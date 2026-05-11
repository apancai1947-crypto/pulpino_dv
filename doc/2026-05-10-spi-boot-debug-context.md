# PULPino SPI Boot 调试上下文

> **用途**：AI 跨会话上下文交接文件。将此文件加入 AI 的上下文后，可直接继续调试任务，无需重新说明背景。
>
> **最后更新**：2026-05-12
>
> **状态：IN PROGRESS** — ROM size 已修复，CPU 执行到 SPI 轮询后卡死

---

## 1. 任务目标

调试 PULPino SoC 的 SPI Boot 流程，使仿真中 CPU 能够：

1. 从 Boot ROM（`0x8000`）启动，执行 bootloader
2. Bootloader 通过 SPI 从 Flash VIP（Synopsys SVT SPI Slave）读取固件镜像
3. 将固件复制到指令 RAM（`0x0000~0x7FFF`）和数据 RAM
4. 跳转到指令 RAM 入口（`instr_base = 0x00000000`，即 CPU 地址 `0x80`）
5. 固件中的 `end_of_test()` 触发 stdout 监视器的 EOT 事件，测试通过

**当前症状**：CPU 执行 boot ROM 代码正常，进入 SPI 轮询循环后卡死（47ms 超时）。`check_spi_flash()` 中的 `spi_get_status()` 轮询永不返回预期值，说明 SPI VIP 未正确响应事务。

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
│   ├── tb_top.sv             # 顶层 testbench（含 TRACE_PC、SPI_APB monitor）
│   ├── boot_code_patched.sv  # 替代 repo 的 boot_code.sv，使用 $readmemh 加载 hex
│   ├── boot_code.hex         # 从 boot_code.c 交叉编译生成的 ROM 内容（1024 words）
│   ├── build_boot_rom.sh     # 交叉编译 boot_code.c 的脚本
│   ├── s19toboot_py3.py      # S19 → hex/sv 转换器（rom_size=1024）
│   └── env/soc_env.sv        # UVM 环境（含 SPI VIP 配置）
├── tests/
│   └── pulpino_spi_boot_test.sv  # UVM test（加载 boot_image.memh 到 SPI VIP）
├── test/
│   └── pulpino_spi_test.py   # Python case 定义（tc_spi_boot）
├── sim/
│   ├── filelist.f            # VCS 文件列表（line 214 指向 tb/boot_code_patched.sv）
│   └── run_case.py           # 仿真运行入口
├── repo/pulpino/             # PULPino 原始 RTL（submodule，禁止修改）
│   ├── rtl/boot_code.sv      # 原始 Boot ROM（被 boot_code_patched.sv 替代）
│   ├── rtl/boot_rom_wrap.sv  # ROM 包装器：addr_i[11:2] → boot_code.A
│   ├── rtl/instr_ram_wrap.sv # 指令 RAM + Boot ROM 仲裁
│   ├── rtl/includes/config.sv # ROM_ADDR_WIDTH=12, ROM_START_ADDR=0x8000
│   └── sw/apps/boot_code/boot_code.c  # Boot ROM C 源码
└── doc/
    └── 2026-05-10-spi-boot-debug-context.md  # 本文件
