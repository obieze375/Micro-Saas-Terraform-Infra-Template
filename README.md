# Micro-Saas-Terraform-Infra-Template
---

## Usage

1. Copy sample vars:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. (Optional) load AWS credentials from a local `.env` file:

```bash
set -a
source .env
set +a
```

3. Deploy:

```bash
terraform init
terraform plan
terraform apply
```
