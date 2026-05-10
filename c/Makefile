# ============================================================================
# c/Makefile — PULPino UVM 固件编译
#
# 功能：将 C 测试程序编译为 RISC-V 裸机固件，生成仿真所需的内存加载文件
#
# 产物：
#   firmware.elf  — RISC-V 可执行文件（含符号信息，用于调试）
#   firmware.hex  — Verilog $readmemh 格式的十六进制文件（字节地址）
#   firmware.dump — 反汇编输出（用于分析编译结果）
#   firmware.slm  — SLM 格式文件（PULPino 仿真用，已转为字地址）
#
# 用法：
#   make CTEST=tc_uart_hello OUT=./build/tc_uart_hello all
#   make clean
# ============================================================================

# ---------------------------------------------------------------------------
# 工具链配置
# ---------------------------------------------------------------------------
# 使用 Ubuntu 的 RISC-V 交叉编译工具链
# 注意：原始 PULPino 使用 riscv32-unknown-elf-gcc（bare-metal 工具链），
# 但 Docker 容器中安装的是 riscv64-linux-gnu-gcc。
# 通过 -march=rv32i -mabi=ilp32 -ffreestanding 确保生成 32 位裸机代码，
# 不受 64 位工具链前缀影响。
TOOL_CHAIN = riscv64-linux-gnu
CC      = $(TOOL_CHAIN)-gcc         # C 编译器
OBJCOPY = $(TOOL_CHAIN)-objcopy     # 二进制格式转换（ELF → Verilog hex）
OBJDUMP = $(TOOL_CHAIN)-objdump     # 反汇编器

# ---------------------------------------------------------------------------
# 测试用例配置
# ---------------------------------------------------------------------------
# CTEST：选择要编译的测试用例，对应 c/tests/$(CTEST)/main.c
# 可选值：tc_uart_hello, tc_mem_access 等
CTEST    ?= tc_uart_hello
# OUT：编译产物输出目录，由上层 Makefile 传入（如 sim/Makefile），
# 默认为 ./build/$(CTEST)
OUT      ?= ./build/$(CTEST)
# PRJ_ROOT：当前目录的绝对路径，用于构建其他路径
PRJ_ROOT = $(abspath .)

# BOOT_MODE：是否生成 SPI Boot 镜像 (1 为是)
BOOT_MODE ?= 0
ifeq ($(BOOT_MODE), 1)
    BOOT_IMAGE = $(OUT)/boot_image.memh
else
    BOOT_IMAGE =
endif

# ---------------------------------------------------------------------------
# 头文件路径
# ---------------------------------------------------------------------------
# 头文件路径：DV 自身 include + 原始 PULPino 外设寄存器定义
INC_DIR  = $(PRJ_ROOT)/include
PULP_INC = $(PRJ_ROOT)/../repo/pulpino/sw/libs/sys_lib/inc
C_INCLUDES = -I$(INC_DIR) -I$(PULP_INC)

# ---------------------------------------------------------------------------
# 源文件路径
# ---------------------------------------------------------------------------
# startup.S  — RISC-V 启动代码：清零寄存器、设置栈指针、调用 main()
# retarget.c — C 库 retarget：printf 重定向到 UART、end_of_test() 等
# irq.c      — 中断注册与分发
# link.ld    — 链接脚本：定义内存布局和段放置规则
STARTUP  = $(PRJ_ROOT)/sys/startup.S
RETARGET = $(PRJ_ROOT)/lib/retarget.c
IRQ      = $(PRJ_ROOT)/lib/irq.c
UART     = $(PRJ_ROOT)/lib/uart.c
PULP_SRC = $(PRJ_ROOT)/../repo/pulpino/sw/libs/sys_lib/src
SPI      = $(PULP_SRC)/spi.c
GPIO     = $(PULP_SRC)/gpio.c
SPI_EXT  = $(PRJ_ROOT)/lib/spi_ext.c
LINK_LD  = $(PRJ_ROOT)/sys/link.ld

# 测试用例主程序源文件：在 tests 目录下递归搜索匹配 CTEST 的目录
TEST_DIR = $(shell find $(PRJ_ROOT)/tests -name $(CTEST) -type d | head -n 1)
TEST_SRC = $(TEST_DIR)/main.c

# 完整源文件列表：启动代码 + 测试主程序 + 库文件 + 原始 SPI/GPIO 驱动
# 链接顺序影响不大（-T 使用链接脚本控制布局），但启动代码必须包含
SRCS = $(STARTUP) $(TEST_SRC) $(RETARGET) $(IRQ) $(UART) $(SPI) $(GPIO) $(SPI_EXT)

