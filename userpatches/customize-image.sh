#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot
# The sd card's root path is accessible via $SDCARD variable.

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

set -e

echo ------------------------------------------------------------------------------------
echo customize-image.sh
echo ------------------------------------------------------------------------------------
echo env:
env
echo ------------------------------------------------------------------------------------
echo Installing additional packages
apt update && apt install -y \
	git vim vnstat net-tools \
	python3 \
    python3-pip \
    python3-venv \
	python-is-python3 \
	default-mysql-server default-mysql-client \
    gnuplot

echo ------------------------------------------------------------------------------------
echo Disable Armbian interactive config, disable root login, enable display of IP address
rm -vf /root/.not_logged_in_yet
cp -vf /tmp/overlay/getty-override.conf /etc/systemd/system/getty\@.service.d/override.conf
cp -vf /tmp/overlay/serial-getty-override.conf /etc/systemd/system/serial-getty\@.service.d/override.conf
cp -vf /tmp/overlay/customize-issue.sh /etc

echo Configuring remote root access via ssh key
mkdir -vp /root/.ssh
chmod 700 /root/.ssh

# Prepare GitHub access during build to clone the application repo:
# cp -vf /tmp/overlay/application-git/id_rsa* /root/.ssh
export SSH_AUTH_SOCK=/tmp/overlay/ssh_agent.sock
cp -vf /tmp/overlay/github-host-keys /root/.ssh/known_hosts
chmod 600 /root/.ssh/*
git clone git@github.com:ZeptaIO/bc_production_configuration /tmp/app
# rm -fv /root/.ssh/id_rsa*

# Key for remote Access to the Armbian Device
cp -vf /tmp/app/root-user/id_rsa.pub /root/.ssh/authorized_keys
chmod 600 /root/.ssh/*
# Block root login on console with goofy password.
passwd --lock root

echo Configuring the locale
# taken from packages/bsp/common/usr/lib/armbian/armbian-firstlogin
LOCALES=en_US.UTF-8
sed -i 's/# '"${LOCALES}"'/'"${LOCALES}"'/' /etc/locale.gen
echo -e "Generating locales: \x1B[92m${LOCALES}\x1B[0m"
locale-gen "${LOCALES}" > /dev/null 2>&1

# setting detected locales globally
{
	echo "export LC_ALL=$LOCALES"
	echo "export LANG=$LOCALES"
	echo "export LANGUAGE=$LOCALES"
} >> /etc/profile

echo Enabling USB 3.0 ports ...
echo overlays=dwc3-0-host rockpi4cplus-usb-host >> /boot/armbianEnv.txt
echo ------------------------------------------------------------------------------------
echo Installing NodeRED

NODE_MAJOR=20

# Install Node.js via Nodesource
if [ ! -x /usr/bin/nodejs ]; then
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list

    apt-get update
    apt-get install nodejs -y
fi

# Install Node-RED
mkdir -p /opt/node-red/base
pushd /opt/node-red/base
npm install node-red
# Install additional useful palette modules:
npm install node-red-contrib-modbus
npm install node-red-node-serialport
npm install node-red-contrib-owfs
npm install node-red-contrib-protobuf
npm install node-red-dashboard
npm install node-red-contrib-ui-actions
npm install node-red-node-mysql
popd

# Prepare access to gpio
groupadd gpio
cp -v /tmp/overlay/99-gpio-permissions.rules /etc/udev/rules.d/

# Create node-red user and it's environment
useradd --base-dir /var/lib/ --create-home node-red
usermod -a -G gpio node-red     # Allow access to gpio
usermod -a -G dialout node-red  # Allow access to RS-232

cp -v /tmp/overlay/nodered.service /etc/systemd/system

echo Install the USB drive auto mounter
cp -v /tmp/overlay/99-usb-mount.rules /etc/udev/rules.d/
cp -v /tmp/overlay/usb-mount\@.service /etc/systemd/system/
mkdir -p /stick

echo Install udev rules for the serial devices
cp -v /tmp/overlay/99-serial-devices.rules /etc/udev/rules.d/

echo Install Backend DB Forwarder Service
cp -v /tmp/app/endurance_test/backend-db/backendforwarder.service /etc/systemd/system

echo ------------------------------------------------------------------------------------
echo Install Platform IO for node-red user
python3 -m venv /var/lib/node-red/.platformio/penv
/var/lib/node-red/.platformio/penv/bin/python3 -m pip install --upgrade pip setuptools
/var/lib/node-red/.platformio/penv/bin/python3 -m pip install -U platformio
chown -R node-red:node-red /var/lib/node-red/.platformio
su node-red -c "/var/lib/node-red/.platformio/penv/bin/pio pkg install --global --tool tool-esptoolpy"

pushd /tmp/app
bc_production_configuration_git_version=$(git log -1 --format=%H)
popd
echo Set GIT Versions:
echo armbian_build_git_version: $(cat /tmp/overlay/armbian_build_git_version)
echo bc_production_configuration_git_version: $bc_production_configuration_git_version
echo $bc_production_configuration_git_version > /var/lib/node-red/bc_production_configuration_git_version
cp -v /tmp/overlay/armbian_build_git_version /var/lib/node-red

echo Installing Endurance Test Configuration:
cp -av /tmp/app/endurance_test/. /var/lib/node-red/
pushd /var/lib/node-red/.node-red
npm install
npm install uuid
popd

chown -R node-red:node-red /var/lib/node-red/
echo ------------------------------------------------------------------------------------
echo Cleaning up
rm -rfv /tmp/app

# Add commands to be executed on the first boot of the system.
sed -i '/systemctl\ disable\ armbian-firstrun/i \
systemctl enable nodered \
systemctl start nodered \
systemctl enable backendforwarder \
systemctl start backendforwarder