```

---

## 3. Boot ROM 构建流程

### 3.1 交叉编译链

```bash
# 在 Docker 容器内执行
docker exec 828e83272623 bash -c "cd /root/work/dv-flow/pulpino_dv/tb && bash build_boot_rom.sh"
```

脚本执行步骤：
1. `riscv64-linux-gnu-gcc -march=rv32i -mabi=ilp32 -O2 -ffreestanding -nostdlib -DBOOT -D__riscv__` 编译 crt0.boot.S、spi.c、uart.c、gpio.c
2. 链接: `-T link.boot.ld -nostartfiles -Wl,--gc-sections -Wl,--build-id=none -nostdlib -lgcc`
3. `objcopy --srec-len 1 --output-target=srec` 生成 S19 文件
4. `python3 s19toboot_py3.py boot_code.s19` 生成 `boot_code.sv` 和 `boot_code.hex`

### 3.2 关键编译参数

| 参数 | 值 | 说明 |
|------|-----|------|
| `rom_size` | 1024 words | `s19toboot_py3.py` 中定义，必须足够容纳整个 boot code |
| `ROM_ADDR_WIDTH` | 12 | `config.sv` 中定义，10-bit word address → 最大 1024 words |
| ROM 起始地址 | 0x8000 | `ROM_START_ADDR` in config.sv |
| 链接脚本 ROM 长度 | 0x2000 (8192 bytes = 2048 words) | `link.boot.ld` 中定义 |

### 3.3 ROM 内存映射

```
instr_ram_wrap (RAM_SIZE=32768):
  ADDR_WIDTH = $clog2(32768) + 1 = 16
  
  addr_i[15] = 1 → Boot ROM (0x8000~0xFFFF)
    boot_rom_wrap: addr_i[ROM_ADDR_WIDTH-1:0] = addr_i[11:0]
      boot_code: A = addr_i[ADDR_WIDTH-1:2] = addr_i[11:2] (10-bit word address)
      
  addr_i[15] = 0 → Instruction RAM (0x0000~0x7FFF)
    sp_ram_wrap: addr_i[ADDR_WIDTH-2:0] = addr_i[14:0]
```

---

## 4. 已完成的修复

### 4.1 Boot ROM size: 548 → 1024 words（2026-05-12）

**根因**：`s19toboot_py3.py` 中 `rom_size = 548`，但编译后的 boot code 需要 ~771 words（text + rodata + data 延伸到 0x8C0C）。

**症状**：
- CPU 在 ROM index 547 (`sw s0, 72(sp)`) 正常执行
- PC+4 = index 548 (0x8890) 超出 ROM 边界，返回 X
- CPU 触发异常，跳转到 exception handler (0x8090)，进入 `j .` 死循环

**修复**：
1. `s19toboot_py3.py`: `rom_size = 548` → `rom_size = 1024`
2. `boot_code_patched.sv`: `mem [0:547]` → `mem [0:1023]`
3. 添加 hex 文件生成到 `s19toboot_py3.py`（之前只生成 .sv 和 .cde）

**验证方法**：
- 在 boot_code_patched.sv 中添加 `$display("[ROM_INIT] ...")` 验证 $readmemh 加载正确
- 添加 ROM_DBG / ROM_HI 调试信号追踪每次 ROM 访问的地址和数据
- 确认 mem[545]=0x00100513, mem[546]=0x04112623, mem[547]=0x04812423 与 hex 文件一致

### 4.2 Flash ID catalog 加载（2026-05-10，上一轮修复）

**根因**：SPI VIP 的 Flash 模型需要通过 catalog 系统初始化完整的 Flash 行为模型。仅设置 `mode_register_cfg` 的 4 个 ID 字段不够。

**修复**：在 `soc_env.sv` 中先加载 S25FL512S catalog，再覆盖 ID 字段。

### 4.3 其他已完成修复（上一轮）

| 问题 | 修复 |
|------|------|
| VCS `-m32` 不支持 | 移除 `-m32`，用 `-march=rv32i -mabi=ilp32` |
| `stdint.h` Linux sysroot 拒绝 RV32 | 加 `-ffreestanding -nostdlib` |
| `set_pin_function` 未定义 | 加 gpio.c 到 sys_lib 编译 |
| OpenRISC `l.jr`/`l.nop` 指令 | 加 `-D__riscv__` 到 CFLAGS |
| `libgcc_s.so` RV64 格式错误 | 加 `-nostdlib -lgcc` |
| `.note.gnu.build-id` 未映射 | 加 `-Wl,--build-id=none` |
| Python 3 `seek` from end 不支持 | 重写 s19toboot_py3.py 为 string list 方式 |
| S19 parser wrong offsets | 重写 parser 正确处理 S1/S2/S3 记录 |
| `$readmemh` 需要 unpacked array | `logic [0:N] [31:0]` → `logic [31:0] mem [0:N]` |

---

## 5. 当前卡住的问题

### 5.1 执行流追踪

ROM size 修复后，CPU 正常执行 boot code：

```
0x0000 → 0x8080: 复位向量跳转
0x8080~0x810C: crt0 初始化（清零寄存器、设置栈指针）
0x8114 (_start): 初始化 .bss、设置中断向量
0x8134 (main_entry): 调用 main()
0x8880 (main):
  → spi_setup_master(1)    @ 0x82F8 → set_pin_function × 4
  → uart_set_cfg(0, 1)     @ 0x8570
  → delay loop 3000 iters   @ 0x88C4~0x88D4
  → *(SPI_REG_CLKDIV) = 4  @ 0x88D8 (write to 0x1A102004)
  → check_spi_flash()       @ 0x8140
    → spi_setup_cmd_addr(0x9F, 8, 0, 0) @ 0x83A0
    → spi_set_datalen(64)   @ 0x83F4
    → spi_setup_dummy(0, 0) @ 0x83D8
    → spi_start_transaction(SPI_CMD_RD, SPI_CSN0) @ 0x842C
    → spi_get_status()      @ 0x845C  ← 轮询 SPI STATUS 寄存器
      → **卡死** — 状态永远不等于 1
