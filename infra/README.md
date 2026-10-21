# Azure infrastructure

Terraform provisions a resource group, VNet and dedicated subnets, private PostgreSQL Flexible Server, Azure Container Registry, Container Apps environment and API app, and Log Analytics workspace.

The PostgreSQL subnet is delegated to Flexible Server and the server has public network access disabled. The Container Apps environment uses a consumption workload profile with external HTTPS ingress on the API only. Terraform creates the API app with a placeholder image; GitHub Actions publishes and deploys the assessment image on pushes to `main`. The API listens on port 3000. Terraform ignores future image changes so CI/CD owns image deployment.

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

From the `infra/` directory, create a local variables file from the example and set its `subscription_id` and `github_deployer_service_principal_object_id`. Use the service principal's **Object ID** from Microsoft Entra **Enterprise applications**; do not use the app registration's client ID. The example file contains placeholders and no secrets. Supply the PostgreSQL password through an environment variable instead of writing it to a file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

In Git Bash, enter strong administrator and application passwords without placing them in shell command history:

```bash
read -r -s -p "PostgreSQL admin password: " TF_VAR_db_admin_password; echo
export TF_VAR_db_admin_password
read -r -s -p "PostgreSQL application password: " TF_VAR_db_app_password; echo
export TF_VAR_db_app_password
```

The app password must be at least 24 characters. Terraform supplies it to the API as its restricted `assessmentapp` login and to a manual Container Apps Job. Terraform configures the administrator password on PostgreSQL and injects it into the bootstrap job, but does not pass it to the API container. The job connects to PostgreSQL over the Container Apps environment's VNet path and creates or updates the app login. After the first `terraform apply`, start the bootstrap job once:

```bash
az containerapp job start --name job-azassessment-dev-db-bootstrap --resource-group rg-azassessment-dev
```

The API revision may report `/ready` as unavailable until this job completes. Check that the job execution succeeds in Azure Portal under the job's **Executions** page before relying on the API's `/ready` or `/items` endpoints. Run the job again after changing the app password. The job creates the table with the admin login and grants the app role only `USAGE` on the schema, `SELECT` and `INSERT` on the table, and sequence access. The API does not receive schema-creation rights. The psql output is silenced so generated SQL containing the app password is not written to job logs.

Then review the proposed resources before deployment:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

Only after reviewing the plan, deploy with `terraform apply`. To remove assessment resources after capturing evidence, run `terraform destroy` from this directory. Confirm the target subscription and plan before applying or destroying resources.

The GitHub Actions principal receives **Container Apps Contributor** only on the Container App and **Reader** on its Container Apps environment, while **AcrPush** remains scoped to the registry. The environment read grant lets the deployment inspect its parent environment while keeping write access limited to the app. After Terraform applies the new grants, remove the older `Container Apps Contributor` grant at resource-group scope in Azure Portal (**Resource group → Access control (IAM) → Role assignments**), then rerun the GitHub Actions workflow to verify the narrower permissions. If deployment fails, restore the resource-group grant while troubleshooting.

## State and secrets

Terraform state contains both PostgreSQL passwords. Keep the state file private, never commit it, and do not share it as an assessment artifact. The root `.gitignore` excludes Terraform state, local variables files, and `.terraform/`.
