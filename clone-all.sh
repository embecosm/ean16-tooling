#!/bin/bash -e

# Script to clone repositories for EAN16

# Copyright (C) 2026 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

topdir="$(dirname "$(cd "$(dirname "$0")" && echo "$PWD")")"
clone_type="https"

# Get the optional argument
if [[ $# -eq 0 ]]
then
    clone_type="https"
elif [[ $# -eq 1 ]]
then
    if [[ "$1" == "--https" ]]
    then
	clone_type="https"
    elif [[ "$1" == "--ssh" ]]
    then
	clone_type="ssh"
    elif [[ "$1" == "--help" ]]
    then
	echo "Usage: ./clone-all.sh [--https | --ssh | --help]"
	exit 0
    else
	echo "ERROR: Unknown argument $1"
	echo "Usage: ./clone-all.sh [--https | --ssh | --help]"
	exit 1
    fi
else
    echo "ERROR: Wrong number of arguments"
    echo "Usage: ./clone-all.sh [--https | --ssh | --help]"
fi

cd "${topdir}" > /dev/null 2>&1

# Clone the repositories
if [[ "${clone_type}" == "ssh" ]]
then
    if [[ -d executorch ]]
    then
	echo "executorch repository already exists"
    else
	git clone -b ean16-1.0 \
	    git@github.com:embecosm/ean16-executorch.git executorch
    fi
    if [[ -d examples ]]
    then
	echo "examples repository already exists"
    else
	git clone -b ean16-1.0 \
	    git@github.com:embecosm/ean16-examples.git examples
    fi
    if [[ -d core-v-verif ]]
    then
	echo "core-v-verif repository already exists"
    else
	git clone git@github.com:openhwgroup/core-v-verif.git core-v-verif
    fi
elif [[ "${clone_type}" == "https" ]]
then
    if [[ -d executorch ]]
    then
	echo "executorch repository already exists"
    else
	git clone -b ean16-1.0 \
	    https://github.com/embecosm/ean16-executorch.git executorch
    fi
    if [[ -d examples ]]
    then
	echo "examples repository already exists"
    else
	git clone -b ean16-1.0 \
	    https://github.com/embecosm/ean16-examples.git examples
    fi
    if [[ -d core-v-verif ]]
    then
	echo "core-v-verif repository already exists"
    else
	git clone https://github.com/openhwgroup/core-v-verif.git core-v-verif
    fi
else
    echo "ERROR: Unknown clone type: ${clone_type}"
    exit 1
fi

# Ensure ExecuTorch submodules are up to date
cd executorch > /dev/null 2>&1
git submodule update --init --recursive
cd .. > /dev/null 2>&1

# Ensure we have the correct commit for the core-v-verif repository
cd core-v-verif > /dev/null 2>&1
git switch --detach 57fbb288

exit 0
