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
# Ignore shellcheck checking on certain things in this file
# shellcheck disable=SC2034,SC2086,SC2181
#

# Standard Environment variables
PROG="${PROG:-$(basename "${0}")}"

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


# Open duplicates of the file descriptors
# Do this here to make sure they are global!!!!
exec {STDOUT}>&1 {STDERR}>&2


#############################################################################
#
# File Descriptor Management
#
#############################################################################
##############
# SaveFileDescriptors - Save the standard file descriptors
##############
SaveFileDescriptors()
{
  exec {STDOUT}>&1 {STDERR}>&2
}


##############
# RestoreFileDescriptors - Restore the filedescriptors we saved
##############
RestoreFileDescriptors()
{
  # Close the file descriptors
  # The resets STDOUT/STDERR four use and flushes the other FD's
  exec >&"${STDOUT}" 2>&"${STDERR}" {STDOUT}>&- {STDERR}>&-

  # Re-open/Re-Duplicate the file descriptors
  # Make sure they are available if needed
  SaveFileDescriptors
}


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
    echo "ERROR: Incorrect parameters passed to CommonArgs. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  local -n common_args_arg_list="${1}"
  local -n common_args_log_args="${2}"
  shift 2

  common_args_log_args=""

  while [ $# -gt 0 ]; do
    case "${1}" in
      -l)       # Send output to logfile rather than terminal
        exec &>> "${LOGFILE}"
        shift
        ;;

      -t)       # If we call Log, send output to both log and terminal
        common_args_log_args="${common_args_log_args} -t"
        shift
        ;;

      -d)       # If we call Log, display a date/timestamp prefix
        common_args_log_args="${common_args_log_args} -d"
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
        RemoveFile "${LOGFILE}"
        echo -n "" > "${LOGFILE}"
        shift
        ;;

      -d)       # Display a date/timestamp prefix
        echo -n "$(date +"%H:%M:%S %d/%m/%Y"): " &>> "${LOGFILE}"
        shift
        ;;

      -t)       # Display output the terminal
        shift
        echo -e "$*" >&"${STDOUT}" 2>&"${STDERR}"
        ;;

      *)        # End of parameters
        break
        ;;
    esac
  done

  echo -e "$*" &>> "${LOGFILE}"
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

  # We generate 256 random chars for each character we want, to make sure we get enough
  # alphanumeric characters in the string 
  bytecount=$(( strlen * 256 ))

  # Get a bunch of random chars - we ignore everything but alphanumerics as special chars (such
  # as '*' or '%') can give problems when used as passwords
  dd if=/dev/random count=${bytecount} bs=1 status=none | tr -dc '[:alnum:]' | cut -b1-${strlen}
}


