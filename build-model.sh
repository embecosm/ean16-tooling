#!/bin/bash

# Build the Verilator model of CV32E40P

# Copyright (C) 2026 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>
# Contributor Paolo Savini <paolo.savini@embecosm.com>

# This file is part of the Embecosm GNU toolchain build system for RISC-V.

# SPDX-License-Identifier: GPL-3.0-or-later

function usage() {
    cat <<EOF
Usage: ./build-model.sh [--clean]   : Remove previous build & ressults
                        [--trace]   : enable VCD tracing
                        [--no-pulp] : disable the PULP extensions
                        [-h|--help] : Print this message.
EOF
}

# Key directories and files
now="$(date +%Y%m%d-%H%M%S)"
topdir="$(dirname "$(pwd)")"
coresimdir="${topdir}/core-v-verif/cv32e40p/sim/core"
coretbdir="${topdir}/core-v-verif/cv32e40p/tb/core"
bspdir="${topdir}/core-v-verif/cv32e40p/bsp"
logdir="${topdir}/logs"
logf="${logdir}/build-model-${now}.log"

# Derived directories needed by the Verilator build system
toolchaindir="$(dirname "$(dirname "$(which riscv32-corev-elf-gcc)")")"
pathandprefix="${toolchaindir}/bin/riscv32-corev-elf-"

# Argument processing
do_clean=false;
do_trace=false;
do_pulp=true;

set +u
until
    opt="$1"
    case "$opt" in
	--clean)
	    do_clean=true
	    ;;
	--trace)
	    do_trace=true
	    ;;
	--no-pulp)
	    do_pulp=false;
	    ;;
	-h|--help)
	    usage
	    exit 0
	    ;;
	?*)
	    echo "Unkown argument $1"
	    usage
	    exit 1
	    ;;
	*)
	    ;;
    esac
    [[ "${opt}" == "" ]]
do
    shift
done
set -u

# Set up logging
mkdir -p "${logdir}"
rm -f "${logf}"
touch "${logf}"

echo "Verilator model build started at ${now}" | tee "${logf}"
echo "Logging to ${logf}" | tee -a "${logf}"

# Clean up if needed
if "${do_clean}"
then
    echo "cleaning..." 2>&1 | tee -a "${logf}"
    rm -rf "${coresimdir}/cobj_dir"
    rm -rf "${coresimdir}/simulation_results"
fi

# Fixup PULP extension support
if ${do_pulp}
then
    cd "${coretbdir}" || exit
    # Delete any old change to avoid duplicates
    sed -i tb_top_verilator.sv -e '/\.COREV_PULP/d'
    sed -i tb_top_verilator.sv -e 's/\(\.COREV_CLUSTER[[:space:]]\+(0),\)/\1\n          .COREV_PULP        (1),/'
fi

# Build is done in tree
echo "building model..." 2>&1 | tee -a "${logf}"
cd "${coresimdir}" > /dev/null 2>&1 || exit

# Fixup tracing
if ${do_trace}
then
    sed -i Makefile -e '/^WAVES/s/[01]/1/'
else
    sed -i Makefile -e '/^WAVES/s/[01]/0/'
fi

export CV_SW_TOOLCHAIN="${toolchaindir}"
export CV_SW_PREFIX="${pathandprefix}"

if ! make verilate >> "${logf}" 2>&1
then
    echo "- Verilating failed"  | tee -a "${logf}"
    echo "Verilator model build failed at $(date +%Y%m%d-%H%M%S)" | \
	tee -a "${logf}"
    exit 1
fi

if ! make -C cobj_dir -f Vtb_top_verilator.mk >> "${logf}" 2>&1
then
    echo "- compiling model failed"  | tee -a "${logf}"
    echo "Verilator model build failed at $(date +%Y%m%d-%H%M%S)" | \
	tee -a "${logf}"
    exit 1
fi

# Restore tracing
git checkout Makefile > /dev/null 2>&1

# Build the BSP
echo "building BSP..." 2>&1 | tee -a "${logf}"

export RISCV_EXE_PREFIX="${pathandprefix}"
export CV_SW_MARCH="rv32imac_zicsr"

cd "${bspdir}" > /dev/null 2>&1 || exit

# patch the source
sed -i -e 's/jal ra,/call/' -e 's/Jal ra,/call/' handlers.S

# Now a clean build of the BSP
make clean
if ! make CFLAGS="-Os -g -static -mabi=ilp32 -march=rv32imc_zicsr" \
     >> "${logf}" 2>&1
then
    echo "- BSP build failed"  | tee -a "${logf}"
    echo "Verilator model build failed at $(date +%Y%m%d-%H%M%S)" | \
	tee -a "${logf}"
    exit 1
fi

# Success
echo "Verilator model build succeeded at $(date +%Y%m%d-%H%M%S)" |
    tee -a "${logf}"
exit 0
