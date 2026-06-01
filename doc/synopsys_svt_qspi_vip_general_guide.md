# Synopsys SVT SPI/QSPI VIP 通用集成与踩坑避坑指南

## 1. 简介
Synopsys SVT (SystemVerilog Testbench) SPI VIP 是一款功能强大的验证组件，支持标准 SPI、Dual SPI、Quad SPI (QSPI) 以及各种 Flash 协议。
本文档总结了在 PULPino 等自定义 SoC 验证环境中集成 SPI VIP 时的**通用路径**和**深度踩坑经验**，适用于任何基于 UVM 的验证环境。

---

## 2. 预集成准备与宏配置

### 2.1 编译宏配置 (`vlog_opt`)
在编译脚本中，必须通过宏定义控制 VIP 的硬件特性及内部数据结构上限：
- `SVT_SPI_IO_WIDTH`：定义物理数据线数量（1=STD, 2=Dual, 4=QSPI）。
- `SVT_SPI_MAX_NUM_SLAVES`：定义支持的最大 Slave 数量。
- **`SVT_SPI_DATA_WIDTH`**：定义事务级 `data[]` 数组的位宽。**注意：配置类中的 `data_frame_width` 绝对不能超过此宏的值！**（例如若设为 40，宏也必须 >= 40）。

```bash
# 示例：VCS 编译选项
+define+SVT_SPI_IO_WIDTH=4 \
+define+SVT_SPI_DATA_WIDTH=32
```

---

## 3. VIP 相关查询的正确流程（SOP）

Synopsys VIP 的 `.svp` 源码经过加密，无法直接通过源码或 `grep` 查询属性。遇到找不到属性或配置不生效时，**请严格遵循以下 SOP**：

1. **【首选】查 Docker 内 HTML 文档（最权威）：**
   路径：`/usr/Synopsys/vip_2018_09/vip/svt/spi_svt/latest/doc/spi_svt_uvm_class_reference/html/`
   核心入口：`index.html`。关键文件：
   - `class_svt_spi_agent_configuration.html` — Agent 专属属性
   - `class_svt_spi_configuration.html` — **父类！绝大多数关键属性都在这里**
   - `class_svt_spi_transaction.html` — 事务字段（如 `data`, `transfer_mode`）
   
   *提示：若在终端无法查看，可通过 Python 脚本提取文本：*
   ```python
   # 在 Docker 内执行
   import re
   DOC = '/usr/Synopsys/vip_2018_09/vip/svt/spi_svt/latest/doc/spi_svt_uvm_class_reference/html/'
   with open(DOC + 'class_svt_spi_configuration.html', encoding='latin-1') as f:
       text = re.sub(r'<[^>]+>', ' ', f.read())
       # 进一步处理即可看到完整 public attributes
   ```

2. **查 `.svi` 文件**：`sverilog/include/` 下的 `.svi` 文件是明文，包含接口端口和枚举宏定义。

3. **利用编译报错反查**：直接把猜测的属性写进代码并编译，VCS `compile.log` 中的 `Error-[MFNF]` 会准确告诉你该类下是否存在此属性。

---

## 4. UVM 环境配置避坑指南 (`soc_env.sv`)

### 4.1 类继承关系与属性误区
很多你以为应该有的配置，其实在父类，或者名字不一样：
- **错误**：`item_operation_mode` -> **正确**：`operation_mode`
- **错误**：`data_width` -> **正确**：`data_frame_width`
- **注意**：`is_master` 等属性在基类 `svt_spi_configuration`，Agent 会继承。

### 4.2 Standard SPI 的关键配置
如果要用 VIP 监控标准 SPI 协议（而非默认的 Flash 协议），**必须集齐以下配置**，缺一不可：

