#!/bin/bash

HERE=$(dirname $0)
SSH_AUTH_SOCK=$HERE/userpatches/overlay/ssh_agent.sock
if [ ! -s $SSH_AUTH_SOCK ]; then 
    echo No SSH Agent running on $SSH_AUTH_SOCK.
    PRIVATE_KEY=$1
    if [ "x$PRIVATE_KEY" == "x" ]; then
        echo Please provide a private ssh-key as command line parameter to access the application git repository.
        exit 1
    fi
    if [ ! -f $PRIVATE_KEY ]; then
        echo No key file found in $PRIVATE_KEY to access the application git repository.
        exit 1
    fi
    export SSH_AUTH_SOCK
    ssh-agent -a $SSH_AUTH_SOCK
    ssh-add $PRIVATE_KEY
fi
# Build a minimal image without asking questions. 
# The content itself is customized via userpatches/customize_image.sh
echo Running in $(pwd)
echo ---------------------------------------
echo userpatches/overlay:
ls $HERE/userpatches/overlay
echo ---------------------------------------
$HERE/compile.sh BOARD=rockpi-4cplus BRANCH=current RELEASE=bookworm KERNEL_CONFIGURE=no BUILD_MINIMAL=yes
