# Azure DevOps Assessment

A small three-tier application deployment demonstrating infrastructure as code, containerization, CI/CD, and basic monitoring on Azure.

## Planned architecture

- **API:** A small containerized API with a health endpoint
- **Compute:** Azure Container Apps
- **Database:** Azure Database for PostgreSQL Flexible Server
- **Container registry:** Azure Container Registry
- **Infrastructure:** Terraform
- **CI/CD:** GitHub Actions, with build, test, image build, and deployment on pushes to `main`
- **Monitoring:** Azure Monitor and Log Analytics

See [architecture notes](docs/architecture-notes.md) for rationale and trade-offs.
Terraform files and deployment instructions are in [`infra/`](infra/README.md).

## Run locally

Requires Node.js 24 or newer.

Install dependencies:

```bash
npm ci
```

```bash
npm start
```

The API listens on port `3000` by default. Set `PORT` to change it. Visit `/` for a welcome response or `/health` for the health check.

When PostgreSQL connection settings are configured, `/ready` checks database connectivity with a simple query. It returns HTTP 503 if the database is not configured or cannot be reached.

The database-backed items API is available at `GET /items` to list items and `POST /items` to create one. Send JSON such as `{"name":"assessment demo"}` to create an item. The API creates the `assessment_items` table on first use. The database password is supplied to Azure Container Apps as a secret through Terraform; do not commit `terraform.tfvars` or Terraform state files.

Run the basic API tests with:

```bash
npm test
```

Build and run the container from the repository root with:

```bash
docker build -t azure-devops-assessment-api .
docker run --rm -p 3000:3000 azure-devops-assessment-api
```

## GitHub Actions deployment

The workflow in `.github/workflows/ci-cd.yml` installs dependencies and runs `npm test` on pull requests and pushes to `main`. On pushes to `main`, it also authenticates to Azure with OpenID Connect, builds and pushes an image tagged with the commit SHA to Azure Container Registry, and updates the Azure Container App.

Configure these **repository variables** in GitHub under **Settings → Secrets and variables → Actions → Variables**:

| Variable | Value |
| --- | --- |
| `AZURE_CLIENT_ID` | Application (client) ID of `github-azure-devops-assessment` |
| `AZURE_TENANT_ID` | Directory (tenant) ID for the Azure subscription |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID containing the assessment resources |

No Azure client secret is required. The Entra application must have a federated credential for this repository's `main` branch, **Container Apps Contributor** access on the resource group, and **AcrPush** access on the registry. The Container App's managed identity pulls the deployed image from the registry.

## Status

The API exposes `/health` for process health and `/ready` for PostgreSQL readiness. Terraform provisions the Azure resources. The GitHub Actions workflow is configured to build, test, publish the image, and deploy on pushes to `main`; configure the repository variables above and push the workflow to enable it. Monitoring alerts remain to be configured.