```systemverilog
spi_cfg = svt_spi_agent_configuration::type_id::create("spi_cfg");

// 1. 角色配置
spi_cfg.is_active = 0; // 0=Passive Monitor (只听不说), 1=Active
spi_cfg.is_master = 0; // 0=Slave 角色 (监控 Master 发出的数据), 1=Master 角色

// 2. 协议与模式
spi_cfg.frame_format   = svt_spi_types::SPI_STD;    // 必须显式指定！否则可能被当作 Flash 解析
spi_cfg.operation_mode = svt_spi_types::SPI_MODE_0; // CPOL=0, CPHA=0

// 3. 数据帧宽 (极其容易踩坑)
spi_cfg.enable_configurable_data_frame_width = 1; // 必须设为1！否则下面那行配置无效！
spi_cfg.data_frame_width = 32;                    // 设置实际的帧长

// 4. 字节序 (决定解析结果)
// VIP 默认按 LSB-first 将线上的 bit 填入 data[0]。
// 如果你的 RTL 是 MSB-first，必须设置为 BIG_ENDIAN，否则读出的数据会高低位倒序！
spi_cfg.bit_endianness = svt_spi_types::BIG_ENDIAN;

// 5. 关闭 Flash 特有检查
spi_cfg.enable_txrx_chk = 0;
```

---

## 5. 数据流监控与自我比对

### 5.1 Passive Slave 的数据获取路径
当 VIP 被配置为 **Passive Slave**（监控 Master 时），它的内部监视器（`txrx_mon`）对方向的定义如下：
- **RX 方向 (`rx_xact_observed_port`)**：对应从 **MOSI** 线上采样到的数据（Master 发给 Slave 的真实有效负载）。
- **TX 方向 (`tx_xact_observed_port`)**：对应从 **MISO** 线上采样到的数据（Slave 返回给 Master 的数据，如果没有驱动则全 0）。

**避坑**：在 UVM Scoreboard 中，如果你想比对 Master 发出的命令或数据，**必须监听 RX 端口**。如果监听 `item_observed_port`（混合端口），有极高概率抓到无用的 TX(MISO) 侧空数据。

### 5.2 提取数据的实现代码
```systemverilog
svt_spi_transaction vip_tr;
// 确保只拿 rx_vip_fifo 里的事务
rx_vip_fifo.get(vip_item);
$cast(vip_tr, vip_item);

if (vip_tr.data.size() > 0) begin
    // 获取第一个 word 的数据（受 SVT_SPI_DATA_WIDTH 宏影响）
    logic [31:0] vip_data = vip_tr.data[0]; 
    
    // 如果配置了正确的 BIG_ENDIAN，vip_data 就可以直接跟预期值比对
    if (vip_data == expected_data) begin
        `uvm_info("CHECK", "Data matched!", UVM_LOW)
    end
