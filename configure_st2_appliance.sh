#!/bin/bash
#
# Script Name:  configure_st2_appliance
# Date Written: 5/9/2022
# Written By:   Jason Piszcyk
# Version:      1.0
# Description:  Configure an ubuntu server as a ST2 appliance
# Notes:
#
# Usage:        See Usage
#
# Copyright (c) 2023 Iocane Pty Ltd
#

# The list of command line options to process
ShortOptList="h"
LongOptList="help:"

# Any Global Variables
# PROG=$(basename $0)
PROG="configure_st2_appliance"
LOGFILE=/tmp/${PROG}.log

# File/Directory locations
CLOUD_INIT_DISABLED=/etc/cloud/cloud-init.disabled
KEYRING_DIR=/etc/apt/keyrings

# Docker Info
DOCKER_KEYRING=${KEYRING_DIR}/docker.gpg
DOCKER_APT_URL=https://download.docker.com/linux/ubuntu
DOCKER_GPG_URL=${DOCKER_APT_URL}/gpg
DOCKER_APT_SRCLIST=/etc/apt/sources.list.d/docker.list


#############################################################################
#
# Processing and Validation Functions
#
#############################################################################

##############
# Usage - Display the Usage then exit...
##############
Usage()
{
  cat - << __EOF

Usage: ${PROG} [ options ]

Usage Info

OPTIONS
-------
  -h, --help
      Display help information
    
__EOF

  exit 1
}


##############
# Log - Write a message to the screen + logfile
##############
Log()
{
  echo -e "$*" | tee -a ${LOGFILE}
}


##############
# UpdateAPTCache - Update the APT Cache
##############
UpdateAPTCache()
{
  Log "Updating the APT cache"
  apt-get update >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log "ERROR: Unable to update APT cache"
    exit 1
  fi
}


##############
# ApplyUpdates - Apply any outstanding updates to the system
##############
ApplyUpdates()
{
  Log "Applying any outstanding updates"
  apt-get -y upgrade >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log "ERROR: Unable to apply updates"
    exit 1
  else
    Log ""
  fi
}


##############
# AutoRemovePackages - Automatically remove unused packages
##############
AutoRemovePackages()
{
  Log "Autoremoving unused packages"
  apt -y autoremove >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log "ERROR: Unable to remove unused packages"
    exit 1
  else
    Log ""
  fi
}


##############
# IsPackageInstalled - Check if a package is installed
##############
IsPackageInstalled()
{
  package="${1}"

  dpkg -l "${package}" > /dev/null 2>&1
  [ $? -eq 0 ] && true || false
}

##############
# InstallPackage - Install a package
##############
InstallPackage()
{
  package="${1}"

  Log "Installing Package: ${package}"

  # Is the package already installed?
  if IsPackageInstalled ${package}; then
    Log "Package already installed: ${package}"
  else
    apt-get -y install ${package} >> ${LOGFILE} 2>&1
    if [ $? -ne 0 ]; then
      Log "ERROR: Unable to install package: ${package}"
      exit 1
    else
      Log ""
    fi
  fi
}


##############
# InstallDockerGPG - Install the docker GPG key
##############
InstallDockerGPG()
{
  Log "Setting up Docker GPG Key"

  install -m 0755 -d ${KEYRING_DIR} >> ${LOGFILE} 2>&1
  if [ $? -eq 0 ]; then
    curl -fsSL ${DOCKER_GPG_URL} | gpg --dearmor -o ${DOCKER_KEYRING} >> ${LOGFILE} 2>&1
    if [ $? -eq 0 ]; then
      chmod a+r ${DOCKER_KEYRING} >> ${LOGFILE} 2>&1
      if [ $? -ne 0 ]; then
        Log "ERROR: Unable to set permissions on docker GPG key"
        exit 1
      fi
    else
      Log "ERROR: Unable to download docker GPG key"
      exit 1
    fi
  else
    Log "ERROR: Unable to create GPG key directory"
    exit 1
  fi
}


#############################################################################
#
# I choose to start the main code.... Here
#
#############################################################################