#############################################################################
#
# File/Directory Manipulation Functions
#
#############################################################################
##############
# CreateDirectory - Create a directory structure
##############
CreateDirectory()
{
  local rc=false
  local arg_list log_args
  local dir_to_create
  local dir_owner="-"
  local dir_mode="="
  local install_args=""

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -lt 1 ] || [ ${#arg_list[@]} -gt 3 ]; then
    echo "ERROR: Incorrect parameters. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  dir_to_create="${arg_list[0]}"
  [ ${#arg_list[@]} -ge 2 ] && dir_owner="${arg_list[1]}"
  [ ${#arg_list[@]} -ge 3 ] && dir_mode="${arg_list[2]}"

  # Set the arguments for 'install'
  [ "${dir_owner}" != "-" ] && install_args="${install_args} -o ${dir_owner}"
  [ "${dir_mode}" != "-" ] && install_args="${install_args} -m ${dir_mode}"
  
  if ! install -d "${dir_to_create}" ${install_args}; then
    Log ${log_args} "ERROR: Unable to create directory"
    Log ${log_args} "ERROR: Directory: >${dir_to_create}<"
    Log ${log_args} "ERROR: Owner: >${dir_owner}<"
    Log ${log_args} "ERROR: Mode: >${dir_mode}<"
  else
    rc=true
  fi

  RestoreFileDescriptors

  ${rc}
}


##############
# RemoveFile - Remove a file if it exists
##############
RemoveFile()
{
  local rc=false
  local arg_list log_args
  local file_to_delete

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -ne 1 ]; then
    echo "ERROR: Incorrect parameters. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  file_to_delete="${arg_list[0]}"

  if [ -f "${file_to_delete}" ]; then
    rm -f "${file_to_delete}"
  else
    true
  fi

  if [ $? -ne 0 ]; then
    Log ${log_args} "ERROR: Unable to delete file"
    Log ${log_args} "ERROR: File: >${file_to_delete}<"
  else
    rc=true
  fi

  RestoreFileDescriptors

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

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -ne 2 ]; then
    echo "ERROR: Incorrect parameters. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  src="${arg_list[0]}"
  dest="${arg_list[1]}"

  if [ -e "${src}" ]; then
    cp "${src}" "${dest}"
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
  
  RestoreFileDescriptors

  ${rc}
}


##############
# CopyDir - Copy a directory tree 
##############
CopyDir()
{
  local rc=false
  local arg_list log_args
  local src dest

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -ne 2 ]; then
    echo "ERROR: Incorrect parameters. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  src="${arg_list[0]}"
  dest="${arg_list[1]}"

  if [ -e "${src}" ]; then
    cp -r "${src}" "${dest}"
  else
    true
  fi

  if [ $? -ne 0 ]; then
    Log ${log_args} "ERROR: Unable to copy directory"
    Log ${log_args} "ERROR: Source Dir: >${src}<"
    Log ${log_args} "ERROR: Destination Dir: >${dest}<"
  else
    rc=true
  fi
  
  RestoreFileDescriptors

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

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -ne 4 ]; then
    echo "ERROR: Incorrect parameters. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  ini_file="${arg_list[0]}"
  ini_section="${arg_list[1]}"
  ini_param="${arg_list[2]}"
  ini_value="${arg_list[3]}"

  if ! crudini --set "${ini_file}" "${ini_section}" "${ini_param}" "${ini_value}"; then
    Log ${log_args} "ERROR: Unable to set entry in INI file"
    Log ${log_args} "ERROR: INI File: >${ini_file}<"
    Log ${log_args} "ERROR: Section: >${ini_section}<"
    Log ${log_args} "ERROR: Parameter: >${ini_param}<"
  else
    rc=true
  fi

  RestoreFileDescriptors

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

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -ne 3 ]; then
    echo "ERROR: Incorrect parameters. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  ini_file="${arg_list[0]}"
  ini_section="${arg_list[1]}"
  ini_param="${arg_list[2]}"

  if ! crudini --del "${ini_file}" "${ini_section}" "${ini_param}"; then
    Log ${log_args} "ERROR: Unable to delete entry from INI file"
    Log ${log_args} "ERROR: INI File: >${ini_file}<"
    Log ${log_args} "ERROR: Section: >${ini_section}<"
    Log ${log_args} "ERROR: Parameter: >${ini_param}<"
  else
    rc=true
  fi

  RestoreFileDescriptors

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

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -ne 2 ]; then
    echo "ERROR: Incorrect parameters. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  sed_cmd="${arg_list[0]}"
  target_file="${arg_list[1]}"

  if ! sed -i "${sed_cmd}" "${target_file}"; then
    Log ${log_args} "ERROR: Unable to edit file via sed"
    Log ${log_args} "ERROR: Target File: >${target_file}<"
    Log ${log_args} "ERROR: sed command: >${sed_cmd}<"
  else
    rc=true
  fi

  RestoreFileDescriptors

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

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -ne 0 ]; then
    echo "ERROR: Incorrect parameters. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  if ! apt-get -q update ; then
    Log ${log_args} "ERROR: Unable to update APT cache"
  else
    rc=true
  fi

  RestoreFileDescriptors

  ${rc}
}


##############
# ApplyUpdates - Apply any outstanding updates to the system
##############
ApplyUpdates()
{
  local rc=false
  local arg_list log_args

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -ne 0 ]; then
    echo "ERROR: Incorrect parameters. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  if ! apt-get -q -y upgrade; then
    Log ${log_args} "ERROR: Unable to apply updates"
  else
    rc=true
  fi

  RestoreFileDescriptors

  ${rc}
}


##############
# AutoRemovePackages - Automatically remove unused packages
##############
AutoRemovePackages()
{
  local rc=false
  local arg_list log_args

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -ne 0 ]; then
    echo "ERROR: Incorrect parameters. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  if ! apt-get -q -y autoremove ; then
    Log ${log_args} "ERROR: Unable to automatically remove unused packages"
  else
    rc=true
  fi

  RestoreFileDescriptors

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
    dpkg -s "${pkg}" > /dev/null 2>&1 || packages_installed=false
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

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -lt 1 ]; then
    echo "ERROR: Incorrect parameters. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  local package_list="${arg_list[*]}"

  if ! apt-get -qq -y install ${package_list} ; then 
    Log ${log_args} "ERROR: A problem occurred when trying to install packages:"
    Log ${log_args} "ERROR: Package List: >${package_list}<"
  else
    rc=true
  fi

  RestoreFileDescriptors

  ${rc}
}


##############
# Get_APT_GPG_Key - Get and store the APT GPG key for a package
##############
Get_APT_GPG_Key()
{
  local rc=false
  local arg_list log_args

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -ne 2 ]; then
    echo "ERROR: Incorrect parameters. Exiting" &3 2>&"${STDERR}"
    exit 1
  fi

  local gpg_key_url="${arg_list[0]}"
  local gpg_key_ring="${arg_list[1]}"

  if ! curl -1sLf "${gpg_key_url}" | gpg --dearmor -o "${gpg_key_ring}"; then
    Log ${log_args} "ERROR: Unable to download and store GPG key."
    Log ${log_args} "ERROR: URL: >${gpg_key_url}<"
    Log ${log_args} "ERROR: Keyring: >${gpg_key_ring}<"
  else
    rc=true
  fi

  RestoreFileDescriptors

  ${rc}
}


