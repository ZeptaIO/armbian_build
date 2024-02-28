#!/bin/bash

HERE=$(dirname $0)

if [ ! -f $HERE/userpatches/overlay/application-git/id_rsa ]; then
    echo Please provide an ssh-key at $HERE/userpatches/overlay/application-git/id_rsa to access the application git repository.
    exit 1
fi

# Build a minimal image without asking questions. 
# The content itself is customized via userpatches/customize_image.sh
$HERE/compile.sh BOARD=rockpi-4cplus BRANCH=current RELEASE=bookworm KERNEL_CONFIGURE=no BUILD_MINIMAL=yes