end
```

---

## 6. 常见错误速查

| 现象 / 报错 | 可能原因 & 解决办法 |
| :--- | :--- |
| **`Error-[MFNF] Member not found`** | 属性名写错。使用 SOP 1 查阅 HTML 文档确认正确属性名。 |
| **VIP 报告 `Read Mode` 且 `DFS=0`** | 1. 它是 Flash 模式，遇到了不认识的 CMD。<br>2. 忘记设置 `frame_format = SPI_STD`。<br>3. `is_master` 配置和物理连线角色相反。 |
| **设置了 `data_frame_width` 但不生效** | 漏了配置 `enable_configurable_data_frame_width = 1`。 |
| **数据位宽报错 `must be less than or equal to Macro`** | 编译时的 `+define+SVT_SPI_DATA_WIDTH` 过小，调大宏定义。 |
| **收到的数据值按位完全翻转** (`0x00000001` 变 `0x80000000`) | 字节序问题。在 config 中添加 `spi_cfg.bit_endianness = svt_spi_types::BIG_ENDIAN`。 |
| **Scoreboard / FIFO 收到全 `0` 数据** | 监听了错误的端口。Slave 角色应只听 `rx_xact_observed_port` (MOSI)。 |
| **Flash 模式 READ_ID 返回全 `0` 或不是预期值** | 必须先加载 catalog（见 §7），再按具体 vendor 覆盖 ID。Spansion 常见模型需要改 `id_cfi[0:3]`，Macronix 常见模型走 `manufacturer_id/device_id*` 字段。 |

---

## 7. SPI Flash 模式集成指南（Boot 场景）

当 DUT 的 SPI Master 需要从外部 Flash 读取固件（SPI Boot）时，VIP 必须配置为 **Active Flash Slave** 模式，模拟一个 NOR Flash 芯片。PULPino boot ROM 的 ID 判断偏 Spansion 系列，但 SVT catalog 中不一定有完全同型号的 part，通常需要用相近 catalog 加 ID 覆盖。

### 7.1 基本配置

```systemverilog
spi_cfg = svt_spi_agent_configuration::type_id::create("spi_cfg");
spi_cfg.is_active     = 1;                          // Active Slave（需要响应 DUT 请求）
spi_cfg.is_master     = 0;                          // Slave 角色
spi_cfg.frame_format  = svt_spi_types::SPI_FLASH;   // Flash 协议模式（非 SPI_STD）
spi_cfg.enable_mem_core = 1;                         // 启用内部 Flash 存储模型
spi_cfg.spi_mem_cfg = svt_spi_mem_configuration::type_id::create("spi_mem_cfg");
```

**注意**：`SPI_FLASH` 模式与 `SPI_STD` 模式完全不同。Flash 模式下 VIP 会解析 Flash 命令（READ_ID、READ、WRITE、ERASE 等），而 STD 模式只做原始 SPI 数据传输。

### 7.2 Flash ID 配置（关键踩坑）

#### 问题现象

只设置 `mode_register_cfg` 的 4 个 JEDEC ID 字段，某些 catalog 下 VIP 仍然返回全零或旧 ID：

```systemverilog
// 对 Spansion S25FL512S_* 这类 catalog，单独这样写可能不影响 pin-level READ_ID：
spi_cfg.spi_mem_cfg.mode_register_cfg.manufacturer_id = 8'h01;
spi_cfg.spi_mem_cfg.mode_register_cfg.device_id_memory_type = 8'h02;
// ... 仿真中 READ_ID 仍可能不是 0x0102194d
```

#### 根因

VIP 的 `mem_core`（加密 IP）内部的 Flash 命令解码器和 ID 响应逻辑需要通过 **catalog 系统** 初始化。catalog 加载过程会初始化大量内部状态（命令映射表、时序模型、CFI/SFDP 数据等），这些是 mem_core 正确工作的前提。不同 vendor catalog 的 `READ_ID (0x9F)` 来源字段不完全一致：Spansion S25FL512S 系列实测更依赖 `id_cfi[0:3]`，Macronix MX25L 系列实测走 JEDEC ID fields。

#### 正确做法：先加载 catalog，再覆盖 ID

```systemverilog
spi_cfg.spi_mem_cfg = svt_spi_mem_configuration::type_id::create("spi_mem_cfg");

// 第 1 步：加载 catalog（建立 Flash 内部模型）
begin
    string dw_home = $getenv("DESIGNWARE_HOME");
    if (dw_home.len() == 0) dw_home = "/opt/sv_pkgs/designware_home";
    spi_cfg.spi_mem_cfg.load_prop_vals(
        {dw_home, "/vip/svt/spi_svt/latest/catalog/spi/nor/Spansion/S25FL512S_EHPLC.cfg"}
    );
end

// 第 2 步：覆盖 ID 字段为 boot ROM 期望的值
spi_cfg.spi_mem_cfg.mode_register_cfg.manufacturer_id        = 8'h01;  // Spansion
spi_cfg.spi_mem_cfg.mode_register_cfg.device_id_memory_type  = 8'h02;  // SPI NOR
spi_cfg.spi_mem_cfg.mode_register_cfg.device_id_memory_capacity = 8'h19;  // 256Mb
spi_cfg.spi_mem_cfg.mode_register_cfg.device_id              = 8'h4D;  // Extended ID

