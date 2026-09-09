# Copyright (C) 2025 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: BSD-3-Clause

cmake_minimum_required(VERSION 3.21)

if (NOT DEFINED ENV{MODEL_PATH})
  message(FATAL_ERROR "Environment Variable MODEL_PATH not set!")
endif()

#set(TOOLCHAIN_PATH $ENV{TOOLCHAIN_INSTALL})
set(MODEL_PATH $ENV{MODEL_PATH})
#set(DATA_PATH $ENV{DATA_PATH})
set(CRT0_PATH $ENV{EXECUTORCH_CRT0})

set(CMAKE_SYSTEM_NAME Generic)

set(CMAKE_CROSSCOMPILING TRUE)

set(CMAKE_ASM_FLAGS_RELEASE "")
set(CMAKE_ASM_FLAGS_RELWITHDEBINFO "")
set(CMAKE_ASM_FLAGS_DEBUG "")
set(CMAKE_C_FLAGS_RELEASE "")
set(CMAKE_C_FLAGS_RELWITHDEBINFO "")
set(CMAKE_C_FLAGS_DEBUG "")
set(CMAKE_CXX_FLAGS_RELEASE "")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "")
set(CMAKE_CXX_FLAGS_DEBUG "")

# Gated on 'DBG_KEEP_PIC' env variable so we can compare it on and off
if (NOT DEFINED ENV{DBG_KEEP_PIC})
  set(CMAKE_POSITION_INDEPENDENT_CODE OFF)
endif()

# Gated on 'DBG_NO_IPO' env variable so we can compare it on and off
if (NOT DEFINED ENV{DBG_NO_IPO})
  set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE TRUE) # Enables LTO for release builds
endif()

set(CMAKE_C_COMPILER riscv32-corev-elf-gcc)
set(CMAKE_ASM_COMPILER riscv32-corev-elf-gcc)
set(CMAKE_CXX_COMPILER riscv32-corev-elf-g++)
set(CMAKE_LINKER riscv32-corev-elf-ld)
#set(CMAKE_SYSROOT ${TOOLCHAIN_PATH}/${SYSROOT_TARGET})

set(CMAKE_OBJCOPY riscv32-corev-elf-objcopy)
set(CMAKE_OBJDUMP riscv32-corev-elf-objdump)
set(CMAKE_AR riscv32-corev-elf-ar)
set(CMAKE_RANLIB riscv32-corev-elf-ranlib)

set(CMAKE_C_STANDARD 23)
set(CMAKE_CXX_STANDARD 20)

set(ISA "$ENV{EXECUTORCH_RV_ISA}")
set(ABI "$ENV{EXECUTORCH_RV_ABI}")
set(LINKER_SCRIPT "$ENV{EXECUTORCH_LDSCRIPT}")
set(BSP_LIBDIR "$ENV{EXECUTORCH_BSP_LIBDIR}")
set (CRTBEGIN "$ENV{EXECUTORCH_CRTBEGIN}")
set (CRTEND "$ENV{EXECUTORCH_CRTEND}")
set(CMAKE_CXX_FLAGS_INIT "${CMAKE_CXX_FLAGS_INIT} -march=${ISA} -mabi=${ABI} -fno-strict-aliasing")
set(CMAKE_C_FLAGS_INIT "${CMAKE_C_FLAGS_INIT} -march=${ISA} -mabi=${ABI} -fno-strict-aliasing")
set(CMAKE_ASM_FLAGS_INIT "${CMAKE_ASM_FLAGS_INIT} -march=${ISA} -mabi=${ABI} -fno-strict-aliasing")

add_compile_options(
    $<$<CONFIG:Release>:-Os>

    $<$<CONFIG:RelWithDebInfo>:-Os>
    $<$<CONFIG:RelWithDebInfo>:-g>

    $<$<CONFIG:Debug>:-O1> # O0 code size too big
    $<$<CONFIG:Debug>:-g3>
    $<$<CONFIG:Debug>:-ggdb>
)

# Propagate log disabled definition to all targets (similar to upstream
# da2223fcf99fc2214a61321d842e0c953dc5dd16)
if(NOT EXECUTORCH_ENABLE_LOGGING)
  add_compile_definitions(ET_LOG_ENABLED=0)
else()
  add_compile_definitions(ET_LOG_ENABLED=1)
endif()

add_compile_definitions(__panther__ VERILATOR)
add_compile_definitions(RUNNER_MODEL_PATH="${MODEL_PATH}")
add_compile_options(-ffunction-sections -fdata-sections -nostartfiles -fno-PIC)
add_link_options(-march=${ISA} -mabi=${ABI} -lm -v -static --specs=nosys.specs --specs=nano.specs -Wl,--gc-sections -nostartfiles ${CRTBEGIN} ${CRTEND} -T${LINKER_SCRIPT} -L${BSP_LIBDIR} -lcv-verif )

message(STATUS Using toolchain: "${TOOLCHAIN_PATH}")
