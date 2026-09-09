#!/bin/bash -e

# Script to build the RISC-V Linux Executorch

# Copyright (C) 2024-2026 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>
# Contributor Shane Slattery <shane.slattery@embecosm.com>

# This file is part of the Embecosm Executorch build system.

# SPDX-License-Identifier: GPL-3.0-or-later

# All output is piped to 'tee', and this therefore discards the
# return code of the original command. Setting the `pipefail` bash
# option allows us to keep any non-zero return code, e.g. a build fails.

set -u
set -o pipefail

# Top level directories
topdir="$(dirname "$(cd "$(dirname "$0")" && echo "$PWD")")"
tooldir=${topdir}/tooling
builddir="${topdir}"/build
logdir="${topdir}"/logs
installdir="${topdir}"/install

# Tool specific directories
executorchdir="${topdir:?}"/executorch
#executorch_toolsdir="${tooldir}"/executorch_tools

BUILD_CMAKE_GENERATOR=
BUILD_CMAKE_TYPE=RelWithDebInfo
IS_VERILATOR=ON
doclean=false
IS_VERBOSE=FALSE

ET_LOGGING=OFF
ET_LOG_LEVEL=Fatal

build_target=riscv32-corev-elf
MODEL_FILE_PATH="${executorchdir}"/model.pte

export EXECUTORCH_RV_ABI=ilp32
export EXECUTORCH_RV_ISA=rv32imc_zicsr_zifencei_xcvhwlp_xcvmem_xcvbitmanip_xcvalu_xcvbi_xcvmac_xcvsimd
export EXECUTORCH_LDSCRIPT="${topdir}/core-v-verif/cv32e40p/bsp/link.ld"
export EXECUTORCH_BSP_LIBDIR="${topdir}/core-v-verif/cv32e40p/bsp"
export EXECUTORCH_CRT0="${topdir}/core-v-verif/cv32e40p/bsp/crt0.S"
export CMAKE_TOOLCHAIN_FILE="${tooldir}/${build_target}.cmake"
EXECUTORCH_CRTBEGIN=$(riscv32-corev-elf-gcc -mabi=${EXECUTORCH_RV_ABI} \
    -march=${EXECUTORCH_RV_ISA} -### /dev/null 2>&1 | grep crtbegin.o | \
    sed -e 's/^.* \([^ ]\+crtbegin.o\).*$/\1/')
EXECUTORCH_CRTEND=$(riscv32-corev-elf-gcc -mabi=${EXECUTORCH_RV_ABI} \
    -march=${EXECUTORCH_RV_ISA} -### /dev/null 2>&1 | grep crtend.o | \
    sed -e 's/^.* \([^ ]\+crtend.o\).*$/\1/')
export EXECUTORCH_CRTBEGIN
export EXECUTORCH_CRTEND
cmake_extra_defs=

