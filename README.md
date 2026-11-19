# First VKS guest cluster with Argo CD

Manifests for the runbook "VKS + Argo CD: first guest cluster". Names used throughout:
Argo CD namespace `system-1-argocd`, cluster namespace `system-1-ns-poc-1`, cluster `wrkld-system-1-poc-1`.
If yours differ, search and replace those three strings in every file.

Copy `clusters/` into your Git repo. `setup/` is applied by hand (it can live in the repo too).

| Step | Do |
|---|---|
| 1 | vCenter admin installs the Argo CD Supervisor Service; create both vSphere Namespaces (Edit for you, VM class + storage policy on the cluster namespace) |
| 2 | Set `spec.version`, then `kubectl apply -f setup/01-argocd-instance.yaml` and `kubectl get argocd argocd -n system-1-argocd -w` until Ready |
| 3 | `kubectl apply -f setup/02-rbac-cluster-namespace.yaml` and `kubectl get managedentity -n system-1-argocd` until Ready |
| 4a | `CLUSTER_NS=system-1-ns-poc-1 ./lookup-values.sh`, then fill the CHANGE-ME values in `clusters/.../cluster.yaml` |
| 4b | Commit and push `clusters/wrkld-system-1-poc-1/cluster.yaml` to `main` |
| 4c | Private repo: fill a copy of `setup/repo-credential.yaml.example` outside the repo, apply it, delete the copy |
| 4d | `kubectl apply -f setup/03-project-vks-clusters.yaml` |
| 5 | `kubectl apply -f setup/04-app-wrkld-system-1-poc-1.yaml`, then in the UI: DIFF (left side empty), SYNC, SYNCHRONIZE |

Log in to the UI:
```sh
kubectl get argocd argocd -n system-1-argocd -o jsonpath='https://{.status.externalIP}{"\n"}'
kubectl get secret argocd-initial-admin-secret -n system-1-argocd -o go-template='{{.data.password | base64decode}}{{"\n"}}'
```

Watch the build (5-10 minutes), then check the nodes:
```sh
kubectl get clusters.cluster.x-k8s.io wrkld-system-1-poc-1 -n system-1-ns-poc-1 -w
kubectl get secret wrkld-system-1-poc-1-kubeconfig -n system-1-ns-poc-1 -o jsonpath='{.data.value}' | base64 -d > ~/.kube/wrkld-system-1-poc-1.kubeconfig
kubectl --kubeconfig ~/.kube/wrkld-system-1-poc-1.kubeconfig get nodes
```
