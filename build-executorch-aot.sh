#!/bin/bash -e

# Script to build RISC-V Linux Executorch

# Copyright (C) 2024-2026 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>
# Contributor Shane Slattery <shane.slattery@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# All output is piped to 'tee', and this therefore discards the
# return code of the original command. Setting the `pipefail` bash
# option allows us to keep any non-zero return code, e.g. a build fails.

set -u
set -o pipefail

# Function to display help details
display_usage() {
    cat <<EOF
Usage: build-executorch-aot.sh [--clean] [--install-requirements] [--help]

  --clean                 Clean Executorch before building
  --install-requirements  Install ExecuTorch requirements at the start
  --help                  Present this message."
EOF
}

# Top level directories
topdir="$(dirname "$(cd "$(dirname "$0")" && echo "$PWD")")"
logdir="${topdir}"/logs

# Tool specific directories
executorchdir="${topdir}"/executorch

install_requirements=false
doclean=false

# Parse arguments
for opt in "${@}"
do
    case ${opt} in
	"--install-requirements")
	    install_requirements=true
	    ;;
	"--clean")
	    doclean=true
	    ;;
	"--help"|"-h")
	    display_usage
	    exit 0
	    ;;
	*)
	    echo "Unknown argument ${opt}" >&2
	    display_usage >&2
	    exit 1
	    ;;
    esac
done

if [[ ! -v VIRTUAL_ENV ]]
then
    echo "No Python virtual environment set." >&2
    echo "Please create or activate your venv before running this script!" >&2
    echo "Example: " >&2
    echo "   python3 -m venv .venv" >&2
    echo "   source .venv/bin/activate" >&2
    echo "   pip install --upgrade pip" >&2
    exit 1
fi

# Set up log files
mkdir -p "${logdir}"
logf="${logdir}"/"executorch-aot-$(date +%Y%m%d-%H%M%S)".log
touch "${logf}"

echo "Starting at $(date)" 2>&1 | tee -a "${logf}"

cd "${executorchdir}" > /dev/null 2>&1

if "${install_requirements}"
then
    echo "Installing Executorch requirements" 2>&1 | tee -a "${logf}"
    if ! ./install_requirements.sh >> "${logf}" 2>&1
    then
	echo "ERROR: Failed to install ExecuTorch requirements" >&2
	exit 1
    fi
fi

if "${doclean}"
then
    echo "Cleaning Executorch build..." | tee -a "${logf}"
    if ! ./install_executorch.sh --clean >> "${logf}" 2>&1
    then
	echo "ERROR: Failed to clean ExecuTorch" >&2
	exit 1
    fi
fi

echo "Building Executorch" 2>&1 | tee -a "${logf}"
if ! ./install_executorch.sh >> "${logf}" 2>&1
then
    echo "ERROR: Failed to build ExecuTorch" >&2
    exit 1
fi

echo "Finishing at $(date)" 2>&1 | tee -a "${logf}"
