# Terraform - EKS Platform Provisioning

This provisions the AWS infrastructure for the platform: a VPC with public/private
subnets, an EKS cluster with a private-subnet node group, ECR repositories,
a private RDS PostgreSQL instance, and CloudWatch monitoring.

All infrastructure is built from **custom modules only** (`./modules/vpc`,
`./modules/eks`, `./modules/ecr`, `./modules/rds`, `./modules/monitoring`) —
no third-party/community Terraform Registry modules are used.

## Usage

```bash
cd terraform
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

## Remote backend & state locking

State is stored in an S3 bucket (`test-assessment-tfstate`, versioning
enabled) with locking handled by a DynamoDB table
(`test-assessment-tf-locks`, partition key `LockID`). This means:
- State is never stored locally or committed to git.
- Two people/pipelines can't run `apply` at the same time — the second one
  blocks until the first releases the lock.
- S3 versioning gives us a rollback path if state ever gets corrupted.

## How to safely upgrade AKS/EKS

1. Upgrade the **control plane** first, one minor version at a time (e.g.
   1.28 → 1.29, never skip versions). Done by bumping `kubernetes_version`
   and applying — AWS handles this with no workload downtime.
2. Check the Kubernetes deprecated API list for the target version before
   upgrading, and fix any manifests using removed APIs.
3. Upgrade **node groups** second, using the node group's `update_config
   { max_unavailable = 1 }` (already set), which performs a rolling
   replacement so only one node is drained/replaced at a time.
4. Watch `kubectl get nodes` and `kubectl get pods -A` throughout; readiness
   probes ensure traffic isn't sent to a pod before it's ready on the new node.
5. Upgrade one environment at a time: dev → staging → production.

## How to add or resize node pools

- Change `node_desired_count` / `node_min_count` / `node_max_count` /
  `node_instance_type` in `variables.tf` (or pass as `-var`) and re-apply.
- To add an entirely new node group (e.g. a GPU pool), copy the
  `aws_eks_node_group` resource in `modules/eks/main.tf` with a new name and
  instance type — existing pods are untouched since it's an additive change.
- Resizing (changing desired/min/max count) never recreates the cluster —
  only the node group's scaling config is updated in place.

## How Terraform state is maintained

- Remote backend (above) is the source of truth — nobody runs `apply` from
  local, un-synced state.
- `terraform plan` is run in CI on every PR touching `terraform/` so drift
  and unintended changes are visible before merge.
- State is never manually edited. If drift or corruption happens, use
  `terraform state show/list` to inspect and `terraform import` /
  `terraform state rm` deliberately rather than editing the file.

## How to avoid downtime during cluster changes

- Minimum 2 replicas + readiness/liveness probes (see `k8s/`) mean the
  Kubernetes scheduler always keeps at least one healthy pod serving traffic
  during a node replacement.
- Node group rolling updates (`max_unavailable = 1`) replace nodes one at a
  time, never all at once.
- Pod Disruption Budgets (recommended future addition, see
  `docs/future-improvements.md`) further guarantee a minimum number of
  available pods during voluntary disruptions like node drains.

## How to separate dev, staging, and production

- Same module code, different **state files and variable values** per
  environment — e.g. `terraform apply -var="environment=staging"` combined
  with a separate backend `key` per environment
  (`eks/dev/terraform.tfstate`, `eks/staging/terraform.tfstate`, etc.), or
  separate Terraform Cloud/CI workspaces.
- Each environment gets its own VPC, cluster, and RDS instance — no shared
  infrastructure between environments, so a mistake in dev can't reach
  production.
- Production-only behaviors are already parameterized in the RDS module
  (`multi_az`, `deletion_protection`, `skip_final_snapshot` all key off
  `var.environment == "production"`).

## How to handle secrets outside Terraform code

- The RDS module generates the database password with `random_password` and
  immediately stores it in **AWS Secrets Manager** — it is never written to
  a `.tfvars` file or hardcoded.
- `terraform.tfstate` will still contain the password (Terraform state
  always contains resource attributes), which is exactly why the state
  bucket is private, encrypted, and access-restricted via IAM — state
  itself is treated as sensitive.
- CI/CD credentials (AWS keys) live in GitHub Secrets / Jenkins Credentials
  / Azure Key Vault, never in `.tf` files.

## What to check if Terraform wants to recreate the cluster

1. Run `terraform plan` and read exactly which attribute triggers
   `# forces replacement`.
2. Common causes: changing `vpc_config.subnet_ids` (whole subnet list swap
   instead of `update_config`), changing the cluster `name`, or changing an
   immutable attribute like `name_prefix`.
3. Compare state vs. actual AWS console/CLI values — someone may have made
   a manual change outside Terraform (drift).
4. If the diff looks unintentional, do **not** apply — first run
   `terraform state show aws_eks_cluster.this` to compare against the plan,
   and check recent commits to `variables.tf` / `main.tf` for the change
   that introduced it.
5. If a genuine recreate is required, plan a maintenance window and migrate
   workloads to a new cluster (blue/green) rather than deleting the
   existing one in place, to avoid downtime.

## Azure equivalent (if AKS is chosen instead of EKS)

The module structure stays the same; swap providers/resources:
`aws_vpc`→`azurerm_virtual_network`, `aws_eks_cluster`→
`azurerm_kubernetes_cluster`, `aws_ecr_repository`→
`azurerm_container_registry`, `aws_db_instance`→
`azurerm_postgresql_flexible_server` (with `public_network_access_enabled =
false` and a private endpoint), and CloudWatch→Log Analytics workspace.
