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
    && useradd -d /home/randuser -s /bin/bash -m randuser -u 1000 -g 1000 \
    && chown -R randuser:randuser /home/randuser && \
    chmod -R 777 /home/randuser

USER randuser

ENV HOME /home/randuser
WORKDIR /home/randuser

# RUN pip install torch==1.12.1+cu113  --extra-index-url https://download.pytorch.org/whl/cu113

# RUN curl -LO https://github.com/NVIDIA/cub/archive/1.10.0.tar.gz && \
#     tar xzf 1.10.0.tar.gz && \
#     export CUB_HOME=$(pwd)/cub-1.10.0 && \
#     pip install 'git+https://github.com/facebookresearch/pytorch3d.git@stable'
# Fix Pytorch 3D

# RUN pip install torch==1.12.1+cu113 torchvision==0.13.1+cu113 torchaudio==0.12.1 --extra-index-url https://download.pytorch.org/whl/cu113
RUN pip install torch==1.12.1+cu113 torchvision==0.13.1+cu113 torchaudio==0.12.1+cu113 -f https://download.pytorch.org/whl/torch_stable.html

RUN export PYTHON_MINOR_VERSION=$(python3 -c "import sys; print(sys.version_info.minor)") && \
PYTORCH_VERSION=$(python3 -c "import torch; print(torch.__version__.split('+')[0].replace('.', ''))") && \
CUDA_VERSION=$(python3 -c "import torch; print(torch.version.cuda.replace('.', '') if torch.version.cuda else '')") && \
VERSION_STR="py3${PYTHON_MINOR_VERSION}_cu${CUDA_VERSION}_pyt${PYTORCH_VERSION}" && \
pip install --user iopath && \
pip install --user fvcore && \
pip install --user --no-index --no-cache-dir pytorch3d -f https://dl.fbaipublicfiles.com/pytorch3d/packaging/wheels/${VERSION_STR}/download.html

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
    && git clone https://github.com/stepjam/PyRep.git ${HOME}/pyrep && cd pyrep \
    && git checkout 4.1.0 \
    && pip install -r requirements.txt \
    && pip install --user -e . \
    && :
RUN :\
    && cd ${HOME} \
    && git clone https://github.com/stepjam/RLBench.git ${HOME}/rlbench && cd rlbench \
    && git checkout 7c3f425f4a0b6b5ce001ba7246354eb3c70555be \
    && pip install -r requirements.txt \
    && pip install --user -e . \
    && :
RUN cd ${HOME} && \
        git clone https://github.com/robot-colosseum/robot-colosseum && \
        cd robot-colosseum && \
        pip install --user -e .
USER root

RUN chown -R randuser:randuser ${HOME}/robot-colosseum
RUN chmod 755 ${HOME}/robot-colosseum

USER randuser
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

# Install RVT
COPY rvt_colosseum/ ${HOME}/rvt_colosseum/

RUN cd ${HOME}/rvt_colosseum && \
pip install --user -e .

# Install RVT deps, get rid of dependency conflict
RUN cd ${HOME}/rvt_colosseum && \
sed -i 's/hydra-core==1.0.5/hydra-core/' rvt/libs/YARR/requirements.txt && \
sed -i '/moviepy/d' rvt/libs/YARR/requirements.txt
# pip install --user -e rvt/libs/PyRep && \
# pip install --user -e rvt/libs/RLBench && \
RUN cd ${HOME}/rvt_colosseum && \
pip install --user -e rvt/libs/YARR && \
pip install --user -e rvt/libs/peract_colab && \
pip install --user yacs

# Grab model config and weights
RUN  cd ${HOME}/rvt_colosseum && \
mkdir -p rvt/runs/rvt && \
git lfs install && git clone https://huggingface.co/ankgoyal/rvt rvt/runs/rvt && \
mv rvt/runs/rvt/rvt/*.yaml rvt/runs/ && \
cd rvt/runs && \
pip install --user gdown && \
/home/randuser/.local/bin/gdown https://drive.google.com/uc?id=1Z0-HR7mGjAaPj-9QMj2ALflLMkOmuHNv && \
rm -rf rvt

# Make Python work and grab some deps
USER root
RUN ln -sf /usr/bin/python3 /usr/bin/python
RUN apt-get update && apt-get install -y sudo ffmpeg wget git
# Set password for randuser
RUN echo "randuser:password" | chpasswd
# Add randuser to the sudo group
RUN usermod -aG sudo randuser
# Allow randuser to use sudo without a password (optional)
RUN echo "randuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# PATCHES ---------------------
USER randuser

# Fix: qt.qpa.plugin: Could not find the Qt platform plugin "xcb" in "/home/randuser/.local/lib/python3.8/site-packages/cv2/qt/plugins"
RUN pip3 install --user opencv-python==4.2.0.34

RUN cd ${HOME} && mkdir data
