# Deployment Guide

This guide walks through deploying the serverless SaaS application
on Huawei Cloud.

## Prerequisites

### Tools

| Tool | Version | Purpose |
|---|---|---|
| Terraform | >= 1.3 | Infrastructure deployment |
| Node.js + npm | >= 14 | Build function packages |
| Python + pip | >= 3.8 | Run client simulator |
| zip | any | Package functions |
| hcloud CLI (optional) | >= 7.0 | Manual cloud operations |

### Credentials

Set Huawei Cloud credentials as environment variables:

```bash
export HW_ACCESS_KEY="your-access-key"
export HW_SECRET_KEY="your-secret-key"
# If using temporary credentials:
export HW_SECURITY_TOKEN="your-security-token"
```

### Region

Default region is `cn-north-4`. Change in `infra/variables.tf` if needed.

## Step 1: Build Function Packages

```bash
cd src/
bash build.sh
```

This script:
1. Creates a temp directory for each function (product-manager, order-manager)
2. Copies the handler, DAL, and shared layer code (`lib/`)
3. Runs `npm install --production` to fetch dependencies
4. Creates zip files in `src/dist/`

Verify the output:
```bash
ls -lh src/dist/*.zip
# Should show:
#   product-manager.zip
#   order-manager.zip
```

## Step 2: Initialize Terraform

```bash
cd infra/
terraform init
```

This downloads the Huawei Cloud provider plugin.

## Step 3: Review the Plan

```bash
terraform plan -out=tfplan
```

Review the resources that will be created. You should see:
- 1 VPC, 1 subnet, 1 security group (with rules)
- 1 DDS MongoDB instance
- 3 OBS buckets
- 6 FunctionGraph functions
- 1 APIG instance, 1 group, 6 APIs, 1 environment, 6 publishments
- 1 DLI queue, 1 database, 2 tables

## Step 4: Deploy

```bash
terraform apply tfplan
```

Type `yes` when prompted. Deployment takes approximately 15-25 minutes
(DDS instance creation is the longest step).

## Step 5: Get Outputs

```bash
terraform output
```

Key outputs:
- `apig_base_url` -- the APIG endpoint URL
- `apig_group_name` -- the API group name (needed for URL path)
- `dds_connection_string` -- MongoDB connection string
- `obs_buckets` -- bucket names for logs, metrics, code
- `dli_info` -- DLI queue and database names

## Step 6: Test APIs

### Manual curl test

Generate a JWT token:
```bash
python3 -c "
import jwt
token = jwt.encode({'tenantId': 'tenant1'}, '<your-signing-key>', algorithm='HS256')  # 与 SAAS_JWT_SECRET 保持一致
if isinstance(token, bytes): token = token.decode()
print(token)
"
```

Test product CRUD:
```bash
APIG_URL=$(terraform output -raw apig_base_url)
GROUP=$(terraform output -raw apig_group_name)
TOKEN="<jwt-from-above>"

# Create a product
curl -X PUT \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"Description":"test product","SKU":123,"ProductPrice":100}' \
  "${APIG_URL}/${GROUP}/product/1"

# Get the product
curl -H "Authorization: Bearer $TOKEN" \
  "${APIG_URL}/${GROUP}/product/1"

# Delete the product
curl -X DELETE -H "Authorization: Bearer $TOKEN" \
  "${APIG_URL}/${GROUP}/product/1"
```

### Client simulator

```bash
cd src/client/
pip install -r requirements.txt

APIG_URL=$(terraform output -raw apig_base_url)
GROUP=$(terraform output -raw apig_group_name)

# Seed 10 products, then make 50 random calls
python product-simulator.py "${APIG_URL}/${GROUP}/product" 10 50

# Seed 10 orders, then make 50 random calls
python order-simulator.py "${APIG_URL}/${GROUP}/order" 10 50
```

## Step 7: Verify Data

### DDS MongoDB

Connect via mongo shell (from a VM in the same VPC):
```bash
mongo "mongodb://rwuser:<password>@<dds-host>:8635/saas?authSource=admin&replicaSet=replica&ssl=true"
```

Check collections:
```javascript
use saas
show collections
// products_pooled
// orders_silo_tenant1
// orders_silo_tenant2
// orders_silo_tenant3

db.products_pooled.find().pretty()
db.orders_silo_tenant1.find().pretty()
```

### OBS Logs and Metrics

Via OBS console or CLI:
```bash
# List log objects
hcloud obs ls bucket=<logs-bucket-name> --region=cn-north-4

# List metric objects
hcloud obs ls bucket=<metrics-bucket-name> --region=cn-north-4
```

### DLI Queries

In the DLI console:
1. Navigate to DLI > SQL Editor
2. Select the queue and database
3. Run queries:
```sql
SELECT tenantId, COUNT(*) as requests
FROM application_logs
GROUP BY tenantId;

SELECT action, AVG(duration) as avg_ms
FROM application_metrics
GROUP BY action;
```

## Step 8: Cleanup

```bash
cd infra/
terraform destroy
```

Type `yes` to confirm. This removes all resources.

**Note**: OBS buckets must be empty before deletion. If the buckets
contain log/metric objects, you may need to manually clear them first:
```bash
# Clear OBS bucket (if Terraform can't delete non-empty bucket)
hcloud obs rm bucket=<bucket-name> --recursive --region=cn-north-4
```

## Troubleshooting

### terraform init fails

- Check network connectivity to registry
- Verify Terraform version >= 1.3

### build.sh fails

- Ensure Node.js and npm are installed: `node --version`
- Ensure zip is installed: `which zip`
- Try manual npm install: `cd src/layers && npm install`

### DDS creation fails

- Check the flavor is available in your AZ:
  `hcloud dds list-flavors --region=cn-north-4`
- Try a different AZ in variables.tf

### FunctionGraph creation fails

- Verify the OBS code bucket was created
- Check that the zip files exist in src/dist/
- Verify the function agency exists or create it manually

### APIG returns 404

- Verify APIs were published to the environment
- Check the URL path includes the group name
- Verify the request method matches (GET/PUT/DELETE)

### DDS connection timeout from function

- Verify the function has VPC ID and network ID configured
- Check the security group allows port 8635 from the subnet CIDR
- Verify the DDS instance is in the same VPC/subnet as the function
