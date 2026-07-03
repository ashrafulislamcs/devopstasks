# DevOps Assessment - Production-Ready Kubernetes Platform (AWS EKS)

A minimal but production-style platform: containerized frontend + backend,
CI/CD via GitHub Actions, Kubernetes manifests, a private database, and
Terraform-provisioned AWS infrastructure (EKS/ECR/RDS/VPC/monitoring).

> Built for AWS EKS. The same structure maps directly onto Azure AKS —
> see the "Azure equivalent" note at the bottom of `terraform/README.md`.

## Repository structure

```
devops-assessment/
├── frontend/                # Node/Express app, calls backend, serves a web page
├── backend/                 # Node/Express API: / and /health on port 8080
├── docker-compose.yml       # Run both locally with one command
├── .dockerignore / .gitignore
├── .github/workflows/deploy.yml   # CI/CD: test -> build -> push -> release -> deploy
├── k8s/                      # Kubernetes manifests (Task 3)
├── terraform/                 # Custom-module Terraform for AKS/EKS (Task 5)
└── docs/
    ├── troubleshooting.md
    ├── future-improvements.md
    └── private-database-connectivity.md   # Task 4 write-up
```

## Task 1 - Run locally

```bash
docker compose up -d
curl http://localhost:8080          # -> "Application is running"
curl http://localhost:8080/health   # -> {"status":"ok"}
curl http://localhost:3000          # frontend page, calls backend internally
```

## Task 2 - CI/CD

`.github/workflows/deploy.yml` runs on every push/PR to `main`:
1. **Test** frontend and backend independently (`npm test` — a small
   built-in smoke test, no external framework needed).
2. **Build** both Docker images and tag them with the short git SHA (never
   `:latest` in the deployable manifests).
3. **Push** to ECR — if `ECR_REGISTRY`/AWS secrets aren't configured in the
   repo, this step becomes a clearly-labeled **mock push** (builds/tags
   still run, push is skipped) so the pipeline is runnable out of the box.
4. **Release** — creates a git tag and GitHub Release.
5. **Deploy** — applies the image update to the cluster via `kubectl`, or a
   labeled **mock deploy** if `KUBE_CONFIG_DATA` isn't configured.

Secrets (AWS keys, registry URL, kubeconfig) are all read from **GitHub
Secrets** — see the comment block at the bottom of `deploy.yml` for how this
maps to Jenkins Credentials / Azure DevOps Variable Groups / Key Vault /
Secrets Manager as alternatives.

## Task 3 - Kubernetes

See `k8s/`. Highlights:
- Frontend and backend are separate `Deployment`s, each with 2 replicas.
- Backend `Service` is `ClusterIP` only — never exposed outside the cluster.
- `Ingress` exposes only the frontend, via an ALB.
- Readiness + liveness probes, resource requests/limits, and a ConfigMap +
  example Secret are all included. Image tags are placeholders
  (`<IMAGE_TAG>`), substituted by the CI pipeline — never hardcoded as `latest`.

Apply manually:
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/
```

## Task 4 - Private database connectivity

Full write-up in `docs/private-database-connectivity.md`: EKS nodes and RDS
share private subnets in one VPC, RDS has `publicly_accessible = false`, a
Route 53 private hosted zone resolves the DB hostname only inside the VPC,
and a security group locks inbound 5432 down to just the EKS node
security group.

## Task 5 - Terraform

See `terraform/` — custom modules only (`vpc`, `eks`, `ecr`, `rds`,
`monitoring`), remote S3 backend with DynamoDB locking. Full explanation of
upgrades, node pool resizing, state maintenance, environment separation, and
secret handling is in `terraform/README.md`.

```bash
cd terraform
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

## Task 6 - Troubleshooting

`docs/troubleshooting.md` — answers to all 15 scenario questions.

## Task 7 - Future improvements

`docs/future-improvements.md` — 13 prioritized improvements (GitOps,
scanning, monitoring, autoscaling, WAF, canary deploys, network policies,
cost optimization, etc.), each with why/how/risk-reduced.

## Security notes
- No secrets, keys, tokens, or Terraform state are committed to this repo
  (`.gitignore` excludes `.tfstate`, `.env`, `*.pem`, `*.key`, `kubeconfig`).
- `k8s/backend-secret-example.yaml` is an **example** with a placeholder
  value only — real secrets are injected at deploy time from AWS Secrets
  Manager / Azure Key Vault.
