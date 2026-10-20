# Architecture Notes

## Proposed design

The assessment will use Azure Container Apps to host a small HTTP API in a Docker container. The API will use Azure Database for PostgreSQL Flexible Server as its managed relational database. Azure Container Registry will store the built image. Terraform will provision the cloud resources, and GitHub Actions will run the build, a simple test, image publishing, and deployment when changes reach `main`.

## Rationale

- **Azure Container Apps** provides managed container hosting with HTTP ingress and scaling, avoiding VM administration for this small demonstration.
- **Azure Database for PostgreSQL Flexible Server** demonstrates use of a managed database rather than a database container.
- **Terraform** makes infrastructure repeatable and reviewable as code.
- **GitHub Actions** keeps CI/CD alongside the source repository and can use federated credentials or repository secrets instead of committed credentials.
- **Azure Monitor and Log Analytics** provide a place to inspect app logs and configure an example alert.

## Security baseline

The implementation should expose only the API's required HTTP ingress, restrict database access to the application path, scope identities and roles to required actions, use encrypted managed services, and keep credentials out of source control. The exact network design will be confirmed while implementing the infrastructure.

## Trade-offs and production follow-up

This is a time-boxed assessment, so the application and test coverage will stay small. A production design would need a reviewed high-availability and backup plan, capacity and cost targets, stronger operational dashboards and alerting, and a deliberate private-network and identity design. These are documented considerations, not claims that the demo is production-ready.
