#!/usr/bin/env bash

# This script is used to create and run a docker container from an image.
# The script expects 3 arguments:
# --- 1) The name of the docker image from which to create and run the container.
# --- 2) Optional extra arguments for docker run command. E.g., some extra -v options
# --- 3) An optional command to execute in the run container. E.g. /bin/bash 
# Example command line:
# ./run_container.bash moveit/moveit "-v logs:/home/cloudsim/gazebo-logs -ti --rm" /bin/bash

IMAGE_NAME=$1
DOCKER_EXTRA_ARGS=$2
COMMAND=$3

# XAUTH=/tmp/.docker.xauth
# xauth nlist :0 | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -
if [ ! -f /tmp/.docker.xauth ]
then
  export XAUTH=/tmp/.docker.xauth
  xauth nlist :0 | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -
fi

# Use lspci to check for the presence of an nvidia graphics card
has_nvidia=`lspci | grep -i nvidia | wc -l`
has_nvidia_docker=`which nvidia-docker > /dev/null 2>&1; echo $?`

# Check if nvidia-docker is avaialble
if [ ${has_nvidia_docker} -eq 0 ] && [ ${has_nvidia} -gt 0 ]
then
  DOCKER_COMMAND=nvidia-docker
  # Set docker gpu parameters
  # check if nvidia-modprobe is installed
  if ! which nvidia-modprobe > /dev/null
  then
    echo nvidia-docker-plugin requires nvidia-modprobe
    echo please install nvidia-modprobe
    exit -1
  fi
  # check if nvidia-docker-plugin is installed
  if curl -s http://localhost:3476/docker/cli > /dev/null
  then
    DOCKER_GPU_PARAMS=" $(curl -s http://localhost:3476/docker/cli)"
  else
    echo nvidia-docker-plugin not responding on http://localhost:3476/docker/cli
    echo please install nvidia-docker-plugin
    echo https://github.com/NVIDIA/nvidia-docker/wiki/Installation
    exit -1
  fi
else
  DOCKER_COMMAND=docker
  DOCKER_GPU_PARAMS=""
fi

DISPLAY="${DISPLAY:-:0}"

${DOCKER_COMMAND} run \
  -e DISPLAY=unix$DISPLAY \
  -e XAUTHORITY=/tmp/.docker.xauth \
  -v "/etc/localtime:/etc/localtime:ro" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "/tmp/.docker.xauth:/tmp/.docker.xauth" \
  -v /dev/log:/dev/log \
  --ulimit rtprio=99 \
  ${DOCKER_EXTRA_ARGS} \
  ${DOCKER_GPU_PARAMS} \
  ${IMAGE_NAME} \
  ${COMMAND}
