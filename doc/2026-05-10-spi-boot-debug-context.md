# PULPino SPI Boot 调试上下文

> **用途**：AI 跨会话上下文交接文件。将此文件加入 AI 的上下文后，可直接继续调试任务，无需重新说明背景。
>
> **最后更新**：2026-05-10

---

## 1. 任务目标

调试 PULPino SoC 的 SPI Boot 流程，使仿真中 CPU 能够：

1. 从 Boot ROM（`0x8080`）启动，执行 bootloader
2. Bootloader 通过 SPI 从 Flash VIP（Synopsys SVT SPI Slave）读取固件镜像
3. 将固件复制到指令 RAM（`0x0000~0x7FFF`）和数据 RAM
4. 跳转到指令 RAM 入口（`instr_base = 0x00000000`，即 CPU 地址 `0x80`）
5. 固件中的 `end_of_test()` 触发 stdout 监视器的 EOT 事件，测试通过

**当前症状**：CPU 卡在 PC=`0x000081e2`，指令 `0x00010001`（非法指令），永远不跳转到用户代码。

---

## 2. 工程目录结构

```
pulpino_dv/
├── c/                        # 固件编译工具
│   ├── Makefile              # 编译入口，BOOT_MODE=1 时生成 boot_image.memh
│   ├── elf2flash.py          # ELF → SPI Flash 镜像格式转换
│   ├── tests/tc_spi_boot/    # SPI Boot 测试固件（main.c）
│   ├── sys/                  # startup.S, link.ld
│   └── lib/                  # retarget.c, uart.c, spi_ext.c 等
├── tb/
│   ├── tb_top.sv             # 顶层 testbench（含 TRACE_PC 调试逻辑）
│   └── env/soc_env.sv        # UVM 环境（含 SPI VIP 配置）
├── tests/
│   └── pulpino_spi_boot_test.sv  # UVM test（加载 boot_image.memh 到 SPI VIP）
├── test/
│   └── pulpino_spi_test.py   # Python case 定义（tc_spi_boot）
├── sim/
│   └── run_case.py           # 仿真运行入口
├── repo/pulpino/             # PULPino 原始 RTL（submodule，禁止修改）
│   ├── rtl/boot_code.sv      # Boot ROM 内容（编译好的指令，只读）
│   ├── rtl/core_region.sv    # CPU core 例化（generate block CORE → RISCV_CORE）
│   ├── rtl/instr_ram_wrap.sv # 指令 RAM + Boot ROM 仲裁
│   └── ips/apb/apb_spi_master/ # SPI Master 控制器 RTL
└── doc/
    ├── boot_mode.md          # SPI Boot 原理说明
    └── 2026-05-10-spi-boot-debug-context.md  # 本文件
```

---

## 3. 工具链

### 3.1 仿真环境

| 工具 | 说明 |
|------|------|
| Docker 容器 `my_eda` | 所有仿真必须在此容器内运行（含 VCS、license） |
| VCS（Synopsys） | 仿真器，路径 `/usr/synopsys/vc_static-O-2018.09-SP2-2/vcs-mx/` |
| Synopsys SVT SPI VIP | `/opt/sv_pkgs/uvm/svt_2018.09/svt_spi/` |
| UVM 1.2 | `-ntb_opts uvm-1.2` |

### 3.2 固件编译链

| 工具 | 说明 |
|------|------|
| `riscv64-linux-gnu-gcc` | RISC-V 交叉编译器（Docker 内，用 `-march=rv32i -mabi=ilp32`） |
| `riscv64-linux-gnu-objcopy` | ELF → binary / verilog hex |
| `python3 c/elf2flash.py` | 生成 SPI Flash 镜像 `boot_image.memh` |

### 3.3 运行命令

```bash
# 在 Docker 内运行
docker exec my_eda bash -c "cd /root/work/dv-flow/pulpino_dv/sim && python3 run_case.py tc_spi_boot"

# 查看仿真日志
docker exec my_eda tail -n 100 /root/work/dv-flow/pulpino_dv/debug/tc_spi_boot/simv.log

# 查看编译日志
docker exec my_eda cat /root/work/dv-flow/pulpino_dv/debug/.b0529a91/compile.log
```

---

## 4. 执行前必须注意的事项

### 4.1 环境预处理

```bash
# 重新编译前，必须删除旧的编译缓存（否则 VCS 使用旧 simv）
docker exec my_eda rm -rf /root/work/dv-flow/pulpino_dv/debug/

# 如果有 simv 进程卡住，先 kill
docker exec my_eda bash -c "killall -9 simv 2>/dev/null; true"
```

