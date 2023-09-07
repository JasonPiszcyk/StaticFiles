#!/usr/bin/env bash
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

# Override PROG as this will be set to a temporary name based on how we are run!
PROG="configure_st2_appliance"

# Call in the Iocane core script which has our functions, standard evn variables, etc
source <(curl -sSL https://raw.githubusercontent.com/JasonPiszcyk/StaticFiles/main/iocane_script_core.sh)


# StackStorm Info


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
# CustomiseEtcIssue - Customise the login screen message
##############
CustomiseEtcIssue()
{
  Log -t "Customising ${ISSUE}"

  echo "IP Address: \\4" >> ${ISSUE}
  echo "" >> ${ISSUE}

  Log -t ""
}


##############
# DisableCloudInit - Disable Cloud Init
##############
DisableCloudInit()
{
  Log -t "Disabling cloud-init"
  touch ${CLOUD_INIT_DISABLED} >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log "ERROR: Unable to create file: ${CLOUD_INIT_DISABLED}"
    exit 1
  else
    Log -t ""
  fi
}


##############
# PurgeSnaps - Disable and Purge SNAPS
##############
PurgeSnaps()
{
  Log -t "Purging any existing snaps"
  apt purge snapd -y >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log -t "ERROR: Unable to purge snaps"
    exit 1
  else
    Log -t ""
  fi
}


##############
# ConfigureFirewall - Configure the firewall
##############
ConfigureFirewall()
{
  Log -t "Setting up basic firewall"

  ufw default deny incoming >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log -t "ERROR: Unable to set default UFW policy: Incoming"
    exit 1
  fi

  ufw default allow outgoing >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log -t "ERROR: Unable to set default UFW policy: Outgoing"
    exit 1
  fi

  ufw allow ssh >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log -t "ERROR: Unable to set allow SSH incoming in UFW"
    exit 1
  else
    Log -t ""
  fi

  ufw disable && ufw --force enable >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log -t "ERROR: Unable to restart UFW"
    exit 1
  else
    Log -t ""
  fi

  ufw status verbose >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log -t "ERROR: Unable to get UFW status"
    exit 1
  fi
  ufw status verbose
  Log -t ""
}


##############
# InstallStackStorm - Install StackStorm
##############
InstallStackStorm()
{
  Log -t "Installing StackStorm"

  # Create the data directory
  Log -t "Installing StackStorm Docker Compose Files"
  install -m 0755 -d ${DATA_DIR} >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log -t "ERROR: Unable to create Data directory"
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
Log -c ""

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
  Log -t "ERROR: Unable to determine OS info"
  exit 1
fi

if [ "${NAME}" != "Ubuntu" ]; then
  Log -t "ERROR: This must be run on an Ubuntu OS"
  exit 1
fi

pkg_arch=$(dpkg --print-architecture)
if [ $? -ne 0 ]; then
  Log -t "ERROR: Unable to determine system architecture"
  exit 1
fi

# Put some info in the Log file...
Log -t ""
Log -t "Configuring ST2 appliance"
Log -t "=========================="
Log -t "OS Name: ${NAME}"
Log -t "OS Version: ${VERSION}"
Log -t "OS Codename: ${VERSION_CODENAME}"
Log -t "OS Package Architecture: ${pkg_arch}"
Log -t ""

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
Log -t "Applying Updates"
if ! UpdateAPTCache ; then
  Log -t "ERROR: Unable to update APT cache"
  exit 1
fi
  
if ! ApplyUpdates ; then
  Log "ERROR: Unable to apply updates"
  exit 1
fi

#
# Make sure the packages we need are installed
#
Log -t "Installing Required Packages"
Log -t "-----------------------------"
if ! InstallPackage ca-certificates gnupg crudini ufw ; then
  Log -t "ERROR: A problem occurred when installed required packages"
  exit 1
fi

Log -t ""

#
# Set up firewall
#
ConfigureFirewall

#
# Install StackStorm
#
InstallStackStorm

#
# Apply any outstanding updates and remove unused packages
#
Log -t "Applying Updates and autoremoving unused packages"
if ! UpdateAPTCache ; then
  Log -t "ERROR: Unable to update APT cache"
  exit 1
fi
  
if ! ApplyUpdates ; then
  Log "ERROR: Unable to apply updates"
  exit 1
fi

if ! AutoRemovePackages ; then
  Log "ERROR: Unable to automatically remove unused packages"
  exit 1
fi

# All done
Log -t ""
Log -t "*************************************************************************"
Log -t "* All Done! System should be rebooted to ensure all updates are applied *"
Log -t "*************************************************************************"
Log -t ""

exit 0