check_target() {
  if [ ! -f "${tooldir}"/"${build_target:?}".cmake ]; then
    #echo A CMake Toolchain file does not exist for "${build_target}"!
    availabletargets=
    for f in "${tooldir}"/*
    do
      case $f in
        *.cmake)
        if [[ -n "${availabletargets}" ]]; then
          availabletargets="${availabletargets}, "
        fi
        availabletargets="${availabletargets}$(basename "$f" .cmake)"
        ;;
      esac
    done
    echo error: Target "${build_target}" not available. Available targets: "${availabletargets}"
    exit 1
  fi
}

display_usage() {
    cat <<EOF
Usage for $0:
  [--clean]                       Erase build & install directories
  [--mode <mode>]                 Build type: Debug, RelWithDebInfo, Release
  [--verbose]                     More detail in the log
  [--model <path>]                Set .pte or .pte.inc path for executor_runner
  [--executorch-logging <level>]  Executoch loging: Debug, Info, Error, Fatal
  [-h | --help]                   Present this message and exit
EOF
}

set +u
until
    opt="$1"
    case ${opt} in
	"--clean")
	    doclean=true;
	    ;;
	"--mode")
	    shift
	    BUILD_CMAKE_TYPE=$1
	    ;;
	"--verbose")
	    IS_VERBOSE=TRUE
	    ;;
	"--ninja")
	    BUILD_CMAKE_GENERATOR=Ninja
	    ;;
	"--model="*)
	    MODEL_FILE_PATH=${opt#--model=}
	    ;;
	"--executorch-logging"*)
	    shift
	    ET_LOG_LEVEL=$1
	    ET_LOGGING=ON
	    ;;
	"-h|--help")
	    display_usage
	    exit 0
	    ;;
	?*)
	    echo "Unknown argument ${opt}" >&2
	    display_usage >&2
	    exit 1
	    ;;
    esac
    [[ "${opt}" == "" ]]
do
    shift
done
set -u

check_target

if [[ ! -v VIRTUAL_ENV ]]
then
    echo "No Python virtual environment set." >&2
    echo "Please create or activate your venv before running this script!" >&2
    echo "Example: " >&2
    echo "   python3 -m venv .venv" >&2
    echo "   source .venv/bin/activate" >&2
    echo "   pip install --upgrade pip" >&2
    exit 2
fi

if [ ! -f "${MODEL_FILE_PATH}" ]
then
  echo "ERROR: Model does not exist! (${MODEL_FILE_PATH})" >&2
  exit 1
fi

# Create build directorys (Use :? to verify path as specified in SC2115)
mkdir -p "${builddir}"

BUILD_CMAKE_GENERATOR=Ninja

if "${doclean}"
then
    rm -rf "${builddir:?}"/*
fi

# Create an install directory
mkdir -p "${installdir}"
if "${doclean}"
then
  rm -rf "${installdir:?}"/*
fi

# Set up log files
mkdir -p "${logdir}"
logf="${logdir}"/"executorch-runtime-$(date +%Y%m%d-%H%M%S)".log
touch "${logf}"

cd "${builddir}"
echo "Starting at $(date)" 2>&1 | tee -a "${logf}"

if [ -f "${MODEL_FILE_PATH}" ]
then
    if [[ ${MODEL_FILE_PATH} == *.pte.inc ]]
    then
	echo "Specified model is already a C byte array." 2>&1 | \
	    tee -a "${logf}"
	export MODEL_PATH="${MODEL_FILE_PATH}"
    elif [[ ${MODEL_FILE_PATH} == *.pte ]] 
    then
	echo "Generating C byte array from model." 2>&1 | tee -a "${logf}"
	modelname=$(basename "${MODEL_FILE_PATH}")
	xxd -i < "${MODEL_FILE_PATH}" > "${builddir}"/"${modelname}".inc
	export MODEL_PATH="${builddir}"/"${modelname}".inc
    else
	echo "Could not create model include file" 2>&1 | tee -a "${logf}"
    fi
fi

# Build the Executorch runtime components and executor runner
cd "${builddir}"

echo "Configuring Executorch Runtime..." 2>&1 | tee -a "${logf}"

cmake -G"${BUILD_CMAKE_GENERATOR}" \
      -DCMAKE_INSTALL_PREFIX="${installdir}" \
      -DCMAKE_BUILD_TYPE="${BUILD_CMAKE_TYPE}" \
      -DPYTHON_EXECUTABLE=python3 \
      -DEXECUTORCH_BUILD_EXTENSION_RUNNER_UTIL=ON \
      -DEXECUTORCH_BUILD_EXECUTOR_RUNNER=OFF \
      -DEXECUTORCH_BUILD_COREV=ON \
      -DEXECUTORCH_BUILD_COREV_RUNNER=ON \
      -DEXECUTORCH_USE_DL=OFF \
      -DEXECUTORCH_XNNPACK_SHARED_WORKSPACE=OFF \
      -DEXECUTORCH_XNNPACK_ENABLE_KLEIDI=OFF \
      -DEXECUTORCH_BUILD_PTHREADPOOL=OFF \
      -DEXECUTORCH_BUILD_CPUINFO=OFF \
      -DEXECUTORCH_BUILD_GFLAGS=OFF \
      -DEXECUTORCH_ENABLE_LOGGING="${ET_LOGGING}" \
      -DEXECUTORCH_LOG_LEVEL="${ET_LOG_LEVEL}" \
      -DEXECUTORCH_BUILD_KERNELS_OPTIMIZED=OFF \
      -DEXECUTORCH_BUILD_KERNELS_QUANTIZED=ON \
      -DEXECUTORCH_BUILD_PORTABLE_OPS=ON \
      -DVERILATOR_TARGET="${IS_VERILATOR}" \
      "${cmake_extra_defs}" \
      -DFLATC_EXECUTABLE="$(which flatc)" \
      -DCMAKE_VERBOSE_MAKEFILE="${IS_VERBOSE}" \
      -B "${builddir}" -S "${executorchdir}" >> "${logf}" 2>&1

  echo "Building Executorch Runtime..." 2>&1 | tee -a "${logf}"
  cmake --build "${builddir}" -j "$(nproc)" >> "${logf}" 2>&1

  echo "Installing Executorch Runtime in ${installdir}" 2>&1 | \
      tee -a "${logf}"
  cmake --install "${builddir}" >> "${logf}" 2>&1

  echo "Installing Executor Runner in ${installdir}" 2>&1 | \
      tee -a "${logf}"
  cp "${builddir}"/backends/corev/corev_runner \
     "${installdir}"/executor_runner >> "${logf}" 2>&1

  echo "Creating hexdump in ${installdir}" 2>&1 | tee -a "${logf}"
  ${build_target}-objcopy -O verilog \
      "${installdir}/executor_runner" "${installdir}/executor_runner.hex"

echo Finishing at "$(date)" 2>&1 | tee -a "${logf}"
