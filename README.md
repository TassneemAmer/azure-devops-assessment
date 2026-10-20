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

## Status

Initial repository setup. Implementation and deployment instructions will be added in later milestones.