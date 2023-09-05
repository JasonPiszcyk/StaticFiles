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
PROG=$(basename $0)
LOGFILE=/tmp/${PROG}.log


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

Log ""
Log "Configuring ST2 appliance"
Log "=========================="


#
# Disable cloud-init
#
Log "Disabling cloud-init"
touch /etc/cloud/cloud-init.disabled >> ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  Log "ERROR: Unable to create file: /etc/cloud/cloud-init.disabled"
  exit 1
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
Log "Applying any outstanding updates"
apt-get update >> ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  Log "ERROR: Unable to update APT cache"
  exit 1
fi

apt-get -y upgrade >> ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  Log "ERROR: Unable to apply updates"
  exit 1
else
  Log ""
fi

#
# Set up firewall
#
Log "Setting up basic firewall"
apt install ufw >> ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  Log "ERROR: Unable to install UFW package"
  exit 1
else
  Log ""
fi

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

ufw disable && ufw enable >> ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  Log "ERROR: Unable to restart UFW"
  exit 1
else
  Log ""
fi

ufw status verbose >> ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
  Log "ERROR: Unable to restart UFW"
  exit 1
fi
ufw status verbose
Log ""

#
# Install Docker
#


# All done
exit 0
