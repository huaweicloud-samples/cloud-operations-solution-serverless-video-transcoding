# serverless-saas-layers — 基于华为云的多租户 SaaS 应用架构
> 多租户 SaaS 应用，包含共享服务层、租户感知分区、
> 集中式日志/指标 -- 全部运行在华为云无服务器基础设施上。
![Status](https://img.shields.io/badge/status-active-brightgreen)
![Platform](https://img.shields.io/badge/platform-Huawei%20Cloud-blue)
![IaC](https://img.shields.io/badge/IaC-Terraform-orange)
![Runtime](https://img.shields.io/badge/runtime-FunctionGraph-purple)
![License](https://img.shields.io/badge/License-MIT-lightgrey)
---

## 目录
- [1. 简介](#1-简介)
- [2. 架构说明](#2-架构说明)
- [3. 架构图](#3-架构图)
- [4. 方案亮点](#4-方案亮点)
- [5. 涉及云服务](#5-涉及云服务)
- [6. 前置条件](#6-前置条件)
- [7. 快速开始](#7-快速开始)
- [8. 分步部署](#8-分步部署)
- [9. 使用方法](#9-使用方法)
- [10. 清理资源](#10-清理资源)
- [11. 详细说明](#11-详细说明)
- [12. 依赖](#12-依赖)
- [13. FAQ](#13-faq)
- [14. 贡献指南](#14-贡献指南)
- [15. 许可证](#15-许可证)
- [16. 联系方式](#16-联系方式)

## 1. 简介

本项目演示了一个基于华为云无服务器基础设施构建的**多租户 SaaS
应用**。它展示了如何：
- 构建**共享服务层**（日志、指标、令牌管理、分区管理），
  打包到每个函数中
- 使用 MongoDB 集合实现**租户感知数据分区**（Pool 模式 vs Silo 模式）
- 通过 OBS 对象存储提供**集中式日志和指标**收集
- 通过 APIG（API 网关）暴露 **RESTful CRUD API**，
  后端为 FunctionGraph 函数
- 通过 DLI（数据湖探索）SQL 查询实现对日志/指标的**数据分析**
应用管理两类资源：**Product**（Pool 模式）和 **Order**（Silo 模式），
各有完整的 CRUD 操作。
---

## 2. 架构说明

```
                    +-------------------+
                    |   Python 客户端   |
                    |   (模拟器)        |
                    +--------+----------+
                             |
                    JWT Bearer Token
                             |
                    +--------v----------+
                    |   APIG 实例       |
                    |   (API 网关)      |
                    +--------+----------+
                             |
              +--------------+--------------+
              |              |              |
     /product/{id}   /order/{id}    (6 个端点)
              |              |              |
     +--------v---+  +-------v----+  +-----v-----+
     | Function-  |  | Function-  |  | Function- |
     | Graph x3   |  | Graph x3   |  |  (共享    |
     | (Product)  |  | (Order)    |  |   层)     |
     +----+-------+  +-----+------+  +-----------+
          |                |
          |    +-----------+-----------+
          |    |                       |
     +----v----v---+          +-------v--------+
     |  DDS MongoDB|          |  OBS 桶       |
     |  (副本集)    |         |  (日志/指标)   |
     |  Pool+Silo  |          +----------------+
     |  集合       |
     +-------+------+
             |
     +-------v--------+
     |  DLI 队列 +    |
     |  数据库 +      |
     |  表 (SQL       |
     |  查询 OBS)     |
     +----------------+
```
**数据流：**
1. 客户端携带 JWT 令牌发送 HTTP 请求到 APIG
2. APIG 路由到对应的 FunctionGraph 函数
3. 函数通过 token-manager 从 JWT 中提取租户 ID
4. partition-manager 确定目标 MongoDB 集合（Pool 或 Silo）
5. DAL 层在 DDS MongoDB 上执行 CRUD 操作
6. log-manager 将结构化日志写入 OBS
7. metrics-manager 将性能指标写入 OBS
8. DLI 查询 OBS 数据进行分析
---

## 3. 架构图

（架构图见 `docs/architecture.md`）

## 4. 方案亮点

- **JWT 租户上下文**：每个请求携带 JWT 令牌，包含 `tenantId` 声明，
  服务端使用共享签名密钥验证
- **Pool 分区**：所有租户共享一个集合（如 `products_pooled`），
  通过 `tenantId` 字段过滤
- **Silo 分区**：每个租户拥有独立集合（如 `orders_silo_tenant1`）
- **共享层代码**：5 个工具模块（token、log、metrics、partition、
  helper）打包到每个函数的 `lib/` 目录
- **集中式可观测性**：所有日志和指标以 JSON 对象写入 OBS，
  可通过 DLI SQL 查询
- **无服务器**：无需管理服务器；自动缩容到零；按量付费
---

## 5. 涉及云服务

本实践涉及 OBS、CCE、DLI、DWS、DDS、APIG、FunctionGraph、SMN 等华为云服务；具体清单以 `infra/` 中 Terraform 资源为准。

## 6. 前置条件

- **Terraform** >= 1.3 已安装
- **华为云账号**，具备 AK/SK 凭证
- **Node.js** >= 14 和 **npm**（用于构建函数包）
- **Python** >= 3.8 和 `pip`（用于客户端模拟器）
- **zip** 命令行工具
- 环境变量：
  ```bash
  export HW_ACCESS_KEY="your-access-key"
  export HW_SECRET_KEY="your-secret-key"
  export HW_SECURITY_TOKEN="your-token"  # 如果使用临时凭证
  ```
---

## 7. 快速开始

```bash
# 1. 构建函数包
cd src/
bash build.sh
# 2. 部署基础设施
cd ../infra/
terraform init
terraform plan
terraform apply   # 审查并确认
# 3. 获取 APIG 端点
terraform output apig_base_url
# 4. 运行客户端模拟器
cd ../src/client/
pip install -r requirements.txt
python product-simulator.py "https://<apig-url>/<group>/product" 10 50
python order-simulator.py "https://<apig-url>/<group>/order" 10 50
# 5. 完成后清理
cd ../../infra/
terraform destroy
```
---

## 8. 分步部署

`infra/` 中的 Terraform 代码创建以下资源：
| 资源                      | 数量   | 用途                        |
|---------------------------|--------|-----------------------------|
| VPC + 子网 + 安全组       | 各 1   | DDS + APIG 网络             |
| DDS MongoDB 副本集        | 1      | CRUD 文档数据库             |
| OBS 桶                    | 3      | 日志、指标、函数代码         |
| FunctionGraph 函数        | 6      | Product/Order Get/Put/Delete |
| APIG 实例 + 分组          | 各 1   | API 网关                    |
| APIG API                  | 6      | REST 端点                   |
| APIG 环境 + 发布          | 1 + 6  | 生产部署                    |
| DLI 数据库 + 表           | 1+2    | OBS 数据分析（使用 DLI 内建默认 SQL 队列）|
**部署步骤：**
```bash
cd infra/
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```
部署完成后，使用 `terraform output` 获取 APIG 端点 URL、
DDS 连接串和 OBS 桶名称。
---

### 9. 函数代码部署

函数代码作为 Terraform apply 的一部分自动部署：
1. `build.sh` 将每个函数（处理器 + DAL + 层代码 + node_modules）
   打包为 zip 文件，存放在 `src/dist/`
2. Terraform 将 zip 上传到 OBS 代码桶
3. FunctionGraph 函数创建时引用 OBS zip 包
代码修改后重新构建：
```bash
cd src/
bash build.sh
cd ../infra/
terraform apply   # 重新上传变更的 zip 并更新函数
```
---

### 10. 客户端模拟器

Python 客户端模拟器向 API 发送随机 CRUD 请求：
```bash
cd src/client/
pip install -r requirements.txt
# Product 模拟器: <url> <种子数量> <总调用次数>
python product-simulator.py "https://<apig-url>/<group>/product" 10 50
# Order 模拟器: <url> <种子数量> <总调用次数>
python order-simulator.py "https://<apig-url>/<group>/order" 10 50
```
每个请求包含随机生成的 JWT 令牌，使用三个租户 ID 之一
（`tenant1`、`tenant2`、`tenant3`），演示多租户数据隔离。
---

## 9. 使用方法

部署后，按以下步骤验证系统：
1. **检查 Terraform 输出：**
   ```bash
   terraform output
   ```
2. **测试 API 端点：**
   ```bash
   # 获取 product（需要已有数据）
   curl -H "Authorization: Bearer <jwt>" \
        https://<apig-url>/<group>/product/0
   # 创建/更新 product
   curl -X PUT -H "Content-Type: application/json" \
        -H "Authorization: Bearer <jwt>" \
        -d '{"Description":"test","SKU":123,"ProductPrice":100}' \
        https://<apig-url>/<group>/product/0
   ```
3. **运行客户端模拟器**（见第 10 节）
4. **验证 DDS 数据：**
   - 通过 mongo shell 连接 DDS MongoDB
   - 检查 `saas.products_pooled` 和 `saas.orders_silo_*` 集合
5. **验证 OBS 日志/指标：**
   - 在 OBS 控制台检查日志桶和指标桶中的对象
6. **验证 DLI 查询：**
   - 在 DLI 控制台对 `application_logs` 和 `application_metrics`
     表执行 SQL 查询
---

## 10. 清理资源

```bash
cd infra/
terraform destroy
```
这将删除所有创建的资源：DDS 实例、OBS 桶、FunctionGraph 函数、
APIG 实例、VPC 和安全组。OBS 桶在删除前必须清空
（如果桶为空，Terraform 会自动处理）。
---

## 11. 详细说明

```
serverless-saas-layers/
|-- infra/                       # Terraform IaC
|   |-- versions.tf              # Provider 版本
|   |-- variables.tf             # 输入变量
|   |-- main.tf                  # 所有基础设施资源
|   `-- outputs.tf               # 输出值
|-- src/                         # 应用源代码
|   |-- layers/                  # 共享服务层模块
|   |   |-- helper.js            # OBS 上传 + MongoDB 连接
|   |   |-- token-manager.js     # JWT 租户 ID 提取
|   |   |-- log-manager.js       # 结构化日志写入 OBS
|   |   |-- metrics-manager.js   # 性能指标写入 OBS
|   |   |-- partition-manager.js # Pool/Silo 分区逻辑
|   |   `-- package.json         # 层依赖
|   |-- product-manager/         # Product CRUD 处理器
|   |   |-- product-manager.js   # APIG 事件处理
|   |   |-- product-manager-dal.js  # 数据访问层
|   |   `-- package.json
|   |-- order-manager/           # Order CRUD 处理器
|   |   |-- order-manager.js     # APIG 事件处理
|   |   |-- order-manager-dal.js # 数据访问层
|   |   `-- package.json
|   |-- client/                  # Python 客户端模拟器
|   |   |-- utils.py             # JWT 令牌生成
|   |   |-- product-simulator.py # Product CRUD 模拟器
|   |   |-- order-simulator.py   # Order CRUD 模拟器
|   |   `-- requirements.txt
|   `-- build.sh                 # 函数打包脚本
|-- docs/                        # 文档
|   |-- architecture.md          # 架构详情
|   `-- deployment-guide.md      # 分步部署指南
|-- README.md                    # 中文版（本文件）
`-- README.en.md                 # 英文版
```
---

### 11. 多租户分区

partition-manager 实现两种分区策略：
**Pool 模式**（用于 Product）：
- 所有租户共享一个集合：`products_pooled`
- 每个文档包含 `tenantId` 字段
- 查询时通过 `tenantId` 过滤隔离租户数据
**Silo 模式**（用于 Order）：
- 每个租户拥有独立集合：`orders_silo_<tenantId>`
- 文档中无需 `tenantId` 字段（集合名提供隔离）
- 更强的数据隔离，代价是更多集合
分区映射定义在 `partition-manager.js` 中：
```javascript
const partitionMap = new Map([
    ['ProductManager', { model: 'Pool', ... }],
    ['OrderManager',   { model: 'Silo', ... }],
]);
```
---

### 12. 日志与指标

**日志**（`log-manager.js`）：
- 每条日志是一个 JSON 对象，写入 OBS 日志桶
- 键格式：`<eventSource>/<timestamp>`（如 `ProductManager/1234567890`）
- 字段：`tenantId`、`message`、`timestamp`、`productId`/`orderId`
**指标**（`metrics-manager.js`）：
- 每条指标是一个 JSON 对象，写入 OBS 指标桶
- 键格式：`<eventSource>/<unix_timestamp>`
- 字段：`source`、`type`、`action`、`duration`、`timestamp`、`tenantId`
- duration 以毫秒为单位
---

## 12. 依赖

- Terraform >= 1.5 + huaweicloud Provider
- 部署所需运行时依赖见 `docs/deployment-guide.md`

## 13. FAQ

| 问题               | 原因                  | 解决方案                              |
|--------------------|-----------------------|---------------------------------------|
| 函数超时           | DDS 连接慢            | 增大 `function_timeout` 变量          |
| APIG 404           | API 未发布            | 检查 `terraform apply` 是否成功完成   |
| DDS 连接被拒绝     | 安全组阻止 8635 端口  | 确认 SG 规则允许子网 CIDR             |
| OBS 上传失败       | 函数委托缺失          | 检查 IAM 委托 `fgs_obs_access` 是否存在 |
| DLI 查询返回空     | OBS 中暂无数据        | 先运行客户端模拟器生成日志            |
| build.sh 失败      | 缺少 npm 或 zip       | 安装 Node.js 和 zip 工具              |
---

## 14. 贡献指南

欢迎提交 Issue 与 Pull Request 改进本实践；提交前请先运行 `terraform fmt -check` 与文档自检。

## 15. 许可证

MIT 许可证。详见 [LICENSE](LICENSE)。
---

## 16. 联系方式

| **创建者** | `Shangdongd` |
| **维护者** | `Shangdongd` |

**Shangdongd** - 项目维护者

