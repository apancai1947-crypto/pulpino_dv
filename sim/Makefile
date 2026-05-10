# sim/Makefile — PULPino UVM verification environment (VCS)
PROJ_ROOT := $(abspath ..)
PULP_ROOT := $(PROJ_ROOT)/repo/pulpino
DEBUG     ?= 0
TEST      ?= pulpino_uart_test
CTEST     ?= tc_uart_hello
VERBOSITY ?= UVM_MEDIUM
XPROP     ?= 0
COV       ?= 0
USE_ZERO_RISCY ?= 0
RISCY_RV32F    ?= 0
ZERO_RV32M     ?= 1
ZERO_RV32E     ?= 0
OUT       := $(PROJ_ROOT)/debug/$(TEST)_$(CTEST)
FW_OUT    := $(OUT)/fw

# VIP 路径统一管理
SVT_VIP_BASE     ?= /opt/sv_pkgs/uvm/svt_2018.09
SVT_UART_DIR 	 ?= $(SVT_VIP_BASE)/svt_uart
SVT_SPI_DIR  	 ?= $(SVT_VIP_BASE)/svt_spi
SVT_I2C_DIR  	 ?= $(SVT_VIP_BASE)/svt_i2c

# ============================================
# Source file list
# ============================================
SV_SOURCES := -f $(PROJ_ROOT)/sim/filelist.f

# ============================================
# VCS compile options
# ============================================
VCS_BASE_OPTS := -full64 -sverilog -ntb_opts uvm-1.2 \
	+incdir+$(SVT_UART_DIR)/include/verilog \
	+incdir+$(SVT_UART_DIR)/include/sverilog \
	+incdir+$(SVT_UART_DIR)/src/verilog/vcs \
	+incdir+$(SVT_UART_DIR)/src/sverilog/vcs \
	+incdir+$(SVT_SPI_DIR)/include/verilog \
	+incdir+$(SVT_SPI_DIR)/include/sverilog \
	+incdir+$(SVT_SPI_DIR)/src/verilog/vcs \
	+incdir+$(SVT_SPI_DIR)/src/sverilog/vcs \
	+incdir+$(SVT_I2C_DIR)/include/verilog \
	+incdir+$(SVT_I2C_DIR)/include/sverilog \
	+incdir+$(SVT_I2C_DIR)/src/verilog/vcs \
	+incdir+$(SVT_I2C_DIR)/src/sverilog/vcs \
    +incdir+$(PULP_ROOT)/rtl/includes \
    +incdir+$(PULP_ROOT)/tb \
    +incdir+$(PROJ_ROOT)/tb \
    +incdir+$(PROJ_ROOT)/tb/env \
    +incdir+$(PROJ_ROOT)/tests \
    +incdir+$(PROJ_ROOT)/seq_lib \
    +incdir+$(PULP_ROOT)/ips/riscv/include \
    +incdir+$(PULP_ROOT)/ips/zero-riscy/include \
    +incdir+$(PULP_ROOT)/ips/apb/apb_event_unit/include \
	+incdir+$(PULP_ROOT)/ips/apb/apb_i2c \
    +incdir+$(PULP_ROOT)/ips/adv_dbg_if/rtl \
    +incdir+$(PULP_ROOT)/ips/axi/axi_node \
	+define+SVT_UVM_TECHNOLOGY \
	+define+SVT_UART \
	+define+SVT_SPI \
	+define+SVT_SPI_IO_WIDTH=4 \
	+define+SVT_I2C \
    -timescale=1ns/1ps \
    -Mdir=$(OUT)/csrc \
    +vcs+lic+wait

ifeq ($(DEBUG), 0)
    DBG_OPTS :=
    SIM_OPTS := +TIMEOUT_NS=10000000 +UVM_VERBOSITY=$(VERBOSITY) +FW_SLMS=$(FW_OUT)/l2_stim.slm +FW_SLMD=$(FW_OUT)/tcdm_bank0.slm \
                +UART_DATA_WIDTH=8 +UART_PARITY_TYPE=0 +UART_STOP_BIT=0 +UART_DISABLE_HW_HANDSHAKE
