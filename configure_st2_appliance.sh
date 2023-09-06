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
ISSUE=/etc/issue
CLOUD_INIT_DISABLED=/etc/cloud/cloud-init.disabled
KEYRING_DIR=/etc/apt/keyrings
DATA_DIR=/data

# Docker Info
DOCKER_KEYRING=${KEYRING_DIR}/docker.gpg
DOCKER_APT_URL=https://download.docker.com/linux/ubuntu
DOCKER_GPG_URL=${DOCKER_APT_URL}/gpg
DOCKER_APT_SRCLIST=/etc/apt/sources.list.d/docker.list

# StackStorm Info
ST2_DOCKER_COMPOSE_DIR=${DATA_DIR}/st2-docker



#############################################################################
#
# Functions
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
# CustomiseEtcIssue - Customise the login screen message
##############
CustomiseEtcIssue()
{
  echo "IP Address: \\4" >> ${ISSUE}
  echo "" >> ${ISSUE}
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

  dpkg -s "${package}" > /dev/null 2>&1
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
# DisableCloudInit - Disable Cloud Init
##############
DisableCloudInit()
{
  Log "Disabling cloud-init"
  touch ${CLOUD_INIT_DISABLED} >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log "ERROR: Unable to create file: ${CLOUD_INIT_DISABLED}"
    exit 1
  else
    Log ""
  fi
}


##############
# PurgeSnaps - Disable and Purge SNAPS
##############
PurgeSnaps()
{
  Log "Purging any existing snaps"
  apt purge snapd -y >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log "ERROR: Unable to purge snaps"
    exit 1
  else
    Log ""
  fi
}


##############
# ConfigureFirewall - Configure the firewall
##############
ConfigureFirewall()
{
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
}


##############
# InstallDocker - Install Docker
##############
InstallDocker()
{
  Log "Setting up Docker"

  # Set up Docker GPG Key
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

  # Set up APT repository
  Log "Setting up Docker APT Repository"
  cat - << __EOF > ${DOCKER_APT_SRCLIST}
deb [arch="${pkg_arch}" signed-by=${DOCKER_KEYRING}] ${DOCKER_APT_URL} ${VERSION_CODENAME} stable
__EOF

  if [ $? -ne 0 ]; then
    Log "ERROR: Problems setting up Docker APT repository"
    exit 1
  fi

  UpdateAPTCache

  # Make sure no docker packages were previusly installed
  if IsPackageInstalled "docker-ce" || IsPackageInstalled "docker-ce-cli" || IsPackageInstalled "containerd.io" || 
      IsPackageInstalled "docker-buildx-plugin" || IsPackageInstalled "docker-compose-plugin"; then
    Log "ERROR: Docker Packages already installed."
    exit 1
  fi

  # Install the packages
  InstallPackage docker-ce 
  InstallPackage docker-ce-cli 
  InstallPackage containerd.io 
  InstallPackage docker-buildx-plugin
  InstallPackage docker-compose-plugin
  InstallPackage docker-compose

  Log ""
}


##############
# InstallStackStorm - Install StackStorm
##############
InstallStackStorm()
{
  Log "Installing StackStorm"

  # Create the data directory
  Log "Installing StackStorm Docker Compose Files"
  install -m 0755 -d ${DATA_DIR} >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log "ERROR: Unable to create Data directory"
    exit 1
  fi

  # Clone the St2 Docker compose repository
  cd ${DATA_DIR} && git clone https://github.com/stackstorm/st2-docker >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log "ERROR: Unable to clone StackStorm Docker GIT Repository"
    exit 1
  fi

  Log ""
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

if [ "${NAME}" != "Ubuntu" ]; then
  Log "ERROR: This must be run on an Ubuntu OS"
  exit 1
fi

pkg_arch=$(dpkg --print-architecture)
if [ $? -ne 0 ]; then
  Log "ERROR: Unable to determine system architecture"
  exit 1
fi

# Put some info in the Log file...
Log ""
Log "Configuring ST2 appliance"
Log "=========================="
Log "OS Name: ${NAME}"
Log "OS Version: ${VERSION}"
Log "OS Codename: ${VERSION_CODENAME}"
Log "OS Package Architecture: ${pkg_arch}"
Log ""

#
# Configure /etc/issue
#
CustomiseEtcIssue

#
# Disable cloud-init
#
DisableCloudInit

#
# Disable and purge snaps
#
PurgeSnaps

#
# Apply any outstanding updates
#
UpdateAPTCache
ApplyUpdates

#
# Make sure the packages we need are installed
#
Log "Installing Required Packages"
Log "-----------------------------"
InstallPackage "ca-certificates"
InstallPackage "gnupg"
InstallPackage "crudini"
InstallPackage "ufw"

Log ""

#
# Set up firewall
#
ConfigureFirewall

#
# Install Docker
#
InstallDocker

#
# Install StackStorm
#
InstallStackStorm

#
# Apply any outstanding updates and remove unused packages
#
UpdateAPTCache
ApplyUpdates
AutoRemovePackages

# All done
Log ""
Log "*************************************************************************"
Log "* All Done! System should be rebooted to ensure all updates are applied *"
Log "*************************************************************************"
Log ""

exit 0
