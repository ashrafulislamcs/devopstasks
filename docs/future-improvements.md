# Future Improvements

### 1. GitOps with Argo CD
- **What:** Replace the `kubectl apply`/`set image` deploy step with Argo CD
  continuously reconciling the cluster against a Git repo of manifests.
- **Why needed:** Right now deploys are push-based and imperative; there's no
  single source of truth for "what's actually running."
- **Business value:** Faster, auditable rollbacks (`git revert`), and any
  manual cluster drift self-heals back to the declared state.
- **Implementation:** Install Argo CD, point it at a `k8s/` (or a separate
  "gitops" repo), and have CI only update image tags in that repo instead of
  calling `kubectl` directly.
- **Risk reduced:** Configuration drift, undocumented manual changes, slow
  or error-prone manual rollbacks.

### 2. Image vulnerability scanning
- **What:** Add Trivy or Grype scanning as a required CI step before push,
  in addition to ECR's scan-on-push (already enabled in Terraform).
- **Why needed:** Catch known CVEs in base images/dependencies before they
  reach production, not after.
- **Business value:** Reduces the chance of a security incident and the cost
  of patching in production under pressure.
- **Implementation:** Add a `trivy image` step in the GitHub Actions
  workflow that fails the build above a severity threshold (e.g. CRITICAL).
- **Risk reduced:** Shipping known-vulnerable dependencies.

### 3. Monitoring and alerting (Prometheus + Grafana)
- **What:** Deploy kube-prometheus-stack for cluster/app metrics and
  Grafana dashboards, alerting via Alertmanager to Slack/PagerDuty.
- **Why needed:** CloudWatch gives infrastructure-level visibility but not
  rich application/business metrics or fast on-call alerting.
- **Business value:** Faster detection and resolution of incidents, less
  downtime.
- **Implementation:** Helm install of kube-prometheus-stack, instrument the
  backend with a `/metrics` endpoint, define SLO-based alert rules.
- **Risk reduced:** Undetected outages, slow incident response.