### 4.2 禁止修改 submodule

`repo/pulpino/` 是 Git submodule，**禁止任何修改**。所有调试手段必须通过：
- `tb/tb_top.sv`（testbench 信号探测）
- `tb/env/soc_env.sv`（VIP 配置）
- `tests/pulpino_spi_boot_test.sv`（UVM test 逻辑）

### 4.3 打印规范

**所有 SystemVerilog 代码中的打印必须使用 `uvm_info`，禁止使用 `$display`。**

唯一例外：`TRACE_PC` 调试块目前使用 `$display`（因为它在 `initial` 块中监控硬件信号，不走 UVM 阶段），可保留。

---

## 5. 关键设计知识

### 5.1 PULPino SPI Boot 原理

```
复位释放
   ↓
fetch_enable = 1
   ↓
boot_addr 默认 = 0x8000（apb_pulpino.sv 参数）
   ↓
CPU reset vector = {boot_addr[31:8], 0x80} = 0x00008080
   ↓
地址 0x8080 → instr_ram_wrap → is_boot = addr[15] = 1 → Boot ROM
   ↓
Boot ROM (boot_code.sv) 执行 bootloader：
   1. spi_setup_master(1)  — 配置 SPI Master 引脚
   2. 读 Flash ID (0x9F)   — 验证 Spansion Flash（ID: 0x0102194D）
   3. 读 Header (cmd 0xEB) — 从 Flash addr=0 读 8 个 32-bit word
   4. 循环读 Instr 块 (0xEB + QUAD mode，8 dummy cycles)
      → 写入指令 RAM (从 0x00000000 开始)
   5. 循环读 Data 块
      → 写入数据 RAM (从 0x00100000 开始)
   6. BOOTREG = 0x00       — 写 apb_pulpino BOOTREG
   7. jump_and_start(0x00000000) — jalr x0, ptr
```

### 5.2 Flash 镜像格式（boot_image.memh）

由 `c/elf2flash.py` 生成，格式为字节序 hex（每行一个字节），SPI VIP 用 `$readmemh` 加载：

```
Offset 0x000: Header (32 bytes = 8 words)
  [0] instr_start  = 0x20      (flash 内指令数据的起始 offset，= 32字节)
  [1] instr_base   = 0x00000000 (指令写入 RAM 的目标地址)
  [2] instr_size   = N bytes
  [3] instr_blocks = N / 4096  (4KB 为单位的块数)
  [4] data_start   = 0x20 + instr_padded_size
  [5] data_base    = 0x00100000 (数据写入 RAM 的目标地址)
  [6] data_size    = M bytes
  [7] data_blocks  = M / 4096
Offset 0x020: instr 二进制（按 4KB 对齐）
Offset 0x020+N*4KB: data 二进制（按 4KB 对齐）
```

**字节序**：SPI Master 按 MSB 先发，spi_read_fifo 以 32-bit word 的 big-endian 形式填充。
当前 `elf2flash.py` 输出为 little-endian 字节序，这可能导致 header 解析错误。

### 5.3 层次结构路径（VCS cross-module reference）

正确的 CPU 信号访问路径（已验证可编译）：

```systemverilog
// CPU 取指信号
dut.core_region_i.CORE.RISCV_CORE.instr_req_o
dut.core_region_i.CORE.RISCV_CORE.instr_gnt_i
dut.core_region_i.CORE.RISCV_CORE.instr_rvalid_i
dut.core_region_i.CORE.RISCV_CORE.instr_rdata_i
dut.core_region_i.CORE.RISCV_CORE.pc_if          // IF 阶段 PC
// 寄存器文件（ra = x1 = mem[1]）
dut.core_region_i.CORE.RISCV_CORE.id_stage_i.registers_i.mem[1]
```

**层次说明**：
- `core_region` 中有 `generate ... if ... begin: CORE` 块
- 块内例化 `riscv_core` 为 `RISCV_CORE`
- 因此路径为 `CORE.RISCV_CORE`（不是 `riscv_core_i`）

### 5.4 SPI VIP 配置

- VIP 类型：Synopsys SVT SPI，slave 模式（模拟 Flash）
- 关键参数：`SVT_SPI_DATA_WIDTH=8`，`SVT_SPI_IO_WIDTH=4`，`SVT_SPI_MAX_NUM_SLAVES=4`
- 镜像加载：`env.spi_master_agent.mem_sequencer.backdoor.load("boot_image.memh", 0)`
- **注意**：SPI VIP 配置中 `part_name` 字段不存在，已移除

---

## 6. 已踩过的坑

