# MIDI Generator — Terraform Infrastructure

AWS infrastructure for the MIDI Generator API. Three environments (dev, qa, prod), S3-backed state.

## Architecture

```
Internet
   ↓
CloudFront (HTTPS termination)
   ↓
ALB (HTTP on port 80)
   ↓
ECS Fargate (FastAPI, public subnet, public IP)
   ├─→ RDS PostgreSQL (public subnet, SG-isolated, not publicly accessible)
   ├─→ S3 bucket (MIDI files)
   └─→ Secrets Manager (Anthropic API key, DB password)
```

**Network topology:** simplified — public subnets only across 2 AZs, no NAT Gateway. RDS is protected by security group (only ECS can reach it). Chosen to keep costs low for a portfolio project.

## Project structure

```
terraform/
├── backend/                         ← bootstrap state (run once)
│   └── main.tf
│
├── ecr/                             ← ECR stack (own state, deployed first)
│   ├── terraform/
│   │   ├── main.tf
│   │   ├── ecr.tf
│   │   └── _variables.tf
│   └── tfvars/
│       ├── dev.tfvars
│       ├── qa.tfvars
│       └── prod.tfvars
│
└── midigen/                         ← main application stack
    ├── terraform/                   ← shared Terraform code (all .tf files)
    │   ├── main.tf
    │   ├── providers.tf
    │   ├── backend.tf
    │   ├── _variables.tf
    │   ├── vpc.tf
    │   ├── security_groups.tf
    │   ├── rds.tf
    │   ├── s3.tf
    │   ├── secrets.tf
    │   ├── iam.tf
    │   ├── alb.tf
    │   ├── ecs.tf
    │   ├── cloudfront.tf
    │   └── outputs.tf
    ├── taskdefs/
    │   └── task_definition.json     ← ECS task def template (templatefile)
    └── tfvars/
        ├── dev.tfvars
        ├── qa.tfvars
        └── prod.tfvars
```

## Prerequisites

- Terraform >= 1.6
- AWS CLI with credentials configured
- Docker (to build and push the application image)
- Anthropic API key from https://console.anthropic.com

Export the API key before running any `terraform apply` for midigen:

```bash
export TF_VAR_anthropic_api_key="sk-ant-api03-..."
```

## Deployment order

State bootstrap → ECR → build & push image → midigen.

### 1. Bootstrap state backend (once per AWS account)

```bash
cd backend
terraform init
terraform apply
```

Creates `midigen-tf-state` (S3).

### 2. Deploy ECR (per environment)

```bash
cd ../ecr/terraform
terraform init -backend-config="key=ecr/dev/terraform.tfstate"
terraform apply -var-file=../tfvars/dev.tfvars
```

Note the `repository_url` output — you'll need it for the next step.

### 3. Build and push the application image

From the MIDI Generator app repo:

```bash
# Log in to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build
docker build -f backend/Dockerfile -t midigen-api:dev .

# Tag and push
ECR_URL=<account-id>.dkr.ecr.us-east-1.amazonaws.com/midigen-dev-api
docker tag midigen-api:dev $ECR_URL:latest
docker push $ECR_URL:latest
```

### 4. Update midigen tfvars with the image URI

Edit `midigen/tfvars/dev.tfvars`:

```hcl
container_image = "<account-id>.dkr.ecr.us-east-1.amazonaws.com/midigen-dev-api:latest"
```

### 5. Deploy midigen stack

```bash
cd ../../midigen/terraform
terraform init -backend-config="key=midigen/dev/terraform.tfstate"
terraform apply -var-file=../tfvars/dev.tfvars
```

### 6. Get the public URL

```bash
terraform output cloudfront_url
```

Open `https://<cloudfront-id>.cloudfront.net/docs` to reach Swagger.

CloudFront takes 10-15 minutes to propagate globally. Meanwhile you can test via the ALB DNS (HTTP only).

## Switching environments

For ECR:

```bash
cd ecr/terraform
terraform init -reconfigure -backend-config="key=ecr/qa/terraform.tfstate"
terraform apply -var-file=../tfvars/qa.tfvars
```

For midigen:

```bash
cd midigen/terraform
terraform init -reconfigure -backend-config="key=midigen/qa/terraform.tfstate"
terraform apply -var-file=../tfvars/qa.tfvars
```

`-reconfigure` tells Terraform to drop the cached backend config and use the new key.

## Destroying an environment

```bash
cd midigen/terraform
terraform init -reconfigure -backend-config="key=midigen/dev/terraform.tfstate"
terraform destroy -var-file=../tfvars/dev.tfvars

cd ../../ecr/terraform
terraform init -reconfigure -backend-config="key=ecr/dev/terraform.tfstate"
terraform destroy -var-file=../tfvars/dev.tfvars
```

**Warning:** CloudFront distributions take 15-20 minutes to delete.

## Cost estimate per environment (dev sizing, no NAT)

| Resource               | Monthly cost |
|------------------------|--------------|
| RDS t4g.micro          | ~$15         |
| ECS Fargate (idle)     | ~$9          |
| ALB                    | ~$18         |
| S3, Secrets Manager    | ~$2          |
| CloudFront             | ~$1          |
| CloudWatch Logs        | ~$1          |
| **Total**              | **~$46/mo**  |

Full three-env deployment: ~$140/mo. For a portfolio project, deploying only `dev` and destroying when not needed is recommended.

## Design decisions

**1. Stack separation.** ECR and midigen are separate stacks with separate state files. ECR must exist before ECS can pull an image, which forces a two-step deployment and makes image lifecycle independent of application infrastructure.

**2. Shared Terraform + per-env tfvars.** One copy of Terraform code in `midigen/terraform/`, three `.tfvars` files in `midigen/tfvars/`. No code duplication between environments; differences are expressed as variable values.

**3. Dynamic naming via `locals`.** All resource names are computed from `"${var.project}-${var.environment}"` prefix. Adding a new environment only requires a new `.tfvars` file — no code changes.

**4. Task definition as JSON template.** ECS container definition lives in `taskdefs/task_definition.json` with `${...}` placeholders, loaded via `templatefile()`. Keeps ECS config readable and separable from `.tf` logic.

**5. Secrets via two patterns.**
- Anthropic API key: stored in Secrets Manager by Terraform (`aws_secretsmanager_secret_version`), passed as `TF_VAR_anthropic_api_key`
- DB password: auto-generated by RDS (`manage_master_user_password = true`), stored by AWS
Both referenced by ARN in ECS task definition — never passed through the container environment as plain text.