##############
# InstallPIP - Install python packages
##############
InstallPIP()
{
  local rc=false
  local arg_list log_args

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -lt 1 ]; then
    echo "ERROR: Incorrect parameters. Exiting" &3 2>&"${STDERR}"
    exit 1
  fi

  local package_list="${arg_list[*]}"

  if ! pip3 install ${package_list}; then
    Log ${log_args} "ERROR: A problem occurred when trying to install python packages:"
    Log ${log_args} "ERROR: Package List: >${package_list}<"
  else
    rc=true
  fi

  RestoreFileDescriptors

  ${rc}
}


#############################################################################
#
# Service Management Functions
#
#############################################################################
##############
# ServiceControl - Control a service vi systemctl 
##############
ServiceControl()
{
  local rc=false
  local arg_list log_args
  local cmd svc

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -ne 2 ]; then
    echo "ERROR: Incorrect parameters. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  cmd="${arg_list[0]}"
  svc="${arg_list[1]}"

  if ! systemctl "${cmd}" "${svc}" ; then
    Log ${log_args} "ERROR: Unable to perform command on service"
    Log ${log_args} "ERROR: CMD: >${cmd}<"
    Log ${log_args} "ERROR: Service: >${svc}<"
  else
    rc=true
  fi

  RestoreFileDescriptors

  ${rc}
}


##############
# Service_WaitForLog - Wait for an entry in the service log
##############
Service_WaitForLog()
{
  local rc=false
  local arg_list log_args
  local max_wait_time=300
  local svc wait_string

  CommonArgs arg_list log_args "$@"

  if [ ${#arg_list[@]} -lt 2 ] || [ ${#arg_list[@]} -gt 3 ]; then
    echo "ERROR: Incorrect parameters. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  svc="${arg_list[0]}"
  wait_string="${arg_list[1]}"
  [ ${#arg_list[@]} -ge 3 ] && max_wait_time="${arg_list[2]}"

  if [ ${max_wait_time} -le 0 ]; then
    bash -c "journalctl -u ${svc} -f --no-pager | grep -q \"${wait_string}\" "
  else
    timeout ${max_wait_time} bash -c "journalctl -u ${svc} -f --no-pager | grep -q \"${wait_string}\" "
  fi
  if [ $? -eq 0 ]; then
    rc=true
  fi

  RestoreFileDescriptors

  ${rc}
}


#############################################################################
#
# User Management Functions
#
#############################################################################
##############
# AddUser - Add a user to the system
##############
AddUser()
{
  local rc=false
  local arg_list log_args
  local username homedir comment shell

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -le 0 ]; then
    echo "ERROR: Incorrect parameters. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  homedir="/home/${username}"
  comment="${username}"
  shell="/bin/bash"

  x=0
  while [ ${#arg_list[@]} -gt ${x}  ]; do
    case "${arg_list[${x}]}" in
      -c)       # Comment
        (( x++ ))
        comment="${arg_list[${x}]}"
        ;;

      -h)       # Home Directory
        (( x++ ))
        homedir="${arg_list[${x}]}"
        ;;

      -s)       # Shell
        (( x++ ))
        shell="${arg_list[${x}]}"
        ;;

      *)        # End of parameters
        # Username should be the last argument
        username="${arg_list[${x}]}"
        break
        ;;
    esac

    (( x++ ))
  done

  if ! useradd -c "${comment}" -d "${homedir}" -m -s "${shell}" "${username}"; then
    Log ${log_args} "ERROR: Unable to create user"
    Log ${log_args} "ERROR: username: >${username}<"
    Log ${log_args} "ERROR: shell: >${shell}<"
    Log ${log_args} "ERROR: comment: >${comment}<"
    Log ${log_args} "ERROR: homedir: >${homedir}<"
  else
    rc=true
  fi

  RestoreFileDescriptors

  ${rc}
}


##############
# SetUserPassword - Set a user password
##############
SetUserPassword()
{
  local rc=false
  local arg_list log_args
  local user password

  CommonArgs arg_list log_args "$@"
  if [ ${#arg_list[@]} -ne 2 ]; then
    echo "ERROR: Incorrect parameters. Exiting" >&"${STDOUT}" 2>&"${STDERR}"
    exit 1
  fi

  user="${arg_list[0]}"
  password="${arg_list[1]}"

  echo "${user}:${password}" | chpasswd
  if [ $? -ne 0 ]; then
    Log ${log_args} "ERROR: Unable to change user password"
    Log ${log_args} "ERROR: User: >${user}<"
    Log ${log_args} "ERROR: Password: >${password}<"
  else
    rc=true
  fi

  RestoreFileDescriptors

  ${rc}
}