| 坑 | 问题描述 | 解决方案 |
|----|---------|---------|
| **XMR 路径错误 1** | 用 `riscv_core_i` 访问 CPU 信号 → XMRE 编译报错 | 正确路径是 `CORE.RISCV_CORE`（generate 块名） |
| **XMR 路径错误 2** | 用 `CORE.instr_req_o` → XMRE 编译报错 | generate 块不是模块层次，需加 `RISCV_CORE` |
| **SPI VIP part_name** | `soc_env.sv` 里设置 `part_name` → 编译报错 | SVT SPI VIP 无此属性，已删除 |
| **elf2flash 字节序** | 原始 `elf2flash.py` 输出 word-per-line → VIP 加载错误 | 改为 byte-per-line 输出 |
| **force 失效** | 尝试 force `clk_gate_q` 和 `pad_mux_q` 无效（路径推测错误） | 已删除该 force，等待验证原始流程 |
| **编译缓存** | 不删 `debug/` 导致 VCS 用旧 simv，误以为已修复 | 每次重编前必须 `rm -rf debug/` |
| **Flash ID 验证** | boot_code.c 会验证 Flash ID（0x0102194D），VIP 需返回正确 ID | VIP 为 generic model，默认返回 0，可能导致 boot 中止 |

---

## 7. 当前调试状态

### 7.1 TRACE_PC 输出分析

当前仿真输出（TRACE_PC）显示：

```
[TRACE_PC] @ 1420000 | PC: 0x00000000 | Instr: 0x0100006f | ra: 0x00000000
  ← CPU 从 0x0000 复位向量起跳（这是 boot_rom 的入口跳转指令）

[TRACE_PC] @ 1500000 | PC: 0x00008084 | Instr: 0x00000093
  ← 跳转到 Boot ROM 区域（0x8084），开始执行 bootloader

[TRACE_PC] @ 3340000 | PC: 0x000081b0 | ra: 0x00008140
  ← boot_code 开始执行 SPI 操作（大量寄存器配置）

[TRACE_PC] @ 3980000 | PC: 0x00008428 | ra: 0x000081ce
  ← 进入 uart_send / spi_xxx 等函数调用

[TRACE_PC] @ 44220000 | PC: 0x000081e2 | Instr: 0x00010001 | ra: 0x000081d6
  ← 卡住！无限循环，指令 0x00010001 不是合法 RISC-V 指令
```

**关键线索**：
- PC `0x81e2` 位于 boot ROM 区域（`0x8000~0x9FFF`）
- 指令 `0x00010001` = `c.addi x0, 0`（C 扩展的 hint 指令）或非法操作码
- `ra = 0x000081d6`，说明从 `0x81d6` 附近调用过来
- CPU 从未跳到 `0x00000080`（指令 RAM），意味着 `jump_and_start` 未执行

### 7.2 当前推测的根本原因

**假说 A（最可能）：Flash ID 验证失败**
- boot_code.c 第 46 行：`if (check_spi_flash()) { uart_send("ERROR..."); while(1); }`
- 若 SPI VIP 返回错误 Flash ID → Boot ROM 进入 `while(1)` 死循环
- 死循环地址正好是 0x81e2 附近

**假说 B：spi_read_fifo 字节序错误导致 Header 解析错误**
- 即使通过了 Flash ID 检查，如果 header 中 `instr_blocks=0`，则不复制任何数据
- 然后 `jump_and_start(0x0)` 执行，但 RAM 内容为空，CPU 取到 `0x00000000`（非法指令）

**假说 C：SPI Master → VIP 握手未完成**
- SPI 事务因 VIP 配置不当挂起，导致 `spi_get_status()` 轮询永不结束

### 7.3 已确认正常的部分

- ✅ `tb_top.sv` 编译通过（TRACE_PC 路径正确）
- ✅ Boot ROM 确实被执行（PC 序列从 0x8080 开始）
- ✅ `boot_image.memh` 由 `elf2flash.py` 生成
- ✅ SPI VIP slave 已加载 memh（`backdoor.load` 调用）
- ✅ `tc_spi_boot` 在 `pulpino_spi_test.py` 中已正确定义

---

## 8. 接下来的调试方向

### 优先级 1：验证 Flash ID 返回值

**方法**：在 `TRACE_PC` 旁边增加 APB monitor 打印，或在 `tb_top.sv` 中监控 SPI RXFIFO 内容。

具体步骤：
1. 在 `tb_top.sv` 中添加 `initial` 块，监控 SPI rxfifo 的 first word
2. 如果 ID 全为 0，需要：
   - 方案 A：在 `pulpino_spi_boot_test.sv` 中配置 VIP 的 memory model，预填写 Flash ID 字节
   - 方案 B：在 VIP 的 slave configuration 中设置正确的 JEDEC ID

