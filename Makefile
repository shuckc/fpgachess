# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0

# Makefile

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

COMPILE_ARGS+= -Wall -Wimplicit
RUN_ARGS += -Wall -Wimplicit

# these pass to vvp
# EXTRA_ARGS+= -Wimplicit
# SIM_ARGS += -Wall -Wimplicit

VERILOG_SOURCES += $(PWD)/hw/fen_decode.sv $(PWD)/hw/test_fen_decode.sv $(PWD)/hw/onehot_to_bin.sv
VERILOG_SOURCES += $(PWD)/hw/ascii_int_to_bin.sv

TOPLEVEL = test_top

# MODULE is the basename of the Python test file
MODULE = tests.test_fen_decode

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