```

### 5.2 SPI VIP 连接验证

VIP 配置（soc_env.sv）：
```systemverilog
spi_master_cfg.is_master     = 0;           // Slave role
spi_master_cfg.is_active     = 1;           // Active Slave
spi_master_cfg.frame_format  = svt_spi_types::SPI_FLASH;
spi_master_cfg.enable_mem_core = 1;
spi_master_cfg.spi_mem_cfg.load_prop_vals(catalog_path); // S25FL512S
// Flash ID: mfr=0x01 type=0x02 cap=0x19 dev=0x4D
```

tb_top.sv 连接：
```systemverilog
assign spi_master_vif.sclk    = spi_master_clk_o;
assign spi_master_vif.ss_n[0] = spi_master_csn0_o;
assign spi_master_vif.mosi[0] = spi_master_sdo0_o;
assign spi_master_sdi0_i      = spi_master_vif.miso[0];
// ... (QSPI 4-bit)
```

boot_image.memh 已加载：
```
SNPS/SVT/MEM/SRV/FILE [inst:env.spi_master_agent.mem_core] Loading memory from file: fw/boot_image.memh
```

### 5.3 SPI_APB Monitor 结果

`tb_top.sv` 中有 APB monitor 监控 0x1A102xxx 范围的写操作：
```systemverilog
`ifdef SPI_BOOT_EN
initial begin
    forever begin
        @(posedge clk);
        if (apb_bus.psel && apb_bus.penable && apb_bus.pwrite &&
            apb_bus.paddr[31:12] == 20'h1A102) begin
            `uvm_info("SPI_APB", ...)
        end
    end
end
`endif
```

**结果：0 条 SPI_APB 消息**。CPU 确实在写 SPI 寄存器（boot code 执行了 spi_setup_cmd_addr 等），但 monitor 没捕获到。

**可能原因**：
- APB monitor 路径 `dut.peripherals_i.s_apb_bus` 可能不是 SPI master 的 APB 接口
- SPI master 可能通过不同的 APB 路径访问
- 或者 CPU 根本没成功写到 SPI 寄存器（AXI2APB bridge 问题）

### 5.4 PC Trace Pipeline Offset

**重要发现**：PC trace 有 1 周期延迟。

