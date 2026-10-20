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

```bash
npm start
```

The API listens on port `3000` by default. Set `PORT` to change it. Visit `/` for a welcome response or `/health` for the health check.

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

Milestones 1-2: repository setup, sample API, basic test, and container definition are in place. Terraform infrastructure is prepared in `infra/`; review and deployment are the next steps. CI/CD and monitoring alerts will follow.
