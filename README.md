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

## Status

The API exposes `/health` for process health and `/ready` for PostgreSQL readiness. Terraform configures the PostgreSQL connection for the Container App; CI/CD and monitoring alerts will follow.
