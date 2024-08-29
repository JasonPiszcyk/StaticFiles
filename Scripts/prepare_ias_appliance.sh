#!/usr/bin/env bash
#
# Script Name:  prepare_ias_appliance.sh
# Written By:   Jason Piszcyk
# Version:      2.0
# Description:  Script to prepare a system for config as an IAS appliance
#
# Copyright (c) 2024 Iocane Pty Ltd
#
# Ignore shellcheck checking on certain things in this file
# shellcheck disable=SC2119,SC2317
#

# IAS RPM Info
IAS_RPM_VERSION="0.2.0"
IAS_RPM_RELEASE="3"
IAS_RPM_NAME="ias-appliance-${IAS_RPM_VERSION}-${IAS_RPM_RELEASE}.x86_64.rpm"
IAS_RPM_LOCATION="https://raw.githubusercontent.com/JasonPiszcyk/StaticFiles/main/RPMS"


#############################################################################
#
# I choose to start the main code.... Here
#
#############################################################################
# Get some info on the OS
# shellcheck disable=SC1091
[ -f /etc/os-release ] && . /etc/os-release

if [ "${NAME}" != "Rocky Linux" ]; then
  Log -t "ERROR: This must be run on a Rocky Linux OS"
  exit 1
fi

# Configure the Repos
dnf config-manager --set-enabled crb
dnf install -y epel-release
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install the ias-appliance RPM - Will install all dependant packages
dnf install -y "${IAS_RPM_LOCATION}/${IAS_RPM_NAME}"

exit 0