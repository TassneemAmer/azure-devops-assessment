# Azure infrastructure

Terraform provisions a resource group, VNet and dedicated subnets, private PostgreSQL Flexible Server, Azure Container Registry, Container Apps environment and API app, and Log Analytics workspace.

The PostgreSQL subnet is delegated to Flexible Server and the server has public network access disabled. The Container Apps environment uses a consumption workload profile with external HTTPS ingress on the API only. A Microsoft sample container is used initially so Terraform can create and demonstrate the app before the GitHub Actions pipeline publishes the assessment image. The sample listens on port 80; the pipeline milestone will switch the app image and ingress to the assessment API on port 3000. Terraform explicitly ignores future changes to those two fields so CI/CD owns them after initial provisioning.

## Prerequisites

- Terraform 1.9 or newer
- Azure CLI
- An Azure subscription with permission to create the resources and role assignment in this configuration

Sign in and select the intended subscription:

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
az account show --query id -o tsv
```

From the `infra/` directory, create a local variables file from the example and set its `subscription_id`. The example file contains no secrets. Supply the PostgreSQL password through an environment variable instead of writing it to a file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

In Git Bash, enter a strong password without placing it in the shell command history:

```bash
read -r -s -p "PostgreSQL admin password: " TF_VAR_db_admin_password; echo
export TF_VAR_db_admin_password
```

Then review the proposed resources before deployment:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

Only after reviewing the plan, deploy with `terraform apply`. To remove assessment resources after capturing evidence, run `terraform destroy` from this directory. Confirm the target subscription and plan before applying or destroying resources.

## State and secrets

Terraform state can contain the PostgreSQL administrator password. Keep the state file private, never commit it, and do not share it as an assessment artifact. The root `.gitignore` excludes Terraform state, local variables files, and `.terraform/`.
