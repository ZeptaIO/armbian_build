#!/bin/bash

# Build a minimal image without asking questions. 
# The content itself is customized via userpatches/customize_image.sh
./compile.sh BOARD=rockpi-4cplus BRANCH=current RELEASE=bookworm KERNEL_CONFIGURE=no BUILD_MINIMAL=yes
