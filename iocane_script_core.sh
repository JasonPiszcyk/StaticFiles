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


#
# Notes on functions in this file
#
# Most functions implement code to redirect output to logfile if desired.
# The following statements will apear in most functions...
#   Save STDOUT to file descriptor 3, STDERR to file descriptor 4
#     exec 3>&1 4>&2
#
#   Restore STDOUT and STDERR to state saved previously
#     exec 1>&3 2>&4
#      

# Standard Environment variables
PROG=${PROG:-$(basename $0)}

# File/Directory locations
LOGFILE=/tmp/${PROG}.log
ISSUE=/etc/issue
CLOUD_INIT_DISABLED=/etc/cloud/cloud-init.disabled
KEYRING_DIR=/usr/share/keyrings
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
  while [ $# -gt 0 ]; do
    case "${1}" in
      -c)       # Clear the log file
        RemoveFile ${LOGFILE}
        echo -n "" > ${LOGFILE}
        shift
        ;;

      -d)       # Display a date/timestamp prefix
        echo -n "$(date +"%H:%M:%S %d/%m/%Y"): " &>> ${LOGFILE}
        shift
        ;;

      -t)       # Display output the terminal
        shift
        echo -e "$*"
        ;;

      *)        # End of parameters
        break
        ;;
    esac
  done

  echo -e "$*" &>> ${LOGFILE}
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
  rc=false
  log_args=""

  exec 3>&1 4>&2

  while [ $# -gt 0 ]; do
    case "${1}" in
      -l)       # Send output to logfile rather than terminal
        exec &>> ${LOGFILE}
        shift
        ;;

      -t)       # If we call Log, send output to both log and terminal
        log_args="${log_args} -t"
        shift
        ;;

      -d)       # If we call Log, display a date/timestamp prefix
        log_args="${log_args} -d"
        shift
        ;;

      *)        # End of parameters
        break
        ;;
    esac
  done

  apt-get -q update
  if [ $? - ne 0 ]; then
    exec 1>&3 2>&4
    Log ${log_args} "ERROR: Unable to update APT cache"
  else
    exec 1>&3 2>&4
    rc=true
  fi

  ${rc}
}


##############
# ApplyUpdates - Apply any outstanding updates to the system
##############
ApplyUpdates()
{
  rc=false
  log_args=""

  exec 3>&1 4>&2

  while [ $# -gt 0 ]; do
    case "${1}" in
      -l)       # Send output to logfile rather than terminal
        exec &>> ${LOGFILE}
        shift
        ;;

      -t)       # If we call Log, send output to both log and terminal
        log_args="${log_args} -t"
        shift
        ;;

      -d)       # If we call Log, display a date/timestamp prefix
        log_args="${log_args} -d"
        shift
        ;;

      *)        # End of parameters
        break
        ;;
    esac
  done

  apt-get -q -y upgrade
  if [ $? - ne 0 ]; then
    exec 1>&3 2>&4
    Log ${log_args} "ERROR: Unable to apply updates"
  else
    exec 1>&3 2>&4
    rc=true
  fi

  ${rc}
}


##############
# AutoRemovePackages - Automatically remove unused packages
##############
AutoRemovePackages()
{
  rc=false
  log_args=""

  exec 3>&1 4>&2

  while [ $# -gt 0 ]; do
    case "${1}" in
      -l)       # Send output to logfile rather than terminal
        exec &>> ${LOGFILE}
        shift
        ;;

      -t)       # If we call Log, send output to both log and terminal
        log_args="${log_args} -t"
        shift
        ;;

      -d)       # If we call Log, display a date/timestamp prefix
        log_args="${log_args} -d"
        shift
        ;;

      *)        # End of parameters
        break
        ;;
    esac
  done

  apt-get -q -y autoremove
  if [ $? - ne 0 ]; then
    exec 1>&3 2>&4
    Log ${log_args} "ERROR: Unable to automatically remove unused packages"
  else
    exec 1>&3 2>&4
    rc=true
  fi

  ${rc}
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
  rc=false
  log_args=""

  exec 3>&1 4>&2

  while [ $# -gt 0 ]; do
    case "${1}" in
      -l)       # Send output to logfile rather than terminal
        exec &>> ${LOGFILE}
        shift
        ;;

      -t)       # If we call Log, send output to both log and terminal
        log_args="${log_args} -t"
        shift
        ;;

      -d)       # If we call Log, display a date/timestamp prefix
        log_args="${log_args} -d"
        shift
        ;;

      *)        # End of parameters
        break
        ;;
    esac
  done

  package_list=$*

  apt-get -q -y install ${package_list}
  if [ $? - ne 0 ]; then
    exec 1>&3 2>&4
    Log ${log_args} "ERROR: A problem occurred when trying to install packages:"
    Log ${log_args} "ERROR: Package List: >${package_list}<"
  else
    exec 1>&3 2>&4
    rc=true
  fi

  ${rc}
}

##############
# Get_APT_GPG_Key - Get and store the APT GPG key for a package
##############
Get_APT_GPG_Key()
{
  rc=false
  log_args=""

  exec 3>&1 4>&2

  while [ $# -gt 0 ]; do
    case "${1}" in
      -l)       # Send output to logfile rather than terminal
        exec &>> ${LOGFILE}
        shift
        ;;

      -t)       # If we call Log, send output to both log and terminal
        log_args="${log_args} -t"
        shift
        ;;

      -d)       # If we call Log, display a date/timestamp prefix
        log_args="${log_args} -d"
        shift
        ;;

      *)        # End of parameters
        break
        ;;
    esac
  done

  gpg_key_url="${1}"
  gpg_key_ring="${2}"

  curl -1sLf "${gpg_key_url}" | gpg --dearmor -o ${gpg_key_ring}
  if [ $? - ne 0 ]; then
    exec 1>&3 2>&4
    Log ${log_args} "ERROR: Unable to download and store GPG key."
    Log ${log_args} "ERROR: URL: >${gpg_key_url}<"
    Log ${log_args} "ERROR: Keyring: >${gpg_key_ring}<"
  else
    exec 1>&3 2>&4
    rc=true
  fi

  ${rc}
}