#
# Clear the logfile
#
[ -e ${LOGFILE} ] && rm -f ${LOGFILE}

#
# Process the command line parameters
#
TempParams=""

# Parse any arguments
TempParams=$(getopt -q -o $ShortOptList -l $LongOptList -- "$@")
[ $? -ne 0 ] && Usage

eval set -- "$TempParams"

# Process the params
while true ; do
  case "$1" in
    -h|--help)
        Usage
        ;;

    --)   # End of parameters
        shift
        break
        ;;

    *)    # Something is wrong here
        Usage
        ;;
  esac
done

# Process unnamed paramaters
[ $# -ne 0 ] && Usage

# Get some info on the OS
if [ -e /etc/os-release ]; then
  . /etc/os-release
else
  Log "ERROR: Unable to determine OS info"
  exit 1
fi

pkg_arch=$(dpkg --print-architecture)
if [ $? -ne 0 ]; then
  Log "ERROR: Unable to determine system architecture"
  exit 1
fi


Log ""
Log "Configuring ST2 appliance"
Log "=========================="
Log "OS Name: ${NAME}"
Log "OS Verison: ${VERSION}"
Log "OS Codename: ${VERSION_CODENAME}"
Log "OS Package Architecture: ${pkg_arch}"
Log ""

#
# Disable cloud-init
#
Log "Disabling cloud-init"
touch ${CLOUD_INIT_DISABLED} >> ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  Log "ERROR: Unable to create file: ${CLOUD_INIT_DISABLED}"
  exit 1
else
  Log ""
fi

#
# Disable and purge snaps
#
Log "Purging any existing snaps"
apt purge snapd -y >> ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  Log "ERROR: Unable to purge snaps"
  exit 1
else
  Log ""
fi


#
# Apply any outstanding updates
#
UpdateAPTCache
ApplyUpdates


#
# Install packages we need
#
Log "Installing Required Packages"
Log "-----------------------------"
InstallPackage "ca-certificates"
InstallPackage "curl"
InstallPackage "gnupg"
InstallPackage "ufw"

Log ""

#
# Set up firewall
#
Log "Setting up basic firewall"

ufw default deny incoming >> ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  Log "ERROR: Unable to set default UFW policy: Incoming"
  exit 1
fi

ufw default allow outgoing >> ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  Log "ERROR: Unable to set default UFW policy: Outgoing"
  exit 1
fi

ufw allow ssh >> ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  Log "ERROR: Unable to set allow SSH incoming in UFW"
  exit 1
else
  Log ""
fi

ufw disable && ufw --force enable >> ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  Log "ERROR: Unable to restart UFW"
  exit 1
else
  Log ""
fi

ufw status verbose >> ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  Log "ERROR: Unable to get UFW status"
  exit 1
fi
ufw status verbose
Log ""


#
# Install Docker
#
Log "Setting up Docker"
InstallDockerGPG

Log "Setting up Docker APT Repository"
cat - << __EOF
deb [arch="${pkg_arch}" signed-by=${DOCKER_KEYRING}] ${DOCKER_APT_URL} ${VERSION_CODENAME} stable
__EOF > ${DOCKER_APT_SRCLIST}
if [ $? -ne 0 ]; then
  Log "ERROR: Problems setting up Docker APT repository"
  exit 1
fi

UpdateAPTCache

# Make sure no docker packages were previusly installed
if IsPackageInstalled "docker-ce" -o IsPackageInstalled "docker-ce-cli" -o IsPackageInstalled "containerd.io" -o 
    IsPackageInstalled "docker-buildx-plugin" -o IsPackageInstalled "docker-compose-plugin"; then
  Log "ERROR: Docker Packages already installed."
  exit 1
else

InstallPackage docker-ce 
InstallPackage docker-ce-cli 
InstallPackage containerd.io 
InstallPackage docker-buildx-plugin
InstallPackage docker-compose-plugin


#
# Apply any outstanding updates and remove unused packages
#
UpdateAPTCache
ApplyUpdates
AutoRemovePackages

# All done
exit 0
