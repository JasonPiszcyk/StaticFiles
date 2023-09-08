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

# Create File descriptors to save STDOUT/STDERR
exec 3>&1 4>&2

#############################################################################
#
# Functions
#
#############################################################################
##############
# CommonArgs - Function to handle common args in our functions
##############
CommonArgs()
{
  if [ $# -lt 2 ]; then
    echo "ERROR: Incorrect parameters passed to CommonArgs. Exiting" 1>&3 2>&4
    exit 1
  fi

  local -n common_args_arg_list="${1}"
  local -n common_args_log_args="${2}"
  shift 2

  common_args_log_args=""

  while [ $# -gt 0 ]; do
    case "${1}" in
      -l)       # Send output to logfile rather than terminal
        exec &>> ${LOGFILE}
        shift
        ;;

      -t)       # If we call Log, send output to both log and terminal
        common_args_log_args="${log_args} -t"
        shift
        ;;

      -d)       # If we call Log, display a date/timestamp prefix
        common_args_log_args="${log_args} -d"
        shift
        ;;

      *)        # End of parameters
        break
        ;;
    esac
  done

  common_args_arg_list=( "$@" )
}


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
        echo -e "$*" 1>&3 2>&4
        ;;

      *)        # End of parameters
        break
        ;;
    esac
  done

  echo -e "$*" &>> ${LOGFILE}
}


