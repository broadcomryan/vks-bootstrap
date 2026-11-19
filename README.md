# VKS GitOps with the Argo CD Supervisor Service

Argo CD on Supervisor `system-1` builds VKS guest clusters from folders in this repo.
**Adding a cluster = adding a folder.** Nothing is built or changed until someone clicks SYNC.

```
setup/                                  applied by hand with kubectl, once
  01-argocd-instance.yaml               Argo CD instance in vSphere Namespace system-1-argocd
  02-rbac-<namespace>.yaml              one per granted vSphere Namespace (RoleBinding + ManagedEntity)
  03-project-vks-clusters.yaml          project: this repo only, granted namespaces only, Cluster objects only
  04-appset-vks-clusters.yaml           one Application per clusters/<namespace>/<cluster>/ folder
  repo-credential.yaml.example          template only; never commit a filled copy
clusters/
  system-1-ns-poc-1/                    vSphere Namespace
    wrkld-system-1-poc-1/cluster.yaml   one VKS cluster
    wrkld-system-1-poc-2/cluster.yaml
  system-1-ns-poc-2/
    wrkld-system-1-poc-3/cluster.yaml
lookup-values.sh                        lists valid versions, classes and storage for cluster.yaml
```

## Rules
- Parent folder = vSphere Namespace = the Cluster's `metadata.namespace`.
- Folder name = cluster name = Application name, unique across all namespaces. Never rename; that's a new cluster.
- Argo CD acts as one service account (`argocd-k8s-sa`). It only reaches namespaces granted by hand
  in `setup/`. A folder under any other namespace shows "not permitted in project".
- Apps sync manually, have no finalizer, and the ApplicationSet preserves resources on deletion,
  so removing a folder or app never deletes a cluster.

## Fresh install (new Supervisor or rebuild)
| Step | Who | Do |
|---|---|---|
| 1 | vCenter admin | Install the Argo CD Supervisor Service (1.2.0+); create `system-1-argocd` and each cluster namespace (Edit for platform admins; VM class + storage policy on the cluster namespace) |
| 2 | you | Set `spec.version` in 01, then `kubectl apply -f setup/01-argocd-instance.yaml`; wait for Ready: `kubectl get argocd argocd -n system-1-argocd -w` |
| 3 | you | `kubectl apply -f setup/02-rbac-system-1-ns-poc-1.yaml -f setup/02-rbac-system-1-ns-poc-2.yaml`; wait for Ready: `kubectl get managedentity -n system-1-argocd` |
| 4 | you | Private repo: fill a copy of `setup/repo-credential.yaml.example` outside the repo, apply it, delete the copy |
| 5 | you | `kubectl apply -f setup/03-project-vks-clusters.yaml -f setup/04-appset-vks-clusters.yaml` |
| 6 | you | In the UI, for each cluster app: DIFF, then SYNC |

UI address and first password:
```sh
kubectl get argocd argocd -n system-1-argocd -o jsonpath='https://{.status.externalIP}{"\n"}'
kubectl get secret argocd-initial-admin-secret -n system-1-argocd -o go-template='{{.data.password | base64decode}}{{"\n"}}'
```

## Day-2
**Add a cluster:** copy a working `cluster.yaml` to `clusters/system-1-ns-poc-1/<new-name>/`, change
`metadata.name`, push. Its app appears within about 3 minutes; DIFF, then SYNC. Check the namespace
has a free load-balancer IP and storage (about 84 GB for 1+2 nodes at best-effort-medium).

**Change a cluster:** edit its `cluster.yaml` (worker count, VM class, Kubernetes version one minor
at a time, from `lookup-values.sh`), push, review the DIFF, SYNC. Never change name, namespace or network ranges.

**Remove a cluster:** delete its folder (the app goes away, the cluster stays), then deliberately
`kubectl delete cluster <name> -n <namespace>`.

**Use a cluster:**
```sh
kubectl get secret <cluster>-kubeconfig -n <namespace> -o jsonpath='{.data.value}' | base64 -d > ~/.kube/<cluster>.kubeconfig
kubectl --kubeconfig ~/.kube/<cluster>.kubeconfig get nodes
```

**Add a vSphere Namespace** (example: `system-1-ns-poc-2`). Do the steps in this order:
1. vCenter: Supervisor Management -> Namespaces -> New Namespace. Name in lowercase. Add Edit permission
   for platform admins, a VM class, a storage policy, and resource limits.
2. Copy `setup/02-rbac-system-1-ns-poc-1.yaml` to `setup/02-rbac-<namespace>.yaml`, replace the namespace
   name, apply it, wait for the ManagedEntity to be Ready: `kubectl get managedentity -n system-1-argocd`.
3. Add the namespace to `destinations` in `setup/03-project-vks-clusters.yaml`, apply it.
4. `CLUSTER_NS=<namespace> ./lookup-values.sh`, then add `clusters/<namespace>/<cluster>/cluster.yaml`. Push, DIFF, SYNC.

No ApplicationSet change, no new service account.

## Troubleshooting
| Symptom | Fix |
|---|---|
| ManagedEntity `MissingRoleBinding` | RoleBinding from 02 missing or in the wrong namespace |
| `not permitted in project` | Namespace not granted (02-rbac-<ns>) or not in the project's destinations (03) |
| `repository not accessible` | Bad token, or the Supervisor can't reach GitHub (behind a proxy: set `spec.repo.proxy.httpsProxy` on the ArgoCD instance) |
| OutOfSync right after sync | `version` ends in `-vkr.N`; remove that ending |
| Progressing over 30 min | `kubectl describe clusters.cluster.x-k8s.io <cluster> -n <namespace>` |

## Next steps (one at a time)
1. Add-ons: cert-manager via AddonInstall, then Contour, then Harbor
2. Register guest clusters with Argo CD and deploy workloads into them
3. A root app so `setup/` lives in Git
4. Supervisor `system-2`
5. Hardening: SSO, automated sync