```systemverilog
// tb_top.sv TRACE_PC
if (instr_req_o && instr_gnt_i) begin
    cur_pc = pc_if;          // 捕获当前 PC
    @(posedge clk);
    while (!instr_rvalid_i) @(posedge clk);
    $display("PC: %h | Instr: %h", cur_pc, instr_rdata_i);
    //                         ^^^ 这是 NEXT 周期的数据！
end
```

- `cur_pc` 在 grant 时采样，但 `instr_rdata_i` 在 rvalid 时采样（下一周期）
- 显示的 "Instr" 对应的是 `cur_pc + 4` 的指令，不是 `cur_pc` 的
- 这个 offset 不影响功能，仅影响 trace 解读

### 5.5 Boot Code 中的地址偏移

ROM_DBG 揭示了一个关键的地址 offset：

```
ROM_DBG: A=546 | A_Q=545 | Q=mem[545]  → 正确
TRACE_PC: PC=0x8884 → 这应该是 ROM index 545，但显示的 Instr 是 mem[546] 的数据
```

这是因为 boot_code 模块的 `A_Q` 寄存器和 `instr_ram_wrap` 的 `is_boot_q` 都有 1 周期延迟。实际的 ROM 数据流水线：
- Cycle T: core 发送 addr (e.g., 545) → ROM 捕获
- Cycle T+1: ROM 输出 mem[545]，is_boot_q=1 选择 rdata_boot
- TRACE_PC 在 T+1 时显示 PC (已变为 546) + data (mem[545])

这是正常的流水线行为，不是 bug。

---

## 6. 下一步调试方向

### 优先级 1：验证 SPI Master 是否真正驱动了 SPI 总线

SPI_APB monitor 没有捕获任何写操作，说明可能 CPU 的 SPI 寄存器写没到达 SPI master IP。

**方法**：
1. 检查 APB probe 路径是否正确 — `dut.peripherals_i.s_apb_bus` 可能不是 SPI master 的 APB
2. 在 `instr_ram_wrap` 或 `core_region` 的 AXI 接口添加 monitor，确认 CPU 的 store 指令确实被执行
3. 在 SPI master IP 内部信号添加探针：`dut.peripherals_i.apb_spi_master.*`

### 优先级 2：确认 SPI Master IP 寄存器地址映射

boot_code.c 使用：
```c
#define SPI_BASE_ADDR  (SOC_PERIPHERALS_BASE_ADDR + 0x2000)  // = 0x1A102000
```

需要确认 PULPino RTL 中 SPI master APB 从机的基地址确实是 0x1A102000：
- 查看 `rtl/peripherals.sv` 中 SPI master 的地址解码
- 或查看 AXI node 的 slave 地址范围配置

### 优先级 3：简化验证 — 跳过 SPI，直接 backdoor 加载

如果 SPI VIP 响应问题短期内无法解决，可以：
1. 去掉 `SPI_BOOT_EN` define，使用普通的 memory preload 流程
2. 或者在 boot_code 中添加一个简单的 GPIO toggle 作为 "hello world" 验证

---

## 7. 踩过的坑

| 坑 | 问题描述 | 解决方案 |
|----|---------|---------|
| **ROM size 不足** | `rom_size=548` 但 boot code 需要 ~771 words | 改为 1024，重新生成 hex |
| **编译缓存** | 不删 `debug/.b0529a91/` 导致 VCS 用旧 simv | 每次改 RTL/tb 源码后必须 `rm -rf debug/.b0529a91/` |
| **$readmemh packed vs unpacked** | `logic [0:N] [31:0]` 是 packed array，$readmemh 不支持 | 改为 `logic [31:0] mem [0:N]` (unpacked) |
| **PC trace 1-cycle offset** | TRACE_PC 显示的 Instr 实际是下一条指令的数据 | 注意解读时 Instr 对应 PC+4 |
| **ROM_DBG 导致仿真超慢** | 每周期 $display 大量输出 → 47ms sim 仅执行 538 条 trace | 调试完后删除 ROM_DBG，只保留 ROM_INIT |
| **S19 parser 偏移错误** | 原始 parser 用 `line[-6:-4]` 在 Python 3 中因 newlines 出错 | 重写为 byte_count + address_length 解析 |
| **boot_code.hex 不存在** | $readmemh 路径硬编码为 Docker 路径 | hex 文件需同步到 Docker 容器内 |
| **Docker 容器未启动** | `docker exec` 失败 | 先 `docker start 828e83272623` |
| **SPI VIP Flash ID** | 不加载 catalog → READ_ID 返回全零 | 先 load_prop_vals(S25FL512S catalog)，再覆盖 ID |

