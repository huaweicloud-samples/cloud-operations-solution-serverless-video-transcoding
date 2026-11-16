# Architecture

## Overview

This document describes the architecture of the serverless multi-tenant
SaaS application deployed on Huawei Cloud.

## Architecture Diagram

```
                         +---------------------+
                         |    Client Layer     |
                         |  (Python Simulator) |
                         +---------+-----------+
                                   |
                          JWT Bearer Token (tenantId)
                                   |
                         +---------v-----------+
                         |   APIG Instance     |
                         |   (API Gateway)     |
                         |   BASIC Edition     |
                         +---------+-----------+
                                   |
                    +--------------+--------------+
                    |                             |
           /product/{resourceId}          /order/{resourceId}
           GET / PUT / DELETE             GET / PUT / DELETE
                    |                             |
          +---------v---------+         +---------v---------+
          | FunctionGraph x3  |         | FunctionGraph x3  |
          | (Product Manager) |         | (Order Manager)   |
          |                   |         |                   |
          | handler.js        |         | handler.js        |
          | dal.js            |         | dal.js            |
          | lib/ (5 modules)  |         | lib/ (5 modules)  |
          +----+---------+----+         +----+---------+----+
               |         |                   |         |
               |         +-------+-----------+         |
               |                 |                     |
      +--------v--------+ +------v------+      +-------v-------+
      |  DDS MongoDB    | |  OBS Buckets|      |   OBS Buckets |
      |  (ReplicaSet)   | |  (Logs)     |      |   (Metrics)   |
      |                 | +-------------+      +---------------+
      |  saas DB        |
      |  |-- products_pooled   (Pool: shared)
      |  |-- orders_silo_t1    (Silo: per-tenant)
      |  |-- orders_silo_t2
      |  `-- orders_silo_t3
      +--------+--------+
               |
      +--------v--------+
      |  DLI Queue      |
      |  + Database     |
      |  + Tables (SQL) |
      +-----------------+
```

## Components

### 1. APIG (API Gateway)

- **Instance**: Dedicated BASIC edition, deployed in the VPC
- **Group**: Logical grouping for all SaaS APIs
- **Environment**: "production" environment for API publishing
- **APIs**: 6 REST endpoints (3 product + 3 order)
- **Path Parameters**: `{resourceId}` extracted and passed to
  FunctionGraph in the event's `pathParameters`

### 2. FunctionGraph (Serverless Compute)

- **Runtime**: Node.js 14.x
- **Handler Pattern**: `<module>.<function>` (e.g., `product-manager.get`)
- **Code Source**: OBS zip packages
- **VPC Access**: Each function is configured with VPC ID and network
  ID to access DDS MongoDB on the private network
- **Memory**: 256 MB (configurable)
- **Timeout**: 15 seconds (configurable)

### 3. DDS MongoDB (Document Database)

- **Mode**: ReplicaSet (single-node replica for demo)
- **Engine**: DDS-Community 4.0 with WiredTiger
- **Flavor**: `dds.mongodb.s6.medium.4.repset`
- **Port**: 8635
- **SSL**: Enabled
- **Database**: `saas`
- **Security**: Security group allows port 8635 only from subnet CIDR

### 4. OBS (Object Storage)

Three buckets are created:
- **Logs bucket**: Stores structured JSON log entries
- **Metrics bucket**: Stores JSON performance metrics
- **Code bucket**: Stores function zip packages

### 5. DLI (Data Lake Insight)

- **Queue**: SQL queue with 16 CU for running analytics queries
- **Database**: Dedicated database for SaaS analytics
- **Tables**: Two OBS-backed JSON tables for logs and metrics
- **Purpose**: Enables SQL queries over log/metric data without
  a separate data warehouse

## Shared Service Layer

Five helper modules are bundled into each function's `lib/` directory:

```
function zip structure:
|-- <handler>.js          # APIG event handler
|-- <handler>-dal.js      # Data access layer
|-- lib/
|   |-- helper.js         # OBS client + MongoDB connection
|   |-- token-manager.js  # JWT verification
|   |-- log-manager.js    # Structured logging to OBS
|   |-- metrics-manager.js # Performance metrics to OBS
|   `-- partition-manager.js # Pool/Silo partition logic
|-- node_modules/
|   |-- mongodb/          # MongoDB driver
|   |-- njwt/             # JWT library
|   `-- esdk-obs-nodejs/  # OBS SDK
`-- package.json
```

## Multi-Tenant Data Flow

```
1. Client sends request:
   PUT /product/123
   Authorization: Bearer <jwt with tenantId="tenant1">
   Body: {"Description":"widget","SKU":42,"Price":100}

2. APIG routes to product_put function

3. product-manager.js handler:
   -> log-manager.log() writes to OBS logs bucket
   -> DAL calls partitionManager.getPartition()

4. partition-manager.js:
   -> token-manager.getTenantId() extracts "tenant1" from JWT
   -> Looks up ProductManager -> model=Pool
   -> Returns: { collectionName: "products_pooled", isPooled: true }

5. product-manager-dal.js:
   -> Connects to DDS MongoDB
   -> db.collection("products_pooled").updateOne(
        { tenantId: "tenant1", productId: "123" },
        { $set: { doc: "{...}" } },
        { upsert: true }
      )

6. metrics-manager.recordMetricEvent():
   -> Writes { source: "ProductManager", action: "UpdateProduct",
               duration: 45, tenantId: "tenant1" }
   -> To OBS metrics bucket

7. Returns: { statusCode: 200, body: "" }
```

## Security Considerations

- DDS MongoDB is only accessible from within the VPC subnet
- OBS buckets are private (ACL: private)
- APIG exposes HTTPS endpoints to the internet
- JWT signing key is shared between client and server (hardcoded
  for demo; in production, use a secret manager)
- FunctionGraph functions access OBS via an IAM agency
- DDS password is passed via Terraform variable (should use
  a secrets manager in production)
