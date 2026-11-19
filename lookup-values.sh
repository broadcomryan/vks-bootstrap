#!/usr/bin/env bash
# Step 4a: lists the values for cluster.yaml. Read-only. Usage: CLUSTER_NS=system-1-ns-poc-1 ./lookup-values.sh
set -eu
: "${CLUSTER_NS:?set CLUSTER_NS}"
echo "Kubernetes versions (use as printed):"
kubectl get kr -o json | jq -r '.items[] | select([.status.conditions[]? | select(.type=="Ready" or .type=="Compatible") | .status] | length==2 and all(.=="True")) | .spec.version | sub("-vkr[.][0-9]+$"; "")'
echo; echo "Cluster classes:"; kubectl get clusterclass -n vmware-system-vks-public -o name
echo; echo "VM classes:";      kubectl get virtualmachineclass -n "$CLUSTER_NS" --no-headers
echo; echo "Storage classes:"; kubectl get storagepolicyquota -n "$CLUSTER_NS" -o jsonpath='{range .items[*].status.total[*]}{.storageClassName}{"\n"}{end}' | sort -u
