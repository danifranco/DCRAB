#!/bin/bash

# This script must be executed inside its folder, that is to say: ./install_dcrab.sh

if [ "$0" != "./install_dcrab.sh" ]; then
	echo "ERROR: DCRAB installation script must executed in its directory (./install_dcrab.sh)"
fi

# Check if install prefix is defined 
if [ -z "$DCRAB_INSTALL_PREFIX" ]; then
    echo "ERROR: DCRAB_INSTALL_PREFIX undefined"
    exit
fi

if [ "$DCRAB_INSTALL_PREFIX" != "$PWD" ]; then
	cp -r * $DCRAB_INSTALL_PREFIX/	
	cd $DCRAB_INSTALL_PREFIX
fi

# mpstat installation
cd src/extra
sysfile=`ls -ld sysstat*.tar.gz | awk '{print $9}' | head -n 1`
sysdir=`echo  ${sysfile%%.tar.gz}`
tar xzvf ${sysfile}
cd ${sysdir}
./configure 
make mpstat 
cp mpstat $DCRAB_INSTALL_PREFIX/src/bin
chmod 755 $DCRAB_INSTALL_PREFIX/src/bin/mpstat
