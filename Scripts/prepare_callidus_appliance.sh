#!/usr/bin/env bash
#
# Script Name:  prepare_callidus_appliance.sh
# Written By:   Jason Piszcyk
# Version:      2.0
# Description:  Script to prepare a system for config as a Callidus appliance
#
# Copyright (c) 2024 Jason Piszcyk
#
# Ignore shellcheck checking on certain things in this file
# shellcheck disable=SC2119,SC2317
#

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
dnf config-manager --add-repo https://repo.piszcyk.com/rpms/rocky/9/piszcyk.repo

# Install the callidus-appliance RPM - Will install all dependant packages
dnf install -y callidus-appliance

exit 0