### 优先级 2：在 boot_code 关键决策点插桩

监控以下 APB 写操作（boot_code.c 的关键路径）：

```
addr 0x1A100000 = SPI Master 基址
SPI_REG_STATUS = 0x1A100000 + 0x00
SPI_REG_CLKDIV = 0x1A100000 + 0x04
```

在 `tb_top.sv` 中加入：
```systemverilog
// 监控 SPI STATUS 寄存器写操作（检测事务启动）
forever @(posedge clk) begin
    if (dut.peripherals_i.apb_spi_master.u_axiregs.PSEL &&
        dut.peripherals_i.apb_spi_master.u_axiregs.PENABLE &&
        dut.peripherals_i.apb_spi_master.u_axiregs.PWRITE) begin
        $display("[SPI_APB] WR addr=0x%02h data=0x%08h",
            dut.peripherals_i.apb_spi_master.u_axiregs.PADDR,
            dut.peripherals_i.apb_spi_master.u_axiregs.PWDATA);
    end
end
```

### 优先级 3：确认 boot_image.memh 字节序

1. 手工检查生成的 `boot_image.memh` 头部：
   - 期望前 4 字节（little-endian word）= `0x00000020`（header[0] = instr_start = 32）
   - 如果顺序是 `20 00 00 00`（大端字节对调），VIP 读出 word = `0x20000000` → 解析为错误地址

2. SPI Master 的 `spi_read_fifo` 按什么顺序拼装 32-bit word：
   - 查看 `spi_master_rx.sv` 的 shift register 方向
   - 确认 VIP 提供的 byte order 与之匹配

### 优先级 4：绕过 Flash ID 检查（快速验证）

如果 Flash ID 失败是根因，可以临时修改（仅调试用，不提交）：

在 `pulpino_spi_boot_test.sv` 中，预填 VIP memory 的前几字节为正确的 Spansion Flash ID：
```
addr 0: ID response for cmd 0x9F
  期望：0x01 0x02 0x19 0x4D（Spansion S25FL128L）
  或：  0x01 0x20 0x18 xx（S25FL256S）
```

---

## 9. 关键文件清单

| 文件 | 作用 | 当前状态 |
|------|------|---------|
| `tb/tb_top.sv` | SPI Boot 流程控制 + TRACE_PC 调试 | ✅ 编译通过，TRACE_PC 已激活 |
| `tb/env/soc_env.sv` | SPI VIP slave 配置 | ✅ `part_name` 已删除，`data_width=8` |
| `tests/pulpino_spi_boot_test.sv` | UVM test，backdoor 加载 memh | ✅ 已实现 |
| `test/pulpino_spi_test.py` | tc_spi_boot 用例定义 | ✅ 已添加 |
| `c/elf2flash.py` | 生成 boot_image.memh | ✅ 已改为字节序输出 |
| `c/Makefile` | 固件编译，BOOT_MODE=1 生成 memh | ✅ 已配置 |
| `c/tests/tc_spi_boot/main.c` | 测试固件（验证 SPI Boot 成功的用户程序） | ✅ 已创建 |
| `repo/pulpino/rtl/boot_code.sv` | Boot ROM 指令（**只读，不可修改**） | — |
| `repo/pulpino/sw/apps/boot_code/boot_code.c` | Boot ROM 源码（**只读，供参考**） | — |

---

## 10. 快速上手命令

```bash
# 1. 进入工作目录
# （在 Windows 上，以下命令通过 docker exec 执行）

# 2. 查看当前仿真日志（TRACE_PC 输出）
docker exec my_eda bash -c "grep 'TRACE_PC\|BOOT\|SPI\|ERROR' /root/work/dv-flow/pulpino_dv/debug/tc_spi_boot/simv.log | head -n 100"

# 3. 重新运行仿真（先删除编译缓存）
docker exec my_eda bash -c "killall -9 simv 2>/dev/null; true"
docker exec my_eda rm -rf /root/work/dv-flow/pulpino_dv/debug/
docker exec my_eda bash -c "cd /root/work/dv-flow/pulpino_dv/sim && python3 run_case.py tc_spi_boot"

# 4. 只查编译报错
docker exec my_eda bash -c "grep -E 'Error|Warning' /root/work/dv-flow/pulpino_dv/debug/.b0529a91/compile.log | head -n 30"

# 5. 手工检查生成的 boot_image.memh
cat /d/learning/verifier/dv-flow/pulpino_dv/c/build/tc_spi_boot/boot_image.memh | head -n 40
```