// Spansion S25FL512S_* catalog 的 pin-level READ_ID 实测来自 id_cfi[0:3]
spi_cfg.spi_mem_cfg.mode_register_cfg.id_cfi[0] = 8'h01;
spi_cfg.spi_mem_cfg.mode_register_cfg.id_cfi[1] = 8'h02;
spi_cfg.spi_mem_cfg.mode_register_cfg.id_cfi[2] = 8'h19;
spi_cfg.spi_mem_cfg.mode_register_cfg.id_cfi[3] = 8'h4D;
```

**关键经验**：VIP catalog 中 **没有** S25FL128S 条目（只有 S25FL512S 变体）。可以用 S25FL512S catalog 作为基础，再覆盖 boot ROM 需要的 ID。注意这只解决 `READ_ID` 阶段，不代表该 catalog 一定支持 boot ROM 后续发送的 `0x71`/QPI 配置命令。

#### READ_ID 响应字节顺序

当 DUT 发送 `0x9F`（READ_ID）命令时，VIP 按以下顺序返回 4 字节：

| 响应字节 | 来源字段 | S25FL128S 值 |
| :--- | :--- | :--- |
| Byte 0 | `manufacturer_id` 或 `id_cfi[0]` | `0x01` |
| Byte 1 | `device_id_memory_type` 或 `id_cfi[1]` | `0x02` |
| Byte 2 | `device_id_memory_capacity` 或 `id_cfi[2]` | `0x19` |
| Byte 3 | `device_id` 或 `id_cfi[3]` | `0x4D` |

组合后 DUT 收到的 32-bit 值为 `0x0102194D`。

### 7.3 Catalog 文件结构

Catalog `.cfg` 文件位于 `$DESIGNWARE_HOME/vip/svt/spi_svt/latest/catalog/spi/nor/<Vendor>/`。

关键字段使用 `@mode_register_cfg` 后缀表示属于 `mode_register_cfg` 子对象：

```ini
catalog_part_number=S25FL512S_HPLC
catalog_device_family=S25FL
catalog_vendor=SPANSION
catalog_class=SPI_FLASH
manufacturer_id@mode_register_cfg=01
device_id@mode_register_cfg=19
# id_cfi 数组也包含 ID 信息（CFI/SFDP 空间）
id_cfi[0]@mode_register_cfg=01
id_cfi[1]@mode_register_cfg=02
id_cfi[2]@mode_register_cfg=20
```

**常用的 Spansion catalog**（仅 S25FL512S 变体）：
- `S25FL512S_EHPLC.cfg` — 增强型，当前 PULPino SPI boot debug 默认使用
- `S25FL512S_HPLC.cfg` — 512Mb, 3V, 133MHz
- 其他 DDR/VIO 变体

### 7.4 Boot 测试的完整 Agent 配置

```systemverilog
`ifdef SPI_BOOT_EN
    spi_cfg.is_active     = 1;
    spi_cfg.frame_format  = svt_spi_types::SPI_FLASH;
    spi_cfg.enable_mem_core = 1;
    spi_cfg.spi_mem_cfg = svt_spi_mem_configuration::type_id::create("spi_mem_cfg");

    // 加载 Spansion catalog
    begin
        string dw_home = $getenv("DESIGNWARE_HOME");
        if (dw_home.len() == 0) dw_home = "/opt/sv_pkgs/designware_home";
        spi_cfg.spi_mem_cfg.load_prop_vals(
            {dw_home, "/vip/svt/spi_svt/latest/catalog/spi/nor/Spansion/S25FL512S_EHPLC.cfg"}
        );
    end

    // 覆盖 Flash ID 为 boot ROM 期望值
    spi_cfg.spi_mem_cfg.mode_register_cfg.manufacturer_id        = 8'h01;
    spi_cfg.spi_mem_cfg.mode_register_cfg.device_id_memory_type  = 8'h02;
    spi_cfg.spi_mem_cfg.mode_register_cfg.device_id_memory_capacity = 8'h19;
    spi_cfg.spi_mem_cfg.mode_register_cfg.device_id              = 8'h4D;
    spi_cfg.spi_mem_cfg.mode_register_cfg.id_cfi[0] = 8'h01;
    spi_cfg.spi_mem_cfg.mode_register_cfg.id_cfi[1] = 8'h02;
    spi_cfg.spi_mem_cfg.mode_register_cfg.id_cfi[2] = 8'h19;
    spi_cfg.spi_mem_cfg.mode_register_cfg.id_cfi[3] = 8'h4D;
`endif
```

### 7.5 Flash 数据预加载

Boot 测试需要将固件镜像预加载到 VIP 的 Flash 存储中：

```systemverilog
// 在 UVM test 的 run_phase 中
if (env.spi_master_agent != null && env.spi_master_agent.mem_sequencer != null) begin
    void'(env.spi_master_agent.mem_sequencer.backdoor.load("fw/boot_image.memh", 0));
