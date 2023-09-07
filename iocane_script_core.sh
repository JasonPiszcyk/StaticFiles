#!/usr/bin/env bash
#
# Script Name:  iocane_script_core
# Date Written: 7/9/2022
# Written By:   Jason Piszcyk
# Version:      1.0
# Description:  Core script function, etc
# Notes:
#
# Usage:        source <(curl -sSL https://raw.githubusercontent.com/JasonPiszcyk/StaticFiles/main/iocane_script_core.sh)
#
# Copyright (c) 2023 Iocane Pty Ltd
#

# Standard Environment variables
PROG=${PROG:-$(basename $0)}

# File/Directory locations
LOGFILE=/tmp/${PROG}.log
ISSUE=/etc/issue
CLOUD_INIT_DISABLED=/etc/cloud/cloud-init.disabled
KEYRING_DIR=/etc/apt/keyrings
DATA_DIR=/data

# Date Info
CUR_DATE=$(date +"%d/%m/%Y")

# Hostname
CUR_HOST=$(hostname)


#############################################################################
#
# Functions
#
#############################################################################
##############
# Log - Write a message to the logfile (and optionally to the screen)
##############
Log()
{
  if [ "$1" = "-c" ]; then
    RemoveFile ${LOGFILE}
    echo -n "" > ${LOGFILE}
    shift
  fi

  if [ "$1" = "-d" ]; then
    echo -n "$(date +"%H:%M:%S %d/%m/%Y"): " >> ${LOGFILE}
    shift
  fi

  if [ "$1" = "-t" ]; then
    shift
    echo "$*"
  fi

  echo "$*" >> ${LOGFILE}
}


#############################################################################
#
# File/Directory Manipulation Functions
#
#############################################################################
##############
# RemoveFile - Remove a file if it exists
##############
RemoveFile()
{
  file_to_delete="${1}"

  [ -f ${file_to_delete} ] && rm -f ${TMP_FILE} || true
}



#############################################################################
#
# Package Management Functions
#
#############################################################################
##############
# UpdateAPTCache - Update the APT Cache
##############
UpdateAPTCache()
{
  apt-get -q update
}


##############
# ApplyUpdates - Apply any outstanding updates to the system
##############
ApplyUpdates()
{
  apt-get -q -y upgrade
}


##############
# AutoRemovePackages - Automatically remove unused packages
##############
AutoRemovePackages()
{
  apt-get -q -y autoremove
}


##############
# IsPackageInstalled - Check if packages are installed
##############
IsPackageInstalled()
{
  package_list=$*
  packages_installed=true

  for pkg in ${package_list}; do
    dpkg -s "${pkg}" > /dev/null 2>&1
    [ $? -eq 0 ] || packages_installed=false
  done

  ${packages_installed}
}


##############
# InstallPackages - Install packages
##############
InstallPackages()
{
  package_list=$*

  apt-get -q -y install ${package_list}
}