else ifeq ($(DEBUG), 1)
    DBG_OPTS := -debug_access+pp -kdb -lca
    SIM_OPTS := +TIMEOUT_NS=10000000 +UVM_VERBOSITY=$(VERBOSITY) +FW_SLMS=$(FW_OUT)/l2_stim.slm +FW_SLMD=$(FW_OUT)/tcdm_bank0.slm \
                +UART_DATA_WIDTH=8 +UART_PARITY_TYPE=0 +UART_STOP_BIT=0 +UART_DISABLE_HW_HANDSHAKE
else ifeq ($(DEBUG), 2)
    DBG_OPTS := -debug_access+all -kdb -lca -fsdb +define+FSDB_DUMP
    SIM_OPTS := +TIMEOUT_NS=10000000 +UVM_VERBOSITY=$(VERBOSITY) +DUMP_WAVE +FW_SLMS=$(FW_OUT)/l2_stim.slm +FW_SLMD=$(FW_OUT)/tcdm_bank0.slm \
                +FSDB_FILE=$(OUT)/novas.fsdb \
                +UART_DATA_WIDTH=8 +UART_PARITY_TYPE=0 +UART_STOP_BIT=0 +UART_DISABLE_HW_HANDSHAKE
endif

ifeq ($(XPROP), 1)
    XPROP_OPTS := -xprop=tmerge
endif

ifeq ($(COV), 1)
    COV_COMP_OPTS := -cm line+cond+fsm+branch+tgl +define+COV
    COV_SIM_OPTS  := -cm line+cond+fsm+branch+tgl \
                     -cm_dir $(OUT)/coverage.vdb -cm_name $(TEST)
endif

VCS_OPTS := $(VCS_BASE_OPTS) $(DBG_OPTS) $(XPROP_OPTS) $(COV_COMP_OPTS)

# ============================================
# Targets
# ============================================
.PHONY: fw comp sim all clean verdi info check-ips

all: fw comp sim

info:
	@echo "PROJ_ROOT       : $(PROJ_ROOT)"
	@echo "PULP_ROOT       : $(PULP_ROOT)"
	@echo "TEST            : $(TEST)"
	@echo "CTEST           : $(CTEST)"
	@echo "VERBOSITY       : $(VERBOSITY)"
	@echo "USE_ZERO_RISCY  : $(USE_ZERO_RISCY)"
	@echo "OUT             : $(OUT)"
	@echo "DESIGNWARE_HOME : $(DESIGNWARE_HOME)"

check-ips:
	@if [ ! -f "$(PULP_ROOT)/ips/riscv/riscv_core.sv" ] && \
	    [ ! -f "$(PULP_ROOT)/ips/zero-riscy/zeroriscy_core.sv" ]; then \
	    echo "[ERROR] IP submodules not cloned. Run: cd $(PULP_ROOT) && ./update-ips.py"; \
	    exit 1; \
	fi

fw:
	@echo "[GCC] Compiling firmware CTEST=$(CTEST) → $(FW_OUT)..."
	@rm -rf $(FW_OUT)
	@mkdir -p $(FW_OUT)
	$(MAKE) -C $(PROJ_ROOT)/c OUT=$(FW_OUT) CTEST=$(CTEST) BOOT_MODE=$(BOOT_MODE) all
	@cp $(FW_OUT)/firmware.slm $(FW_OUT)/l2_stim.slm
	@echo "@00000000 00000000" > $(FW_OUT)/tcdm_bank0.slm

comp: check-ips fw
	@mkdir -p $(OUT)
	@echo "[VCS] Compiling $(TEST) → $(OUT)..."
	cd $(PROJ_ROOT) && vcs $(VCS_OPTS) $(SV_SOURCES) -top tb_top \
	    -o $(OUT)/simv -l $(OUT)/compile.log

sim:
	@echo "[SIM] Running $(TEST) → $(OUT)/simv.log"
	cd $(OUT) && $(OUT)/simv $(SIM_OPTS) $(COV_SIM_OPTS) \
	    +UVM_TESTNAME=$(TEST) -l $(OUT)/simv.log

verdi:
	cd $(OUT) && verdi -nologo -dbdir $(OUT)/simv.daidir \
	    -ssf $(OUT)/novas.fsdb &

clean:
	rm -rf $(PROJ_ROOT)/debug/*