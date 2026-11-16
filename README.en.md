# serverless-saas-layers — Huawei Cloud Practice

## Table of Contents
- Overview
- Architecture
- Highlights
- Cloud Services
- Prerequisites
- Quick Start
- Deployment
- Usage
- Cleanup
- FAQ
- License
- Contact

## 1. Overview

This project demonstrates a **multi-tenant SaaS application** built on
Huawei Cloud serverless infrastructure. It shows how to:
- Build **shared service layers** (logging, metrics, token management,
  partition management) that are bundled with each function
- Implement **tenant-aware data partitioning** (Pool vs Silo models)
  using MongoDB collections
- Provide **centralized logging and metrics** via OBS object storage
- Expose **RESTful CRUD APIs** through APIG (API Gateway) with
  FunctionGraph backends
- Enable **data analytics** on logs/metrics through DLI (Data Lake
  Insight) SQL queries
The application manages two resources: **Products** (pooled model) and
**Orders** (silo model), each with full CRUD operations.
---

## 2. Architecture

> Multi-tenant SaaS application with shared service layers, tenant-aware
> partitioning, and centralized logging/metrics -- running fully on
> Huawei Cloud serverless infrastructure.
![Status](https://img.shields.io/badge/status-active-brightgreen)
![Platform](https://img.shields.io/badge/platform-Huawei%20Cloud-blue)
![IaC](https://img.shields.io/badge/IaC-Terraform-orange)
![Runtime](https://img.shields.io/badge/runtime-FunctionGraph-purple)
![License](https://img.shields.io/badge/license-MIT-lightgrey)
---

```
                    +-------------------+
                    |   Python Client   |
                    |   (Simulator)     |
                    +--------+----------+
                             |
                    JWT Bearer Token
                             |
                    +--------v----------+
                    |   APIG Instance   |
                    |   (API Gateway)   |
                    +--------+----------+
                             |
              +--------------+--------------+
              |              |              |
     /product/{id}   /order/{id}    (6 endpoints)
              |              |              |
     +--------v---+  +-------v----+  +-----v-----+
     | Function-  |  | Function-  |  | Function- |
     | Graph x3   |  | Graph x3   |  |  (shared  |
     | (Product)  |  | (Order)    |  |   layers) |
     +----+-------+  +-----+------+  +-----------+
          |                |
          |    +-----------+-----------+
          |    |                       |
     +----v----v---+          +-------v--------+
     |  DDS MongoDB|          |  OBS Buckets   |
     |  (ReplicaSet)|         |  (logs/metrics)|
     |  Pool + Silo |          +----------------+
     |  Collections |
     +-------+------+
             |
     +-------v--------+
     |  DLI Queue +   |
     |  Database +    |
     |  Tables (SQL   |
     |  on OBS data)  |
     +----------------+
```
**Data flow:**
1. Client sends HTTP request with JWT bearer token to APIG
2. APIG routes to the matching FunctionGraph function
3. Function extracts tenant ID from JWT via token-manager
4. Partition-manager determines the MongoDB collection (Pool or Silo)
5. DAL performs CRUD operation on DDS MongoDB
6. log-manager writes structured logs to OBS
7. metrics-manager records performance metrics to OBS
8. DLI queries OBS data for analytics
---

## 3. Highlights

- **Tenant Context via JWT**: Each request carries a JWT token with
  `tenantId` claim; verified server-side with a shared signing key
- **Pool Partitioning**: All tenants share one collection
  (e.g., `products_pooled`), filtered by `tenantId` field
- **Silo Partitioning**: Each tenant gets a dedicated collection
  (e.g., `orders_silo_tenant1`)
- **Shared Layer Code**: 5 helper modules (token, log, metrics,
  partition, helper) bundled into each function's `lib/` directory
- **Centralized Observability**: All logs and metrics written to OBS
  as JSON objects, queryable via DLI SQL
- **Serverless**: No servers to manage; scales to zero; pay-per-use
---

## 4. Cloud Services

The practice uses Huawei Cloud services provisioned by the `infra/` Terraform configurations.

## 5. Prerequisites

- **Terraform** >= 1.3 installed
- **Huawei Cloud account** with AK/SK credentials
- **Node.js** >= 14 and **npm** (for building function packages)
- **Python** >= 3.8 with `pip` (for client simulator)
- **zip** command-line tool
- Environment variables:
  ```bash
  export HW_ACCESS_KEY="your-access-key"
  export HW_SECRET_KEY="your-secret-key"
  export HW_SECURITY_TOKEN="your-token"  # if using temporary credentials
  ```
---

## 6. Quick Start

```bash

## 7. Deployment

The Terraform code in `infra/` creates the following resources:
| Resource | Count | Purpose |
|---|---|---|
| VPC + Subnet + Security Group | 1 each | Network for DDS + APIG |
| DDS MongoDB Replica Set | 1 | Document database for CRUD |
| OBS Buckets | 3 | Logs, metrics, function code |
| FunctionGraph Functions | 6 | Product/Order Get/Put/Delete |
| APIG Instance + Group | 1 each | API Gateway |
| APIG APIs | 6 | REST endpoints |
| APIG Environment + Publish | 1 + 6 | Production deployment |
| DLI Queue + Database + Tables | 1 + 1 + 2 | Analytics on OBS data |
**To deploy:**
```bash
cd infra/
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```
After deployment, use `terraform output` to get the APIG endpoint URL,
DDS connection string, and OBS bucket names.
---

Function code is automatically deployed as part of the Terraform apply:
1. `build.sh` packages each function (handler + DAL + layer code +
   node_modules) into a zip file in `src/dist/`
2. Terraform uploads the zips to the OBS code bucket
3. FunctionGraph functions are created referencing the OBS zips
To rebuild functions after code changes:
```bash
cd src/
bash build.sh
cd ../infra/
terraform apply   # re-uploads changed zips and updates functions
```
---

## 8. Usage

Follow the usage/verification steps described in the deployment guide.

## 9. Cleanup

cd ../../infra/
terraform destroy
```
---

```bash
cd infra/
terraform destroy
```
This removes all created resources: DDS instance, OBS buckets,
FunctionGraph functions, APIG instance, DLI queue, VPC, and security
groups. OBS buckets must be emptied before deletion (Terraform handles
this automatically if the bucket is empty).
---

## 10. FAQ

Frequently asked questions are maintained in the deployment guide.

## 11. License

MIT License. See [LICENSE](LICENSE) for details.
---

## 12. Contact

| **Creator** | `Shangdongd` |
| **Maintainer** | `Shangdongd` |

## Appendix

### Table of Contents
1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Key Features](#3-key-features)

5. [Repository Structure](#5-repository-structure)
6. [Prerequisites](#6-prerequisites)
7. [Quick Start](#7-quick-start)
8. [Infrastructure Deployment](#8-infrastructure-deployment)
9. [Function Code Deployment](#9-function-code-deployment)
10. [Client Simulator](#10-client-simulator)
11. [Multi-Tenant Partitioning](#11-multi-tenant-partitioning)
12. [Logging and Metrics](#12-logging-and-metrics)
13. [DLI Data Analytics](#13-dli-data-analytics)
14. [Verification](#14-verification)
15. [Cleanup](#15-cleanup)
16. [Troubleshooting](#16-troubleshooting)
17. [License](#17-license)
---

### 5. Repository Structure
```
serverless-saas-layers/
|-- infra/                       # Terraform IaC
|   |-- versions.tf              # Provider versions
|   |-- variables.tf             # Input variables
|   |-- main.tf                  # All infrastructure resources
|   `-- outputs.tf               # Output values
|-- src/                         # Application source code
|   |-- layers/                  # Shared service layer modules
|   |   |-- helper.js            # OBS upload + MongoDB connection
|   |   |-- token-manager.js     # JWT tenant ID extraction
|   |   |-- log-manager.js       # Structured logging to OBS
|   |   |-- metrics-manager.js   # Performance metrics to OBS
|   |   |-- partition-manager.js # Pool/Silo partition logic
|   |   `-- package.json         # Layer dependencies
|   |-- product-manager/         # Product CRUD handler
|   |   |-- product-manager.js   # APIG event handler
|   |   |-- product-manager-dal.js  # Data access layer
|   |   `-- package.json
|   |-- order-manager/           # Order CRUD handler
|   |   |-- order-manager.js     # APIG event handler
|   |   |-- order-manager-dal.js # Data access layer
|   |   `-- package.json
|   |-- client/                  # Python client simulator
|   |   |-- utils.py             # JWT token generation
|   |   |-- product-simulator.py # Product CRUD simulator
|   |   |-- order-simulator.py   # Order CRUD simulator
|   |   `-- requirements.txt
|   `-- build.sh                 # Function packaging script
|-- docs/                        # Documentation
|   |-- architecture.md          # Architecture details
|   `-- deployment-guide.md      # Step-by-step deployment
|-- README.md                    # Chinese version
`-- README.en.md                 # This file (English)
```
---

### 1. Build function packages
cd src/
bash build.sh

### 2. Deploy infrastructure
cd ../infra/
terraform init
terraform plan
terraform apply   # review and confirm

### 3. Get APIG endpoint
terraform output apig_base_url

### 4. Run client simulator
cd ../src/client/
pip install -r requirements.txt
python product-simulator.py "https://<apig-url>/<group>/product" 10 50
python order-simulator.py "https://<apig-url>/<group>/order" 10 50

### 10. Client Simulator
The Python client simulator sends random CRUD requests to the API:
```bash
cd src/client/
pip install -r requirements.txt

### Product simulator: <url> <seed_count> <total_calls>
python product-simulator.py "https://<apig-url>/<group>/product" 10 50

### Order simulator: <url> <seed_count> <total_calls>
python order-simulator.py "https://<apig-url>/<group>/order" 10 50
```
Each request includes a randomly-generated JWT token with one of three
tenant IDs (`tenant1`, `tenant2`, `tenant3`), demonstrating multi-tenant
data isolation.
---

### 11. Multi-Tenant Partitioning
The partition-manager implements two partitioning strategies:
**Pool Model** (used for Products):
- All tenants share one collection: `products_pooled`
- Each document includes a `tenantId` field
- Queries filter by `tenantId` to isolate tenant data
**Silo Model** (used for Orders):
- Each tenant gets a dedicated collection: `orders_silo_<tenantId>`
- No `tenantId` field needed in documents (collection name provides isolation)
- Stronger data isolation at the cost of more collections
The partition map is defined in `partition-manager.js`:
```javascript
const partitionMap = new Map([
    ['ProductManager', { model: 'Pool', ... }],
    ['OrderManager',   { model: 'Silo', ... }],
]);
```
---

### 12. Logging and Metrics
**Logging** (`log-manager.js`):
- Each log entry is a JSON object written to the OBS logs bucket
- Key format: `<eventSource>/<timestamp>` (e.g., `ProductManager/1234567890`)
- Fields: `tenantId`, `message`, `timestamp`, `productId`/`orderId`
**Metrics** (`metrics-manager.js`):
- Each metric is a JSON object written to the OBS metrics bucket
- Key format: `<eventSource>/<unix_timestamp>`
- Fields: `source`, `type`, `action`, `duration`, `timestamp`, `tenantId`
- Duration is measured in milliseconds
---

### 13. DLI Data Analytics
DLI (Data Lake Insight) provides SQL querying over OBS data:
**Tables created:**
- `application_logs` -- queries JSON log files in the logs bucket
- `application_metrics` -- queries JSON metric files in the metrics bucket
**Example queries:**
```sql
-- Count requests per tenant
SELECT tenantId, COUNT(*) as request_count
FROM application_logs
GROUP BY tenantId;
-- Average response time per action
SELECT action, AVG(duration) as avg_duration_ms
FROM application_metrics
GROUP BY action;
-- Find slow operations (> 1000ms)
SELECT * FROM application_metrics WHERE duration > 1000;
```
Access DLI via the Huawei Cloud console or DLI API.
---

### 14. Verification
After deployment, verify the system:
1. **Check Terraform outputs:**
   ```bash
   terraform output
   ```
2. **Test API endpoints:**
   ```bash
   # Get a product (requires existing data)
   curl -H "Authorization: Bearer <jwt>" \
        https://<apig-url>/<group>/product/0
   # Create/update a product
   curl -X PUT -H "Content-Type: application/json" \
        -H "Authorization: Bearer <jwt>" \
        -d '{"Description":"test","SKU":123,"ProductPrice":100}' \
        https://<apig-url>/<group>/product/0
   ```
3. **Run client simulator** (see section 10)
4. **Verify DDS data:**
   - Connect to DDS MongoDB via mongo shell
   - Check `saas.products_pooled` and `saas.orders_silo_*` collections
5. **Verify OBS logs/metrics:**
   - Check OBS console for objects in logs and metrics buckets
6. **Verify DLI queries:**
   - Run SQL queries in DLI console on `application_logs` and
     `application_metrics` tables
---

### 16. Troubleshooting
| Issue | Cause | Solution |
|---|---|---|
| Function timeout | DDS connection slow | Increase `function_timeout` variable |
| APIG 404 | API not published | Check `terraform apply` completed successfully |
| DDS connection refused | Security group blocks 8635 | Verify SG rule allows subnet CIDR |
| OBS upload fails | Function agency missing | Check IAM agency `fgs_obs_access` exists |
| DLI query returns empty | No data in OBS yet | Run client simulator first to generate logs |
| build.sh fails | Missing npm or zip | Install Node.js and zip utility |
---

### Maintainer
**`Shangdongd`** - Project Maintainer
