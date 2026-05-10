# Synopsys VIP安装指南

### 一、前言

VIP（Verification IP）的安装，集成和使用这三个技能，是每一个初级IC验证工程师必须要掌握的，这步路是必经之路。因此本文将分为这三个部分。

在每一个svt_vip’s userguide的前两章，都会讲VIP的安装详细步骤，本文是基于这个详细步骤实操之后，写的一些总结。

### 二、VIP的安装

#### 环境变量设置 $DESIGNWARE_HOME

```bash
export DESIGNWARE_HOME=/vip_designware_home  #设置DESIGNWARE_HOME指向的路径
export PATH=$DESIGNWARE_HOME/bin:$PATH  #将DESIGNWARE_HOME下的bin添加到环境变量PATH中
```

这是第一步，也是最重要的一步。
**注：这里的 `vip_designware_home` 是个例子，用户需根据自己需求指定目录。**

#### 运行 xxx.run 文件

xxx.run 文件是一个可执行的压缩文件，可以从 Synopsys 的官网获取。拿到 xxx.run 文件后，直接在任意位置执行该文件：

```bash
./xxx.run         #执行xxx.run文件
```

#### License 问题如何解决？

在 userguide 中，还会讲解 `LM_LICENSE_FILE` 的设置，如果没有设置，执行 xxx.run 文件将会不成功。

![image](https://i-blog.csdnimg.cn/direct/b040a5f55860487793554598065c3f69.png)

解决方法：License 可以在相关渠道寻找破解方法，拿到 License 生成器后，根据 userguide 里的步骤，在 License 中添加对应的 VIP feature。

---

如果上述问题解决，xxx.run 文件成功执行，将会把 VIP 文件生成到 `$DESIGNWARE_HOME` 指向的目录下，此时会发现目录下有两个文件夹：`bin` 和 `vip`。

![image](https://i-blog.csdnimg.cn/direct/9d6264b84166400dac6e04ecaa5a9a13.png)

进入 `vip/svt` 文件夹，可以看到各种各样的 VIP：

![image](https://i-blog.csdnimg.cn/direct/ab2aac7c9b474df38daa978e3b931bcb.png)

以 UART 为例，进入 `uart_svt` 文件夹，可以看到具体版本（如 T-2022.09）：

![image](https://i-blog.csdnimg.cn/direct/73767920fa8c42b599bff03da61281c2.png)

---

#### dw_vip_setup 工具的使用

进入 `$DESIGNWARE_HOME/bin` 文件夹，最重要的工具是 `dw_vip_setup`。

![image](https://i-blog.csdnimg.cn/direct/67dce15ffdd9484f95d85f9ff2314acf.png)

通过执行 `dw_vip_setup -help` 可以了解工具选项。

##### VIP 库中的 LIBRARIES, MODELS, EXAMPLES

执行命令查看相关信息：
```bash
dw_vip_setup -info home:uart_svt      #打印uart_svt相关的所有信息
```

| 术语 | 定义 | 主要用途 |
| --- | --- | --- |
| **Libraries (库)** | Synopsys VIP 产品的集合或特定协议的所有底层组件。 | 包含基础代码、协议规则检查器、覆盖率模型等。 |
| **Models (模型)** | 代表特定协议接口（如 PCIe、USB 等）的具体实现代码。 | 实例化并连接到 DUT，用于生成事务、监控信号。 |
| **Examples (示例)** | 随 VIP 提供的参考测试平台和用例。 | 帮助用户快速上手，加速验证平台开发。 |

---

##### dw_vip_setup 命令行

###### 添加、移除、更新 Model
```bash
dw_vip_setup -path <design_dir> -add uart_agent_svt -v T-2022.09
dw_vip_setup -path <design_dir> -remove uart_agent_svt -v T-2022.09
dw_vip_setup -path <design_dir> -update uart_agent_svt -v <version>
```

###### 生成 Example
```bash
dw_vip_setup -path <design_dir> -example uart_svt/tb_uart_svt_uvm_basic_sys -v T-2022.09 -doc -svlog
```

---

### 三、VIP 的集成

#### 不可以直接使用 DESIGNWARE_HOME 路径下的文件

因为 VIP 库里的文件组织形式不适用于直接放入 flist。集成时需要将分散在各处的文件聚合。

#### 集成方法——使用 dw_vip_setup 安装 Models

关键是要指定一个 `design_dir`（生成路径）。运行命令后，会在指定目录下生成 `include`、`src` 等文件夹。

#### 使用 dw_vip_setup 添加 Examples

Example 文件夹提供了一个完整的验证平台，运行其中的 case 可以快速理解 VIP 结构。

```bash
# 运行示例
cd <design_dir>/examples/sverilog/uart_svt/tb_uart_svt_uvm_basic_sys
./run_uart_svt_uvm_basic_sys -waves fsdb directed_test vcsvlog
```

---

### 四、在个人验证环境添加 VIP 的 flist

示例 flist：
```text
// macros
+define+SVT_UVM_TECHNOLOGY
+define+UVM_PACKER_MAX_BYTES=8000 
+define+SVT_UART

// include dirs
+incdir+/vip_design_dir/include/verilog
+incdir+/vip_design_dir/include/sverilog

// pkgs 
/vip_design_dir/include/sverilog/svt.uvm.pkg 
/vip_design_dir/include/sverilog/svt_uart.uvm.pkg
```

---

### 五、快速上手 VIP 的方式

1. **阅读文档**：`uvm_user_guide.pdf`（详细使用）、`uvm_getting_started.pdf`（快速集成）。
2. **运行 Example**：实际运行 case 理解 VIP 行为。
3. **查看 Class Reference**：通过网页形式查看类、变量和方法。

### 六、总结

尽管 flist 中添加的是 `design_dir` 中的文件，但最终绝大部分文件仍来源于最根本的 `DESIGNWARE_HOME` 库。`design_dir` 的生成是为了方便用户集成。
