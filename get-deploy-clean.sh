#!/bin/bash

# 원하는 네임스페이스 지정
NS=test
BACKUP_DIR="deployments-clean"

# 백업 디렉토리 생성
mkdir -p $BACKUP_DIR

echo "=== 네임스페이스 $NS 의 배포용 Kubernetes 리소스 생성 시작 ==="
echo ""

# Deployment 백업 (배포 가능한 깨끗한 버전)
echo "📦 Deployment 배포용 YAML 생성 중..."
kubectl get deploy -n $NS --no-headers -o custom-columns=":metadata.name" | while read -r DEPLOY; do
    if [ -n "$DEPLOY" ]; then
        BACKUP_FILE="${BACKUP_DIR}/${NS}-${DEPLOY}-deployment.yaml"
        if kubectl get deploy $DEPLOY -n $NS -o yaml | \
           grep -v -E "(creationTimestamp|generation|resourceVersion|uid|deployment.kubernetes.io/revision)" | \
           sed '/^status:/,$d' > $BACKUP_FILE; then
            echo "✅ Deployment 배포용 YAML 생성 성공: $BACKUP_FILE"
        else
            echo "❌ Deployment 배포용 YAML 생성 실패: $DEPLOY"
        fi
    fi
done

echo ""

# Service 백업 (배포 가능한 깨끗한 버전)
echo "🌐 Service 배포용 YAML 생성 중..."
kubectl get svc -n $NS --no-headers -o custom-columns=":metadata.name" | while read -r SVC; do
    if [ -n "$SVC" ]; then
        # Helm으로 생성된 서비스인지 확인
        MANAGED_BY=$(kubectl get svc $SVC -n $NS -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null)
        
        if [ "$MANAGED_BY" != "Helm" ]; then
            BACKUP_FILE="${BACKUP_DIR}/${NS}-${SVC}-service.yaml"
            if kubectl get svc $SVC -n $NS -o yaml | \
               grep -v -E "(creationTimestamp|resourceVersion|uid|clusterIP|clusterIPs)" | \
               sed '/^status:/,$d' > $BACKUP_FILE; then
                echo "✅ Service 배포용 YAML 생성 성공: $BACKUP_FILE"
            else
                echo "❌ Service 배포용 YAML 생성 실패: $SVC"
            fi
        else
            echo "⏭️  Service 스킵 (Helm 관리): $SVC"
        fi
    fi
done

echo ""

# Ingress 백업 (배포 가능한 깨끗한 버전)
echo "🌍 Ingress 배포용 YAML 생성 중..."
kubectl get ing -n $NS --no-headers -o custom-columns=":metadata.name" | while read -r ING; do
    if [ -n "$ING" ]; then
        BACKUP_FILE="${BACKUP_DIR}/${NS}-${ING}-ingress.yaml"
        if kubectl get ing $ING -n $NS -o yaml | \
           grep -v -E "(creationTimestamp|generation|resourceVersion|uid)" | \
           sed '/^status:/,$d' > $BACKUP_FILE; then
            echo "✅ Ingress 배포용 YAML 생성 성공: $BACKUP_FILE"
        else
            echo "❌ Ingress 배포용 YAML 생성 실패: $ING"
        fi
    fi
done

echo ""
echo "=== 배포용 YAML 생성 완료 ==="
echo "생성된 파일들:"
ls -la ${BACKUP_DIR}/${NS}-*.yaml 2>/dev/null || echo "생성된 파일이 없습니다."

echo ""
echo "💡 이제 이 파일들로 다른 환경에 배포할 수 있습니다:"
echo "kubectl apply -f ${BACKUP_DIR}/"