end
```

`boot_image.memh` 由 `c/elf2flash.py` 生成，格式为每行一个十六进制字节（byte-per-line），小端序头部。

---

## 8. PULPino SPI Boot 集成实战经验（2026-05）

本节记录 PULPino SPI Boot + Synopsys SVT SPI Flash VIP 调试中已经验证有效的做法。它们比“能编译”更重要，因为很多 SPI Flash VIP 问题不是 UVM 配置错误，而是 pin mapping、catalog 初始化顺序、Flash ID 来源字段和 boot ROM 命令序列之间不匹配。

### 8.1 Flash 模式下不要把 MOSI/MISO 简单接到 `mosi/miso`

SVT SPI VIP 在 Flash 模式下有自己的 IO 约定：

- `dq0` 是标准 SPI Flash 的 SI/MOSI。
- `dq1` 是标准 SPI Flash 的 SO/MISO。
- Quad TX 阶段 master 在 `dq0-dq3` 上驱动。
- Quad RX 阶段 flash 在 `dq0-dq3` 上驱动。

PULPino SPI master 的接口是分离的 `sdo*` / `sdi*`，所以在 SPI boot / flash 模式下推荐这样接：

```systemverilog
assign spi_master_vif.mosi[0] = 1'bz;
assign spi_master_vif.mosi[1] = 1'bz;
assign spi_master_vif.mosi[2] = 1'bz;
assign spi_master_vif.mosi[3] = 1'bz;

assign spi_master_vif.dq0 =
    (spi_master_mode_o == 2'b00 || spi_master_mode_o == 2'b01) ? spi_master_sdo0_o : 1'bz;
