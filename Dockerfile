FROM nvidia/opengl:1.2-glvnd-devel-ubuntu20.04

# The dockerfile was borrowed from issue: https://github.com/robot-colosseum/rvt_colosseum/issues/5

RUN :\
    && apt-get update -q \
    && export DEBIAN_FRONTEND=nointeractive \
    && apt-get install -y --no-install-recommends \
        vim tar xz-utils curl git build-essential \
        libx11-6 libxcb1 libxau6 libgl1-mesa-dev \
        xvfb dbus-x11 x11-utils libxkbcommon-x11-0 \
        libavcodec-dev libavformat-dev libswscale-dev \
        python3 python3-dev python3-virtualenv python3-pip \
        libraw1394-11 libmpfr6 \
        libusb-1.0-0 ca-certificates git-lfs\
    && apt-get autoclean -y \
    && apt-get autoremove -y \
    && apt-get clean

RUN git config --global http.sslVerify false

RUN :\
    && groupadd -g 1000 randuser \
    && useradd -d /home/randuser -s /bin/bash -m randuser -u 1000 -g 1000 

USER randuser

ENV HOME /home/randuser
WORKDIR /home/randuser

RUN :\
    && cd ${HOME} \
    && virtualenv venv && . venv/bin/activate \ 
    && pip install torch==1.12.1+cu113 torchvision==0.13.1+cu113 torchaudio==0.12.1+cu113 -f https://download.pytorch.org/whl/torch_stable.html \
    && :

RUN :\
    && cd ${HOME} \
    && . venv/bin/activate \
    && export PYTHON_MINOR_VERSION=$(python3 -c "import sys; print(sys.version_info.minor)") \
    && PYTORCH_VERSION=$(python3 -c "import torch; print(torch.__version__.split('+')[0].replace('.', ''))") \
    && CUDA_VERSION=$(python3 -c "import torch; print(torch.version.cuda.replace('.', '') if torch.version.cuda else '')") \
    && VERSION_STR="py3${PYTHON_MINOR_VERSION}_cu${CUDA_VERSION}_pyt${PYTORCH_VERSION}" \
    && pip install iopath \
    && pip install fvcore \
    && pip install --no-index --no-cache-dir pytorch3d -f https://dl.fbaipublicfiles.com/pytorch3d/packaging/wheels/${VERSION_STR}/download.html \
    && :

RUN :\
    && curl -o ${HOME}/coppeliasim.tar.xz https://downloads.coppeliarobotics.com/V4_1_0/CoppeliaSim_Edu_V4_1_0_Ubuntu20_04.tar.xz \
    && tar -xvf ${HOME}/coppeliasim.tar.xz -C ${HOME} \
    && rm ${HOME}/coppeliasim.tar.xz \
    && :

ENV COPPELIASIM_ROOT=${HOME}/CoppeliaSim_Edu_V4_1_0_Ubuntu20_04
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${COPPELIASIM_ROOT}
ENV QT_QPA_PLATFORM_PLUGIN_PATH=${COPPELIASIM_ROOT}

# Colosseum stuff
RUN :\
    && cd ${HOME} \
    && . venv/bin/activate \
    && git clone https://github.com/stepjam/PyRep.git ${HOME}/pyrep && cd pyrep \
    && git checkout 4.1.0 \
    && pip install -r requirements.txt \
    && pip install -e . \
    && :
RUN :\
    && cd ${HOME} \
    && . venv/bin/activate \
    && git clone https://github.com/stepjam/RLBench.git ${HOME}/rlbench && cd rlbench \
    && git checkout 7c3f425f4a0b6b5ce001ba7246354eb3c70555be \
    && pip install -r requirements.txt \
    && pip install -e . \
    && :
RUN :\
    && cd ${HOME} \
    && . venv/bin/activate \
    && git clone https://github.com/robot-colosseum/robot-colosseum \
    && cd robot-colosseum \
    && pip install -e . \
    && :

USER root

RUN chown -R randuser:randuser ${HOME}/robot-colosseum
RUN chmod 755 ${HOME}/robot-colosseum

USER randuser

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all


# Install RVT 
RUN :\ 
    && git clone --recurse-submodules https://github.com/StriderOne/rvt_colosseum.git \ 
    && cd rvt_colosseum && git submodule update --init \
    && :

# Grab model config and weights
RUN :\  
    && cd ${HOME} \ 
    && . venv/bin/activate \
    && cd ${HOME}/rvt_colosseum \
    && mkdir -p runs/rvt \
    && git lfs install && git clone https://huggingface.co/ankgoyal/rvt runs/rvt \
    && mv runs/rvt/rvt/*.yaml runs/ \
    && cd runs \
    && pip install gdown \
    && ${HOME}/venv/bin/gdown https://drive.google.com/uc?id=1Z0-HR7mGjAaPj-9QMj2ALflLMkOmuHNv \
    && rm -rf rvt \
    && :


USER root

RUN chown -R randuser:randuser ${HOME}/rvt_colosseum
RUN chmod 755 ${HOME}/rvt_colosseum

USER randuser

RUN :\ 
    && cd ${HOME} \ 
    && . venv/bin/activate \
    && cd ${HOME}/rvt_colosseum \ 
    && pip install -e . \
    && :

# Install RVT deps, get rid of dependency conflict
RUN :\ 
    && cd ${HOME} \ 
    && . venv/bin/activate \
    && cd ${HOME}/rvt_colosseum \
    && sed -i 's/hydra-core==1.0.5/hydra-core/' rvt/libs/YARR/requirements.txt \
    && sed -i '/moviepy/d' rvt/libs/YARR/requirements.txt \
    && :

RUN :\ 
    && cd ${HOME} \ 
    && . venv/bin/activate \
    && cd ${HOME}/rvt_colosseum \
    && pip install -e rvt/libs/YARR \
    && pip install -e rvt/libs/peract_colab \
    && pip install yacs \
    && :

# Make Python work and grab some deps
# USER root
# RUN ln -sf /usr/bin/python3 /usr/bin/python
# RUN apt-get update && apt-get install -y sudo ffmpeg wget git
# # Set password for randuser
# RUN echo "randuser:password" | chpasswd
# # Add randuser to the sudo group
# RUN usermod -aG sudo randuser
# # Allow randuser to use sudo without a password (optional)
# RUN echo "randuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# # PATCHES ---------------------
# USER randuser

# Fix: qt.qpa.plugin: Could not find the Qt platform plugin "xcb" in "/home/randuser/.local/lib/python3.8/site-packages/cv2/qt/plugins"
RUN :\
    && cd ${HOME} \ 
    && . venv/bin/activate \
    && pip install opencv-python==4.2.0.34 \
    && :

RUN cd ${HOME} && mkdir data
COPY patches/collect_dataset.sh ${HOME}/robot-colosseum/collect_dataset.sh
COPY patches/rlbench_env.py ${HOME}/rvt_colosseum/rvt/libs/YARR/yarr/envs/rlbench_env.py
COPY patches/eval.py ${HOME}/rvt_colosseum/rvt/eval.py
