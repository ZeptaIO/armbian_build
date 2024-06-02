#!/bin/bash

set -e

HERE=$(realpath $(dirname $0))

echo Running in $(pwd)
echo ---------------------------------------
echo userpatches/overlay:
ls -l $HERE/userpatches/overlay
echo ---------------------------------------

SSH_AUTH_SOCK=$HERE/userpatches/overlay/ssh_agent.sock
if [ ! -S $SSH_AUTH_SOCK ]; then 
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
pushd $HERE
git log -1 --format=%H > $HERE/userpatches/overlay/armbian_build_git_version
popd
# Build a minimal image without asking questions. 
# The content itself is customized via userpatches/customize_image.sh
$HERE/compile.sh BOARD=rockpi-4cplus BRANCH=current RELEASE=bookworm KERNEL_CONFIGURE=no BUILD_MINIMAL=yes COMPRESS_OUTPUTIMAGE=xz
