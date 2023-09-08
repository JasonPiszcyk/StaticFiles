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


# MongoDB Info
MONGO_KEY_URL=https://www.mongodb.org/static/pgp/server-4.4.asc
MONGO_APT_URL=http://repo.mongodb.org/apt/ubuntu
MONGO_KEYRING=${KEYRING_DIR}/mongodb-keyring.gpg
MONGO_APT_SRCLIST=/etc/apt/sources.list.d/mongodb-org-4.4.list

# RAbbitMQ Info
RMQ_TEAM_KEY_URL=https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA
ERLANG_KEY_URL=https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/gpg.E495BB49CC4BBE5B.key
RMQ_KEY_URL=https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/gpg.9F4587F226208342.key

RMQ_TEAM_KEYRING=${KEYRING_DIR}/com.rabbitmq.team.gpg
ERLANG_KEYRING=${KEYRING_DIR}/io.cloudsmith.dl.rabbitmq.erlang.gpg
RMQ_KEYRING=${KEYRING_DIR}/io.cloudsmith.dl.rabbitmq.gpg

ERLANG_APT_URL=http://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/deb/ubuntu
RMQ_APT_URL=https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/deb/ubuntu

RMQ_APT_SRCLIST=/etc/apt/sources.list.d/rabbitmq.list


# StackStorm Info
ST2_KEY_URL=https://packagecloud.io/StackStorm/stable/gpgkey
ST2_APT_URL=https://packagecloud.io/StackStorm/stable/ubuntu
ST2_KEYRING=${KEYRING_DIR}/StackStorm_stable-archive-keyring.gpg
ST2_APT_SRCLIST=/etc/apt/sources.list.d/StackStorm_stable.list


#############################################################################
#
# Util Functions - Functions used throughout script
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




#############################################################################
#
# Process Functions - Functions used to perform a task such as an install
#
#############################################################################
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

  Log "\nUFW: Set default incoming policy"
  ufw default deny incoming >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log -t "ERROR: Unable to set default UFW policy: Incoming"
    exit 1
  fi

  Log "\nUFW: Set default outgoing policy"
  ufw default allow outgoing >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log -t "ERROR: Unable to set default UFW policy: Outgoing"
    exit 1
  fi

  Log "\nUFW: Allow SSH"
  ufw allow ssh >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log -t "ERROR: Unable to set allow SSH incoming in UFW"
    exit 1
  else
    Log -t ""
  fi

  Log "\nUFW: Restart"
  ufw disable && ufw --force enable >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log -t "ERROR: Unable to restart UFW"
    exit 1
  else
    Log -t ""
  fi

  Log "\nUFW: Show status"
  ufw status verbose >> ${LOGFILE} 2>&1
  if [ $? -ne 0 ]; then
    Log -t "ERROR: Unable to get UFW status"
    exit 1
  fi
  ufw status verbose
  Log -t ""
}


##############
# InstallMongoDB - Install MongoDB
##############
InstallMongoDB()
{
  Log -t "Installing MongoDB"

  Log "\nMongoDB: Downloading APT Key"
  Get_APT_GPG_Key -l -t ${MONGO_KEY_URL} ${MONGO_KEYRING} || exit 1

  Log "\nMongoDB: Configuring APT Repo"
  cat - << __EOF > ${MONGO_APT_SRCLIST}
deb [signed-by=${MONGO_KEYRING}] ${MONGO_APT_URL} ${VERSION_CODENAME}/mongodb-org/4.4 multiverse
__EOF

  UpdateAPTCache -l -t || exit 1

  Log "\nMongoDB: Installing Packages"
  InstallPackages -l -t mongodb-org || exit 1

  Log "\nMongoDB: Setting start at boot"
  if ! systemctl enable mongod >> ${LOGFILE} 2>&1 ; then
    Log -t "ERROR: Unable to set Mongo DB to run at startup"
    exit 1
  fi

  Log "\nMongoDB: Starting"
  if ! systemctl start mongod >> ${LOGFILE} 2>&1 ; then
    Log -t "ERROR: Unable start Mongo DB"
    exit 1
  fi

  Log -t ""
}


