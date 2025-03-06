#!/bin/bash

docker run --runtime=nvidia --gpus all -e DISPLAY -it --rm \
    --name rvt_colosseum \
    -v $HOME/.Xauthority:/home/randuser/.Xauthority \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v ./rvt:/home/randuser/rvt_colosseum/rvt \
    --net=host rvt_colosseum:nvidia bash