# ---------------------------------------------------------------------------
# 编译选项
# ---------------------------------------------------------------------------
# -march=rv32i     — 目标架构：RV32I 基本整数指令集（32 位 RISC-V）
# -mabi=ilp32      — ABI：int/long/pointer 都是 32 位
# -mcmodel=medany  — 代码模型：允许代码放在任意地址（兼容 64 位工具链）
# -ffreestanding   — 独立环境：不假设标准 C 库存在，不使用内置函数优化
# -O2              — 优化级别 2（平衡性能和代码大小）
# -g               — 生成调试信息（用于 GDB / 波形调试）
# -Wall            — 开启所有常见警告
CFLAGS = -march=rv32i -mabi=ilp32 -mcmodel=medany -ffreestanding -O2 -g
CFLAGS += $(C_INCLUDES) -Wall
CFLAGS += $(EXTRA_CFLAGS)

# -nostartfiles — 不链接 crt0 等启动文件（由 startup.S 提供）
# -nostdlib     — 不链接标准 C 库（由 retarget.c 提供最小实现）
# -T link.ld    — 使用自定义链接脚本控制内存布局
#                 关键：.text 放在 0x80（PULPino reset vector 地址）
LDFLAGS = -nostartfiles -nostdlib -T $(LINK_LD)

# ---------------------------------------------------------------------------
# 构建目标
# ---------------------------------------------------------------------------
.PHONY: all clean info prepare

# 默认目标：编译固件，生成所有产物
# 执行顺序：prepare → firmware.elf → firmware.hex → firmware.slm
#                                  └→ firmware.dump
all: prepare $(OUT)/firmware.hex $(OUT)/firmware.dump $(OUT)/firmware.slm $(BOOT_IMAGE)

# 创建输出目录
prepare:
	@mkdir -p $(OUT)

# 步骤 1：编译链接 → ELF
# 将所有 .S 和 .c 源文件编译并链接为 RISC-V ELF 可执行文件
$(OUT)/firmware.elf: $(SRCS)
	@echo "[GCC] Building $(CTEST) ELF..."
	$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@

# 步骤 2：ELF → Verilog Hex
# 提取 .text（代码）、.rodata（只读数据）、.data（初始化数据）段，
# 输出为 Verilog $readmemh 格式的十六进制文件
# 格式：每行一个字节，@地址 表示起始地址
$(OUT)/firmware.hex: $(OUT)/firmware.elf
	@echo "[OBJCOPY] Generating Verilog Hex..."
	$(OBJCOPY) -O verilog -j .text -j .rodata -j .data $< $@

# 步骤 3：ELF → 反汇编
# 生成带源码注释的反汇编文件，用于调试和验证链接结果
$(OUT)/firmware.dump: $(OUT)/firmware.elf
	@echo "[OBJDUMP] Generating Disassembly..."
	$(OBJDUMP) -S -d $< > $@

# 步骤 4：Hex → SLM
# 将 Verilog hex 转换为 PULPino 仿真用的 SLM 格式
# SLM 格式特点：
#   - 字地址（hex 文件中的字节地址 ÷ 4）
#   - 小端序重组（RISC-V 是小端序，hex 文件按字节存储）
#   - 每行一个 32 位字，供 $readmemh 使用
$(OUT)/firmware.slm: $(OUT)/firmware.hex
	@echo "[HEX2SLM] Converting to SLM format..."
	python3 $(PRJ_ROOT)/hex2slm.py $(OUT)/firmware.hex $(OUT)/firmware.slm

# 步骤 5：生成 SPI Boot 镜像（仅当 BOOT_MODE=1 时）
$(OUT)/instr.bin: $(OUT)/firmware.elf
	@echo "[OBJCOPY] Extracting instructions (.text + .rodata)..."
	$(OBJCOPY) -O binary -j .text -j .rodata $< $@

$(OUT)/data.bin: $(OUT)/firmware.elf
	@echo "[OBJCOPY] Extracting data (.data)..."
	$(OBJCOPY) -O binary -j .data $< $@

$(OUT)/boot_image.memh: $(OUT)/instr.bin $(OUT)/data.bin
	@echo "[ELF2FLASH] Packaging SPI Boot Image..."
	python3 $(PRJ_ROOT)/elf2flash.py $(OUT)/instr.bin $(OUT)/data.bin $@

# 打印当前编译配置（用于调试 Makefile 变量）
info:
	@echo "CTEST     : $(CTEST)"
	@echo "OUT       : $(OUT)"
	@echo "SRCS      : $(SRCS)"

# 清理编译产物
clean:
	rm -rf $(OUT)
