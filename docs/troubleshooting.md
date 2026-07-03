# Troubleshooting

### 1. Pod is in `CrashLoopBackOff`. What do you check?
- `kubectl describe pod <pod>` for the last termination reason/exit code.
- `kubectl logs <pod> --previous` to see why the *previous* container instance died.
- Confirm the container's start command/entrypoint is correct and the app
  isn't crashing on a missing env var, bad config, or failing DB connection.
- Check resource limits — an OOMKilled exit code means the memory limit is too low.
- Verify the readiness/liveness probe paths and ports actually match the app.

### 2. Deployment is successful, but app is not reachable. What do you check?
- `kubectl get pods` — are pods actually `Running` and `Ready`?
- `kubectl get svc` — does the Service selector match the pod labels?
- `kubectl get endpoints <service>` — empty endpoints means the selector isn't
  matching any pod.
- Confirm the container port, Service `targetPort`, and app's listening port
  all line up.
- Check the Ingress/Gateway routing and the ingress controller's own logs.

### 3. Difference between readiness and liveness probe?
- **Readiness** answers "can this pod receive traffic right now?" — if it
  fails, the pod is pulled out of the Service's endpoint list (no restart).
- **Liveness** answers "is this pod still healthy/alive?" — if it fails
  repeatedly, Kubernetes kills and restarts the container.
- Readiness protects users from being routed to a not-yet-ready pod (e.g.
  during startup); liveness recovers a pod that's stuck/deadlocked.

### 4. Docker build works locally but fails in pipeline. Why?
- Different base image cache state — CI often builds with no cache, exposing
  missing lockfile entries or an untracked local file.
- `.dockerignore` differences, or a file the build needs wasn't committed to git.
- Platform/architecture mismatch (e.g. local Apple Silicon `arm64` image vs.
  CI's `amd64` runner).
- Missing build secrets/credentials that only exist on the local machine.

### 5. Pipeline fails during Docker build. What do you check?
- Read the exact failing layer/step in the CI log — usually a `RUN` command.
- Confirm base image tag still exists and is reachable from the CI runner
  (network/registry auth issues).
- Check for a dependency version that changed upstream since the Dockerfile
  was written (unpinned versions).
- Confirm build context size/paths are correct relative to where the
  pipeline invokes `docker build`.

### 6. Certificate renewal failed. What do you check?
- If using cert-manager: `kubectl describe certificate` and `kubectl
  describe certificaterequest` for the actual error.
- DNS-01/HTTP-01 challenge failure — confirm the DNS record or HTTP path is
  actually reachable from the certificate authority.
- Rate limiting from the CA (e.g. Let's Encrypt) from too many recent attempts.
- Expired or revoked account credentials for the ACME/CA integration.

### 7. Ingress returns 502 or 504. What do you check?
- **502** usually means the backend pod returned an invalid response or
  crashed mid-request — check backend pod logs and readiness.
- **504** usually means the backend took too long — check app performance,
  DB query time, and increase the ingress/controller timeout if legitimately slow.
- Confirm the Service the Ingress points to has healthy endpoints.
- Check the ingress controller's own logs/pods for errors reaching upstream.

### 8. Vendor SFTP connection to port 22 times out. What do you check?
- Security group / NSG / firewall rule — is inbound/outbound 22 actually
  allowed between the two specific IP ranges involved?
- Network ACL rules (stateless — check both directions).
- Whether the vendor's IP is on an allow-list that changed, or a NAT
  gateway's egress IP changed and needs to be re-whitelisted on their side.
- Confirm the SFTP service is actually running/listening on the target host.

### 9. Terraform plan wants to recreate the cluster. What do you check?
- Read the `# forces replacement` attribute in the plan output precisely.
- Compare against the last known-good state — did someone change an
  immutable field (name, subnet set, etc.)?
- Check for drift: a manual change made directly in the cloud console that
  Terraform now wants to "fix" by recreating.
- Don't apply until the cause is understood; treat any full recreate of a
  cluster as requiring a planned migration window.

### 10. How would you upgrade AKS/EKS safely?
- Upgrade control plane one minor version at a time, after checking the
  deprecated/removed API list for the target version.
- Upgrade node groups afterward using a rolling/max-unavailable strategy so
  workloads are never all down at once.
- Do it in dev → staging → production order, watching pod health and app
  metrics at each step.

### 11. Frontend loads, but backend API calls fail. What do you check?
- Browser console / network tab for the actual failing request and status code.
- Confirm the frontend is using the correct internal Service DNS name for
  the backend (e.g. `http://backend:8080`), not `localhost`.
- `kubectl exec` into the frontend pod and `curl` the backend Service
  directly to isolate network vs. app-level issues.
- Check backend pod logs and any NetworkPolicy that might be blocking
  frontend→backend traffic.

### 12. Backend pod is running, but database connection times out. What do you check?
- Confirm the DB security group actually allows inbound traffic from the
  EKS node/pod security group on the DB port.
- Confirm the backend pod and RDS instance are in subnets that can route to
  each other (both private, same VPC, correct route tables).
- Check the DB endpoint/hostname value in the ConfigMap/Secret is correct
  and current (RDS endpoints can change after certain maintenance events).
- Confirm the database is actually up (`aws rds describe-db-instances`) and
  not mid-failover.

### 13. Private DNS is not resolving database hostname. What do you check?
- Confirm the Route 53 private hosted zone is associated with the correct
  VPC (the one the EKS nodes actually run in).
- Confirm `enableDnsSupport` and `enableDnsHostnames` are enabled on the VPC.
- `kubectl exec` into a pod and run `nslookup`/`dig` against the hostname to
  see exactly where resolution fails.
- Check CoreDNS pods/logs in the cluster for errors forwarding to the VPC resolver.

### 14. How would you rotate database credentials safely?
- Generate a new password in AWS Secrets Manager (or have Secrets Manager's
  automatic rotation Lambda do it).
- Update the RDS master user password to match.
- Update/refresh the Kubernetes Secret (ideally automatically via External
  Secrets Operator watching Secrets Manager).
- Perform a rolling restart of backend pods so they pick up the new
  credential (`kubectl rollout restart deployment/backend`) — with 2+
  replicas this causes zero downtime.
- Only after confirming the new pods connect successfully, consider the
  rotation complete; keep the old credential valid for a short overlap
  window if the DB engine supports it.

### 15. Secrets were accidentally committed to GitHub. What do you do?
- Immediately rotate/invalidate the exposed credential at the source (AWS
  key, DB password, API token) — treat it as compromised the moment it hit
  git history, regardless of repo visibility.
- Remove it from git history (`git filter-repo` or BFG Repo-Cleaner), not
  just a follow-up commit that deletes the file — the old commit still
  contains it.
- Force-push the cleaned history and have all collaborators re-clone.
- Audit access/usage logs (CloudTrail, etc.) for any unauthorized use during
  the exposure window.
- Add the pattern to `.gitignore` and add a pre-commit secret scanner
  (e.g. gitleaks) to prevent recurrence.

---