##############
# GenerateRandomString - Generate a random string
##############
GenerateRandomString()
{
  local strlen=20
  local bytecount

  if [ $# -eq 1 ]; then
    strlen=${1}
  fi

  # We generate 256 random chars for weach character we want, to make sure we get enough
  # alphanumeric characters in the string 
  bytecount=$(( $strlen * 256 ))

  # Get a bunch of random chars - we ignore everything but alphanumerics as special chars (such
  # as '*' or '%') give problems when used as passswords
  dd if=/dev/random count=${bytecount} bs=1 status=none | tr -dc '[:alnum:]' | cut -b1-${strlen}
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
  local rc=false
  local arg_list log_args
  local file_to_delete

  CommonArgs arg_list log_args $*
  if [ ${#arg_list[@]} -ne 1 ]; then
    echo "ERROR: Incorrect parameters. Exiting" 1>&3 2>&4
    exit 1
  fi

  file_to_delete="${arg_list[0]}"

  if [ -f ${file_to_delete} ]; then
    rm -f ${file_to_delete}
  else
    true
  fi

  if [ $? -ne 0 ]; then
    Log ${log_args} "ERROR: Unable to delete file"
    Log ${log_args} "ERROR: File: >${file_to_delete}<"
  else
    rc=true
  fi

  exec 1>&3 2>&4

  ${rc}
}


##############
# CopyFile - Copy a file
##############
CopyFile()
{
  local rc=false
  local arg_list log_args
  local src dest

  CommonArgs arg_list log_args $*
  if [ ${#arg_list[@]} -ne 2 ]; then
    echo "ERROR: Incorrect parameters. Exiting" 1>&3 2>&4
    exit 1
  fi

  src="${arg_list[0]}"
  dest="${arg_list[1]}"

  if [ -e ${src} ]; then
    cp ${src} ${dest}
  else
    true
  fi

  if [ $? -ne 0 ]; then
    Log ${log_args} "ERROR: Unable to copy file"
    Log ${log_args} "ERROR: File: >${src}<"
    Log ${log_args} "ERROR: Destination: >${dest}<"
  else
    rc=true
  fi
  
  exec 1>&3 2>&4

  ${rc}
}


##############
# SetIniEntry - Set an entry in an ini file
##############
SetIniEntry()
{
  local rc=false
  local arg_list log_args
  local ini_file ini_section ini_param ini_value

  CommonArgs arg_list log_args $*
  if [ ${#arg_list[@]} -ne 4 ]; then
    echo "ERROR: Incorrect parameters. Exiting" 1>&3 2>&4
    exit 1
  fi

  ini_file="${arg_list[0]}"
  ini_section="${arg_list[1]}"
  ini_param="${arg_list[2]}"
  ini_value="${arg_list[3]}"

  crudini --set "${ini_file}" "${ini_section}" "${ini_param}" "${ini_value}"
  if [ $? -ne 0 ]; then
    Log ${log_args} "ERROR: Unable to set entry in INI file"
    Log ${log_args} "ERROR: INI File: >${ini_file}<"
    Log ${log_args} "ERROR: Section: >${ini_section}<"
    Log ${log_args} "ERROR: Parameter: >${ini_param}<"
  else
    rc=true
  fi

  exec 1>&3 2>&4

  ${rc}
}


##############
# DelIniEntry - Delete an entry from an ini file
##############
DelIniEntry()
{
  local rc=false
  local arg_list log_args
  local ini_file ini_section ini_param

  CommonArgs arg_list log_args $*
  if [ ${#arg_list[@]} -ne 3 ]; then
    echo "ERROR: Incorrect parameters. Exiting" 1>&3 2>&4
    exit 1
  fi

  ini_file="${arg_list[0]}"
  ini_section="${arg_list[1]}"
  ini_param="${arg_list[2]}"

  crudini --del "${ini_file}" "${ini_section}" "${ini_param}"
  if [ $? -ne 0 ]; then
    Log ${log_args} "ERROR: Unable to delete entry from INI file"
    Log ${log_args} "ERROR: INI File: >${ini_file}<"
    Log ${log_args} "ERROR: Section: >${ini_section}<"
    Log ${log_args} "ERROR: Parameter: >${ini_param}<"
  else
    rc=true
  fi

  exec 1>&3 2>&4

  ${rc}
}


##############
# SedFile - Run a sed command against a file
##############
SedFile()
{
  local rc=false
  local arg_list log_args
  local sed_cmd target_file

  CommonArgs arg_list log_args $*
  if [ ${#arg_list[@]} -ne 2 ]; then
    echo "ERROR: Incorrect parameters. Exiting" 1>&3 2>&4
    exit 1
  fi

  sed_cmd="${arg_list[0]}"
  target_file="${arg_list[1]}"

  sed -i "${sed_cmd}" ${target_file}
  if [ $? -ne 0 ]; then
    Log ${log_args} "ERROR: Unable to edit file via sed"
    Log ${log_args} "ERROR: Target File: >${target_file}<"
    Log ${log_args} "ERROR: sed command: >${sed_cmd}<"
  else
    rc=true
  fi

  exec 1>&3 2>&4

  ${rc}
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
  local rc=false
  local arg_list log_args

  CommonArgs arg_list log_args $*
  if [ ${#arg_list[@]} -ne 0 ]; then
    echo "ERROR: Incorrect parameters. Exiting" 1>&3 2>&4
    exit 1
  fi

  apt-get -q update
  if [ $? -ne 0 ]; then
    Log ${log_args} "ERROR: Unable to update APT cache"
  else
    rc=true
  fi

  exec 1>&3 2>&4

  ${rc}
}


##############
# ApplyUpdates - Apply any outstanding updates to the system
##############
ApplyUpdates()
{
  local rc=false
  local arg_list log_args

  CommonArgs arg_list log_args $*
  if [ ${#arg_list[@]} -ne 0 ]; then
    echo "ERROR: Incorrect parameters. Exiting" 1>&3 2>&4
    exit 1
  fi

  apt-get -q -y upgrade
  if [ $? -ne 0 ]; then
    Log ${log_args} "ERROR: Unable to apply updates"
  else
    rc=true
  fi

  exec 1>&3 2>&4

  ${rc}
}


##############
# AutoRemovePackages - Automatically remove unused packages
##############
AutoRemovePackages()
{
  local rc=false
  local arg_list log_args

  CommonArgs arg_list log_args $*
  if [ ${#arg_list[@]} -ne 0 ]; then
    echo "ERROR: Incorrect parameters. Exiting" 1>&3 2>&4
    exit 1
  fi

  apt-get -q -y autoremove
  if [ $? -ne 0 ]; then
    Log ${log_args} "ERROR: Unable to automatically remove unused packages"
  else
    rc=true
  fi

  exec 1>&3 2>&4

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
  local rc=false
  local arg_list log_args

  CommonArgs arg_list log_args $*
  if [ ${#arg_list[@]} -lt 1 ]; then
    echo "ERROR: Incorrect parameters. Exiting" 1>&3 2>&4
    exit 1
  fi

  local package_list="${arg_list[*]}"

  apt-get -q -y install ${package_list}
  if [ $? -ne 0 ]; then
    Log ${log_args} "ERROR: A problem occurred when trying to install packages:"
    Log ${log_args} "ERROR: Package List: >${package_list}<"
  else
    rc=true
  fi

  exec 1>&3 2>&4

  ${rc}
}

##############
# Get_APT_GPG_Key - Get and store the APT GPG key for a package
##############
Get_APT_GPG_Key()
{
  local rc=false
  local arg_list log_args

  CommonArgs arg_list log_args $*
  if [ ${#arg_list[@]} -ne 2 ]; then
    echo "ERROR: Incorrect parameters. Exiting" 1>&3 2>&4
    exit 1
  fi

  local gpg_key_url="${arg_list[0]}"
  local gpg_key_ring="${arg_list[1]}"

  curl -1sLf "${gpg_key_url}" | gpg --dearmor -o ${gpg_key_ring}
  if [ $? -ne 0 ]; then
    Log ${log_args} "ERROR: Unable to download and store GPG key."
    Log ${log_args} "ERROR: URL: >${gpg_key_url}<"
    Log ${log_args} "ERROR: Keyring: >${gpg_key_ring}<"
  else
    rc=true
  fi

  exec 1>&3 2>&4

  ${rc}
}
