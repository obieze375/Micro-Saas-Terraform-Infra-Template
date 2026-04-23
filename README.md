# Micro-Saas-Terraform-Infra-Template
---

## Intro

Used this article: (https://aws.plainenglish.io/i-built-a-full-saas-app-on-aws-for-1-34-month-heres-the-architecture-0e5482683cd9) as inspiration to create a production-grade terraform template capable of hosting a micro-saas application 

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
