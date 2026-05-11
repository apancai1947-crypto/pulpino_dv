# Synopsys SVT SPI/QSPI VIP 通用集成与踩坑避北指南

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
| **Flash 模式 READ_ID 返回全 `0`** | 必须先加载 catalog（见 §7），仅设置 `mode_register_cfg` 字段无效。 |

---

## 7. SPI Flash 模式集成指南（Boot 场景）

当 DUT 的 SPI Master 需要从外部 Flash 读取固件（SPI Boot）时，VIP 必须配置为 **Active Flash Slave** 模式，模拟一个 NOR Flash 芯片（如 Spansion S25FL128S）。

### 7.1 基本配置

```systemverilog
spi_cfg = svt_spi_agent_configuration::type_id::create("spi_cfg");
spi_cfg.is_active     = 1;                          // Active Slave（需要响应 DUT 请求）
spi_cfg.is_master     = 0;                          // Slave 角色
spi_cfg.frame_format  = svt_spi_types::SPI_FLASH;   // Flash 协议模式（非 SPI_STD）
spi_cfg.enable_mem_core = 1;                         // 启用内部 Flash 存储模型
spi_cfg.spi_mem_cfg = new("spi_mem_cfg");            // 必须手动创建 mem_cfg 对象
```

**注意**：`SPI_FLASH` 模式与 `SPI_STD` 模式完全不同。Flash 模式下 VIP 会解析 Flash 命令（READ_ID、READ、WRITE、ERASE 等），而 STD 模式只做原始 SPI 数据传输。

### 7.2 Flash ID 配置（关键踩坑）

#### 问题现象

直接设置 `mode_register_cfg` 的 4 个 ID 字段，VIP 仍然返回全零：

```systemverilog
// ❌ 这样写不生效！
spi_cfg.spi_mem_cfg.mode_register_cfg.manufacturer_id = 8'h01;
spi_cfg.spi_mem_cfg.mode_register_cfg.device_id_memory_type = 8'h02;
// ... 仿真中 READ_ID 仍然返回 0x00000000
```

#### 根因

VIP 的 `mem_core`（加密 IP）内部的 Flash 命令解码器和 ID 响应逻辑需要通过 **catalog 系统** 初始化。仅设置 `mode_register_cfg` 字段不够——catalog 加载过程会初始化大量内部状态（命令映射表、时序模型、SFDP 数据等），这些是 mem_core 正确工作的前提。

#### 正确做法：先加载 catalog，再覆盖 ID

```systemverilog
spi_cfg.spi_mem_cfg = new("spi_mem_cfg");

// 第 1 步：加载 catalog（建立 Flash 内部模型）
begin
    string dw_home = $getenv("DESIGNWARE_HOME");
    if (dw_home.len() == 0) dw_home = "/opt/sv_pkgs/designware_home";
    spi_cfg.spi_mem_cfg.load_prop_vals(
        {dw_home, "/vip/svt/spi_svt/latest/catalog/spi/nor/Spansion/S25FL512S_HPLC.cfg"}
    );
end

// 第 2 步：覆盖 ID 字段为目标芯片的值
spi_cfg.spi_mem_cfg.mode_register_cfg.manufacturer_id        = 8'h01;  // Spansion
spi_cfg.spi_mem_cfg.mode_register_cfg.device_id_memory_type  = 8'h02;  // SPI NOR
spi_cfg.spi_mem_cfg.mode_register_cfg.device_id_memory_capacity = 8'h19;  // 256Mb
spi_cfg.spi_mem_cfg.mode_register_cfg.device_id              = 8'h4D;  // Extended ID
```

**关键经验**：VIP catalog 中 **没有** S25FL128S 条目（只有 S25FL512S 变体）。必须用 S25FL512S catalog 作为基础，再覆盖 ID 字段。

#### READ_ID 响应字节顺序

当 DUT 发送 `0x9F`（READ_ID）命令时，VIP 按以下顺序返回 4 字节：

| 响应字节 | 来源字段 | S25FL128S 值 |
| :--- | :--- | :--- |
| Byte 0 | `manufacturer_id` | `0x01` |
| Byte 1 | `device_id_memory_type` | `0x02` |
| Byte 2 | `device_id_memory_capacity` | `0x19` |
| Byte 3 | `device_id` | `0x4D` |

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

**可用的 Spansion catalog**（仅 S25FL512S 变体）：
- `S25FL512S_HPLC.cfg` — 512Mb, 3V, 133MHz（推荐）
- `S25FL512S_EHPLC.cfg` — 增强型
- 其他 DDR/VIO 变体

### 7.4 Boot 测试的完整 Agent 配置

```systemverilog
`ifdef SPI_BOOT_EN
    spi_cfg.is_active     = 1;
    spi_cfg.frame_format  = svt_spi_types::SPI_FLASH;
    spi_cfg.enable_mem_core = 1;
    spi_cfg.spi_mem_cfg = new("spi_mem_cfg");

    // 加载 Spansion catalog
    begin
        string dw_home = $getenv("DESIGNWARE_HOME");
        if (dw_home.len() == 0) dw_home = "/opt/sv_pkgs/designware_home";
        spi_cfg.spi_mem_cfg.load_prop_vals(
            {dw_home, "/vip/svt/spi_svt/latest/catalog/spi/nor/Spansion/S25FL512S_HPLC.cfg"}
        );
    end

    // 覆盖 Flash ID 为 S25FL128S
    spi_cfg.spi_mem_cfg.mode_register_cfg.manufacturer_id        = 8'h01;
    spi_cfg.spi_mem_cfg.mode_register_cfg.device_id_memory_type  = 8'h02;
    spi_cfg.spi_mem_cfg.mode_register_cfg.device_id_memory_capacity = 8'h19;
    spi_cfg.spi_mem_cfg.mode_register_cfg.device_id              = 8'h4D;
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