### 4. Rollback strategy
- **What:** Formalize `kubectl rollout undo` (or Argo CD's revision history)
  as a documented, rehearsed runbook, backed by keeping the previous 3–5
  image tags available.
- **Why needed:** There's currently no explicit rollback procedure.
- **Business value:** Minimizes downtime and blast radius from a bad deploy.
- **Implementation:** Document the rollback command in `docs/`, tag every
  release image immutably (already enforced by ECR `IMMUTABLE` tags), and
  add a rollback job/button to the pipeline.
- **Risk reduced:** Extended outages from a bad release with no fast way back.

### 5. Helm chart
- **What:** Convert the raw `k8s/` manifests into a parameterized Helm chart
  (or Kustomize overlays) for dev/staging/production.
- **Why needed:** Raw YAML duplicates config across environments and is
  error-prone to keep in sync.
- **Business value:** Faster, safer environment promotion; less copy-paste drift.
- **Implementation:** `helm create`, move current manifests into templates,
  parameterize replicas/resources/image tags per environment `values.yaml`.
- **Risk reduced:** Environment configuration drift.

### 6. Kubernetes autoscaling (HPA + Cluster Autoscaler)
- **What:** Add a HorizontalPodAutoscaler for frontend/backend based on
  CPU/memory, and Cluster Autoscaler (or Karpenter) for the node group.
- **Why needed:** Fixed 2-replica deployments won't handle traffic spikes or
  save cost during quiet periods.
- **Business value:** Better cost efficiency and resilience under load
  without manual intervention.
- **Implementation:** `kubectl autoscale deployment backend --min=2 --max=10
  --cpu-percent=70`, install Cluster Autoscaler with IAM permissions scoped
  to the node group's ASG.
- **Risk reduced:** Outages under traffic spikes; overspend during low traffic.

### 7. Production approval gates
- **What:** Require manual approval (GitHub Environments protection rules)
  before the `deploy` job runs against the production environment.
- **Why needed:** Currently every merge to `main` can auto-deploy; there's
  no human checkpoint before production impact.
- **Business value:** Reduces risk of accidental or unreviewed production changes.
- **Implementation:** Configure a GitHub "production" Environment with
  required reviewers, and gate the `deploy` job on that environment.
- **Risk reduced:** Unintended or unreviewed production deployments.

### 8. Private cluster (no public API endpoint)
- **What:** Set `endpoint_public_access = false` on the EKS cluster and
  require a bastion host or VPN/Direct Connect to reach `kubectl`.
- **Why needed:** The current setup keeps the public endpoint on for
  simplicity, which is not ideal for a real production environment.
- **Business value:** Meaningfully shrinks the attack surface for the
  control plane.
- **Implementation:** Flip the Terraform variable, stand up a bastion or
  AWS Systems Manager Session Manager access path for operators.
- **Risk reduced:** Exposure of the Kubernetes API to the public internet.

### 9. WAF (Web Application Firewall)
- **What:** Attach AWS WAF to the ALB created by the Ingress controller.
- **Why needed:** The frontend is the one component intentionally exposed
  to the internet, so it's the most exposed attack surface.
- **Business value:** Blocks common web exploits (SQLi, XSS, bot traffic)
  before they reach application code.
- **Implementation:** Terraform `aws_wafv2_web_acl` associated with the ALB
  ARN, with AWS-managed rule groups enabled.
- **Risk reduced:** Web application attacks, scraping, basic DDoS patterns.

### 10. Blue/green or canary deployments
- **What:** Roll new versions to a small percentage of traffic first (e.g.
  via Argo Rollouts) before shifting 100%.
- **Why needed:** Standard rolling updates still expose all users to a bad
  release, just gradually.
- **Business value:** Catches bad releases with minimal user impact and
  enables instant traffic-level rollback.
- **Implementation:** Install Argo Rollouts, replace `Deployment` with
  `Rollout` for frontend/backend, define canary steps and analysis based on
  error rate/latency.
- **Risk reduced:** Wide-blast-radius bad deployments.

### 11. Backup and disaster recovery
- **What:** Automated RDS snapshots (already have 7-day retention) plus
  cross-region snapshot copy, and Velero for Kubernetes object/PV backups.
- **Why needed:** Current setup protects against instance failure but not
  region-level disaster or accidental resource deletion.
- **Business value:** Meets a real recovery-time/recovery-point objective
  instead of hoping nothing catastrophic happens.
- **Implementation:** Terraform `aws_db_instance` snapshot copy to a second
  region; Velero scheduled backups to S3.
- **Risk reduced:** Data loss, extended recovery time after a major incident.

### 12. Network policies
- **What:** Add Kubernetes `NetworkPolicy` resources so only the frontend
  pods can talk to backend pods, and only backend pods can talk to the
  database — enforced at the pod network level, not just security groups.
- **Why needed:** Currently any pod in the namespace could reach any other
  pod; there's no pod-to-pod network segmentation.
- **Business value:** Defense-in-depth — limits lateral movement if any
  single pod is compromised.
- **Implementation:** Requires a CNI that supports NetworkPolicy (e.g.
  Calico on EKS), then define allow-lists per app label.
- **Risk reduced:** Lateral movement from a compromised pod.

### 13. Cost optimization
- **What:** Move stateless workloads to EC2 Spot node groups where
  tolerable, right-size requests/limits based on actual usage (via VPA
  recommendations), and add AWS Budgets alerts.
- **Why needed:** No current cost controls or right-sizing feedback loop.
- **Business value:** Lower infrastructure spend without reducing reliability.
- **Implementation:** Add a Spot-backed secondary node group for
  fault-tolerant workloads, review Vertical Pod Autoscaler recommendations
  monthly, set AWS Budget alerts on the account.
- **Risk reduced:** Unnecessary cloud spend / budget overruns.