---

## 8. 成功经验

1. **ROM 调试方法**：在 `$readmemh` 后添加 `$display` 验证关键索引的值，再添加 cycle-level `$display` 追踪每次读操作
2. **编译缓存管理**：VCS build hash 基于编译选项而非源文件，改源码后必须手动清缓存
3. **ROM size 确认方法**：用 `riscv64-linux-gnu-nm -n boot_code.elf` 查看最后的符号地址，计算所需 ROM words
4. **TRACE_PC 调试**：虽然有 1-cycle offset，但仍是追踪 CPU 执行流的有效手段
5. **hex 文件格式**：$readmemh 接受纯 hex（每行一个 32-bit word），不需 @address 前缀

---

## 9. 关键文件清单

| 文件 | 作用 | 当前状态 |
|------|------|---------|
| `tb/boot_code_patched.sv` | 替代 repo 的 boot ROM，用 $readmemh | ✅ 1024 words，debug 已清理 |
| `tb/boot_code.hex` | ROM 内容（从 boot_code.c 编译） | ✅ 1024 行，正确 |
| `tb/s19toboot_py3.py` | S19 → hex/sv 转换 | ✅ rom_size=1024，生成 hex |
| `tb/build_boot_rom.sh` | 交叉编译 boot_code.c | ✅ 可用 |
| `sim/filelist.f` line 214 | 指向 tb/boot_code_patched.sv | ✅ |
| `tb/tb_top.sv` | TRACE_PC + SPI_APB monitor | ✅ 编译通过 |
| `tb/env/soc_env.sv` | SPI VIP Flash 配置 | ✅ catalog + ID override |
| `tests/pulpino_spi_boot_test.sv` | UVM test | ✅ 加载 boot_image.memh |

---

## 10. 运行命令速查

```bash
# 启动容器
docker start 828e83272623

# 同步文件到 Docker
docker cp tb/boot_code_patched.sv 828e83272623:/root/work/dv-flow/pulpino_dv/tb/
docker cp tb/boot_code.hex 828e83272623:/root/work/dv-flow/pulpino_dv/tb/
docker cp tb/s19toboot_py3.py 828e83272623:/root/work/dv-flow/pulpino_dv/tb/

# 重新编译运行（清缓存）
docker exec 828e83272623 bash -c "rm -rf /root/work/dv-flow/pulpino_dv/debug/.b0529a91/"
docker exec 828e83272623 bash -c "cd /root/work/dv-flow/pulpino_dv && python3 sim/run_case.py tc_spi_boot --tag spi"

# 查看结果
docker exec 828e83272623 cat /root/work/dv-flow/pulpino_dv/debug/results.log
docker exec 828e83272623 bash -c "grep -E 'TRACE_PC|SPI_APB|BOOT|PASS|FAIL' /root/work/dv-flow/pulpino_dv/debug/tc_spi_boot/simv.log | tail -30"

# 检查 ROM 内容
docker exec 828e83272623 bash -c "awk 'NR>=546 && NR<=548' /root/work/dv-flow/pulpino_dv/tb/boot_code.hex"

# 重新生成 hex 文件
docker exec 828e83272623 bash -c "cd /root/work/dv-flow/pulpino_dv/tb && python3 s19toboot_py3.py boot_build/boot_code.s19"
```