assign spi_master_vif.dq1 =
    (spi_master_mode_o == 2'b01) ? spi_master_sdo1_o : 1'bz;
assign spi_master_vif.dq2 =
    (spi_master_mode_o == 2'b01) ? spi_master_sdo2_o : 1'bz;
assign spi_master_vif.dq3 =
    (spi_master_mode_o == 2'b01) ? spi_master_sdo3_o : 1'bz;

assign spi_master_sdi0_i = (spi_master_mode_o == 2'b00) ? spi_master_vif.dq1 : spi_master_vif.dq0;
assign spi_master_sdi1_i = (spi_master_mode_o == 2'b00) ? 1'b0 : spi_master_vif.dq1;
assign spi_master_sdi2_i = (spi_master_mode_o == 2'b00) ? 1'b0 : spi_master_vif.dq2;
assign spi_master_sdi3_i = (spi_master_mode_o == 2'b00) ? 1'b0 : spi_master_vif.dq3;
```

这一步修正后，`READ_ID (0x9F)` 期间可以在 `dq1/sdi0` 上看到 VIP 返回值。之前 MISO 长期保持 X/Z 的主要原因之一就是 flash IO 约定没有对齐。

### 8.2 catalog load 之后再覆盖 timing 和 ID

`load_prop_vals()` 会初始化 flash model 的 part number、命令表、timing、ID/CFI/SFDP 等内部状态。实测中，如果在 catalog load 之前改 timing 或 ID，后续可能被 catalog 覆盖掉。

推荐顺序：

```systemverilog
spi_cfg.spi_mem_cfg = svt_spi_mem_configuration::type_id::create("spi_mem_cfg");

spi_cfg.spi_mem_cfg.load_prop_vals(flash_cfg_file);

// catalog load 之后再覆盖，避免被 load_prop_vals() 写回默认值
spi_cfg.spi_mem_cfg.timing_cfg.tRPH_ns = 350;
spi_cfg.spi_mem_cfg.timing_cfg.tPU_us  = 0.300;
spi_cfg.spi_mem_cfg.timing_cfg.tVSL_us = 0.300;
```

`tPU_us / tVSL_us` 对 boot bring-up 很敏感。默认 catalog power-up timing 可能很长，DUT 先发 READ_ID 时 VIP 还没准备好，就会看到没有返回或返回异常。调试阶段可以先缩短到亚微秒级，确认协议链路是否打通。

### 8.3 READ_ID 字段来源和 vendor 有关

不要假设所有 catalog 都从同一组字段返回 `0x9F`。

已观察到的差异：

| Vendor/catalog | READ_ID 来源 | 经验 |
| :--- | :--- | :--- |
| Spansion `S25FL512S_*` | `mode_register_cfg.id_cfi[0:3]` | 只改 `manufacturer_id/device_id*` 可能不影响 pin-level READ_ID。 |
| Macronix `MX25L12865E_*` | `manufacturer_id`, `device_id_memory_type`, `device_id_memory_capacity` | `id_cfi[0:3]` 可能保持 0，但 READ_ID 仍由 JEDEC fields 产生。 |

为了让同一套 test 能快速切换 catalog，可同时覆盖两组字段：

```systemverilog
spi_cfg.spi_mem_cfg.mode_register_cfg.manufacturer_id = 8'h01;
spi_cfg.spi_mem_cfg.mode_register_cfg.device_id_memory_type = 8'h02;
spi_cfg.spi_mem_cfg.mode_register_cfg.device_id_memory_capacity = 8'h19;
spi_cfg.spi_mem_cfg.mode_register_cfg.device_id = 8'h4D;

spi_cfg.spi_mem_cfg.mode_register_cfg.id_cfi[0] = 8'h01;
spi_cfg.spi_mem_cfg.mode_register_cfg.id_cfi[1] = 8'h02;
spi_cfg.spi_mem_cfg.mode_register_cfg.id_cfi[2] = 8'h19;
spi_cfg.spi_mem_cfg.mode_register_cfg.id_cfi[3] = 8'h4D;
```

PULPino boot ROM 当前接受：

- manufacturer byte 为 `0x01`
- memory type/capacity 为 `0x0219` 或 `0x2018`

所以验证时不只看 VIP transaction summary，也要看 DUT 采样后的 pin-level word，例如：

```text
SPI_READ_ID_OBS response=0x0102194d
```

### 8.4 用 plusarg 切换 catalog 和仿真停止时间

为了避免每次换 flash model 都重新编译，建议把 catalog 路径做成 runtime plusarg：

```systemverilog
string flash_cfg_file;
if (!$value$plusargs("SPI_FLASH_CFG=%s", flash_cfg_file)) begin
    flash_cfg_file = {dw_home, "/vip/svt/spi_svt/latest/catalog/spi/nor/Spansion/S25FL512S_EHPLC.cfg"};
end
spi_cfg.spi_mem_cfg.load_prop_vals(flash_cfg_file);
```

运行示例：

```bash
python3 run_case.py tc_spi_boot \
  +SPI_FLASH_CFG=/usr/Synopsys/vip_2018_09/vip/svt/spi_svt/O-2018.09/catalog/spi/nor/Macronix/MX25L12865E_VIO_30V.cfg
```

如果只是想拉长/缩短波形，不要通过重新编译改 SV delay。可以在 UVM test 里加 debug-only plusarg：

```systemverilog
int unsigned force_finish_ns;
if ($value$plusargs("SPI_BOOT_FORCE_FINISH_NS=%0d", force_finish_ns) && force_finish_ns != 0) begin
    #(force_finish_ns * 1ns);
end
else begin
    env.stdout_mon.eot_event.wait_trigger();
end
```

注意：`+SPI_BOOT_FORCE_FINISH_NS` 只能用于 dump 波形或 catalog 扫描，不能当作真实 pass。

### 8.5 打开“VIP 收到了什么”的低噪声日志

直接 `tr.sprint()` 很容易把日志打爆。更好的做法是接 VIP monitor 的 analysis port，然后只打印关键字段。

```systemverilog
uvm_tlm_analysis_fifo #(svt_spi_transaction) spi_vip_rx_fifo;
uvm_tlm_analysis_fifo #(svt_spi_transaction) spi_vip_tx_fifo;

env.spi_master_agent.txrx_mon.rx_xact_observed_port.connect(spi_vip_rx_fifo.analysis_export);
env.spi_master_agent.txrx_mon.tx_xact_observed_port.connect(spi_vip_tx_fifo.analysis_export);
```

推荐打印：

```systemverilog
`uvm_info("SPI_VIP_RX", $sformatf(
    "cmd=%s mode=%s addr=0x%0h dfs=%0d data=%s",
    tr.flash_command.name(), tr.flash_protocol_mode.name(),
    tr.address_frame, tr.data_frame_size, spi_data_summary(tr)), UVM_LOW)
```

PULPino boot bring-up 中最有用的观测点：

- `SPI_APB`：boot ROM 是否真的在配置 SPI master。
- `SPI_PIN_EVT`：前几个 SCLK 采样，确认 MOSI 第一字节是不是 `10011111`。
- `SPI_READ_ID_OBS`：DUT 实际收到的 READ_ID word。
- `SPI_VIP_RX/TX`：VIP transaction-level 解析出来的命令。

### 8.6 关闭高频 PC trace，保留定点 SPI trace

SPI boot 仿真里 PC trace 会非常重，尤其在 boot delay loop 中会严重拖慢仿真。建议：

- 默认 build 不加 `+define+TRACE_PC`。
- 如需定位 CPU 卡点，再临时打开。
- 常态保留低噪声 SPI 定点 trace，例如只打印前 32 个 SPI APB write、前 96 个 SCLK sample。

### 8.7 SPI Boot 仿真完美通关破局路线与终极踩坑归档（2026-05）

在 2026-05 的调试中，我们通过对物理层和总线协议的深度重构，**100% 跑通了整个 SPI Boot 加载与引导链路**，在此归档两条极具实战价值的“终极避坑记忆”：

#### 8.7.1 规避 QPI-0x71 / 指令四线传输的物理缺陷 (改用 0x03)
- **踩坑现象**：原本 Boot ROM 会发送 `0x71` 命令去配 Flash 寄存器，而 SVT Flash VIP 因无法识别 `0x71` 而直接抛出 `UVM_FATAL`。即便剔除 `0x71` 依然无法直接使用 `0xEB`（Quad I/O Fast Read）——因为 PULPino 的 SPI 硬件 design 在执行 Quad 事务时，**指令本身也会四线传输**，导致普通 Flash VIP 无法解析指令。
- **通关方法**：在 Boot ROM 中抛弃复杂的 QPI 配置，彻底改用最标准、100% 物理支持的 **`0x03` Standard Read (单线模式)** 来读取 header、instruction 与 data。此举实现了 100% 的 Flash VIP 协议兼容性。

#### 8.7.2 规避大端 vs 小端端序颠倒与地址对齐 Bug (终极要害)
- **要害 1：24-bit 物理地址高位对齐 (addr << 8)**：
  SPI 控制器在发送物理地址时，默认直接取寄存器 `SPI_REG_SPIADR` 的最高 24 位（bits [31:8]）。如果在 C 代码中直接传入 24 位地址 `addr`，移位寄存器发出的地址实际上会被高位截断放大（相当于右移 8 位变 0 导致总线错位）。因此，**所有 24 位 Standard Read 的 `addr` 写入寄存器前，必须做左移 8 位（`addr << 8`）高位对齐处理**。
- **要害 2：数据/指令段透明端序纠正 (spi_read_fifo_swap)**：
  JEDEC 物理总线上先收到的字节被装入了 FIFO 的最高字节，导致 CPU 从 FIFO 读取的 word 数据为**完全颠倒的大端字节序**。
  这会导致：
  1. Header 读出来的 blocks 数量被解析为 `0x01000000`（1677 万个 block），导致无限读取死循环。
  2. 指令 RAM 装载进的机器码（如 `0x00000093` 变成 `0x93000000`）完全错乱，导致 CPU 跳转后瞬间抛出 **`Illegal instruction at PC 0x00000086`**。
  - **通关方法**：在 Boot ROM 中实现带有 `byte_swap` 自动转换的 FIFO 读取函数 **`spi_read_fifo_swap`**。该函数在接收时，自动将 32-bit word 进行字节反转。此举使写入 RAM 的指令对 CPU 完全透明地呈现为正常的小端字节序，CPU 跳转执行后即可正常输出 `Booted Successfully` 并完美通过！
