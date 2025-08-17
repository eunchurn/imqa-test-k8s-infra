#!/bin/bash

# 백업 파일명 (날짜 포함)
BACKUP_FILE="cluster-backup-$(date +%Y%m%d-%H%M%S).yaml"

# 네임스페이스 리소스 전체 백업
for ns in $(kubectl get ns --no-headers -o custom-columns=":metadata.name"); do
  echo "### Namespace: $ns ###" >> $BACKUP_FILE
  kubectl get $(kubectl api-resources --verbs=list --namespaced -o name | tr '\n' ',' | sed 's/,$//') \
    -n $ns -o yaml >> $BACKUP_FILE
done

# 클러스터 스코프 리소스 (네임스페이스 없는 것들)
echo "### Cluster Scoped Resources ###" >> $BACKUP_FILE
kubectl get $(kubectl api-resources --verbs=list --namespaced=false -o name | tr '\n' ',' | sed 's/,$//') \
  -o yaml >> $BACKUP_FILE

echo "백업 완료: $BACKUP_FILE"