##############
# InstallRabbitMQ - Install RabbitMQ
##############
InstallRabbitMQ()
{
  Log -t "Installing RabbitMQ"

  Log "\nRabbitMQ: Downloading APT Keys"
  Get_APT_GPG_Key -l -t ${RMQ_TEAM_KEY_URL} ${RMQ_TEAM_KEYRING} || exit 1
  Get_APT_GPG_Key -l -t ${ERLANG_KEY_URL} ${ERLANG_KEYRING} || exit 1
  Get_APT_GPG_Key -l -t ${RMQ_KEY_URL} ${RMQ_KEYRING} || exit 1

  Log "\nRabbitMQ: Configuring APT Repos"
  cat - << __EOF > ${RMQ_APT_SRCLIST}
## Provides modern Erlang/OTP releases
##
deb [signed-by=${ERLANG_KEYRING}] ${ERLANG_APT_URL} ${VERSION_CODENAME} main
deb-src [signed-by=${ERLANG_KEYRING}] ${ERLANG_APT_URL} ${VERSION_CODENAME} main

## Provides RabbitMQ
##
deb [signed-by=${RMQ_KEYRING}] ${RMQ_APT_URL} ${VERSION_CODENAME} main
deb-src [signed-by=${RMQ_KEYRING}] ${RMQ_APT_URL} ${VERSION_CODENAME} main
__EOF

  UpdateAPTCache -l -t || exit 1

  Log "\nRabbitMQ: Installing Packages"
  InstallPackages -l -t erlang-base erlang-asn1 erlang-crypto erlang-eldap erlang-ftp \
        erlang-inets erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
        erlang-runtime-tools erlang-snmp erlang-ssl erlang-syntax-tools erlang-tftp \
        erlang-tools erlang-xmerl || exit 1

  InstallPackages -l -t rabbitmq-server --fix-missing || exit 1
  InstallPackages -l -t redis-server || exit 1

  Log -t ""
}


##############
# InstallStackStorm - Install StackStorm
##############
InstallStackStorm()
{
  Log -t "Installing StackStorm"

  Log "\nStackStorm: Downloading APT Key"
  Get_APT_GPG_Key -l -t ${ST2_KEY_URL} ${ST2_KEYRING} || exit 1

  Log "\nStackStorm: Configuring APT Repo"
  cat - << __EOF > ${ST2_APT_SRCLIST}
deb [signed-by=${ST2_KEYRING}] ${ST2_APT_URL} ${VERSION_CODENAME} main
deb-src [signed-by=${ST2_KEYRING}] ${ST2_APT_URL} ${VERSION_CODENAME} main
__EOF

  UpdateAPTCache -l -t || exit 1

  Log "\nStackStorm: Installing Packages"
  InstallPackages -l -t st2 st2web nginx libldap2-dev libsasl2-dev ldap-utils || exit 1
  InstallPackages -l -t gcc libkrb5-dev || exit 1

  Log -t ""
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
UpdateAPTCache -l -t || exit 1
ApplyUpdates -l -t || exit 1

#
# Make sure the packages we need are installed
#
Log -t "Installing Required Packages"
Log -t "-----------------------------"
InstallPackages -l -t ca-certificates gnupg crudini ufw || exit 1
Log -t ""

#
# Set up firewall
#
ConfigureFirewall

#
# Install MongoDB
#
InstallMongoDB

#
# Install RabbitMQ
#
InstallRabbitMQ

#
# Install StackStorm
#
InstallStackStorm

#
# Apply any outstanding updates and remove unused packages
#
Log -t "Applying Updates and autoremoving unused packages"
UpdateAPTCache -l -t || exit 1
ApplyUpdates -l -t || exit 1
AutoRemovePackages -l -t || exit 1

# All done
Log -t ""
Log -t "*************************************************************************"
Log -t "* All Done! System should be rebooted to ensure all updates are applied *"
Log -t "*************************************************************************"
Log -t ""

exit 0
