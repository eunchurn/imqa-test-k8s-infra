#!/bin/bash

# 원하는 네임스페이스 지정
NS=test
BACKUP_DIR="deployments"

# 백업 디렉토리 생성
mkdir -p $BACKUP_DIR

echo "=== 네임스페이스 $NS 의 Kubernetes 리소스 백업 시작 ==="
echo ""

# Deployment 백업
echo "📦 Deployment 백업 중..."
kubectl get deploy -n $NS --no-headers -o custom-columns=":metadata.name" | while read -r DEPLOY; do
    if [ -n "$DEPLOY" ]; then
        BACKUP_FILE="${BACKUP_DIR}/${NS}-${DEPLOY}-deployment.yaml"
        if kubectl get deploy $DEPLOY -n $NS -o yaml > $BACKUP_FILE; then
            echo "✅ Deployment 백업 성공: $BACKUP_FILE"
        else
            echo "❌ Deployment 백업 실패: $DEPLOY"
        fi
    fi
done

echo ""

# Service 백업 (헬름 차트에서 생성된 서비스 제외하고 커스텀 서비스만)
echo "🌐 Service 백업 중..."
kubectl get svc -n $NS --no-headers -o custom-columns=":metadata.name" | while read -r SVC; do
    if [ -n "$SVC" ]; then
        # Helm으로 생성된 서비스인지 확인 (app.kubernetes.io/managed-by: Helm 라벨)
        MANAGED_BY=$(kubectl get svc $SVC -n $NS -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null)
        
        if [ "$MANAGED_BY" != "Helm" ]; then
            BACKUP_FILE="${BACKUP_DIR}/${NS}-${SVC}-service.yaml"
            if kubectl get svc $SVC -n $NS -o yaml > $BACKUP_FILE; then
                echo "✅ Service 백업 성공: $BACKUP_FILE"
            else
                echo "❌ Service 백업 실패: $SVC"
            fi
        else
            echo "⏭️  Service 스킵 (Helm 관리): $SVC"
        fi
    fi
done

echo ""

# Ingress 백업
echo "🌍 Ingress 백업 중..."
kubectl get ing -n $NS --no-headers -o custom-columns=":metadata.name" | while read -r ING; do
    if [ -n "$ING" ]; then
        BACKUP_FILE="${BACKUP_DIR}/${NS}-${ING}-ingress.yaml"
        if kubectl get ing $ING -n $NS -o yaml > $BACKUP_FILE; then
            echo "✅ Ingress 백업 성공: $BACKUP_FILE"
        else
            echo "❌ Ingress 백업 실패: $ING"
        fi
    fi
done

echo ""
echo "=== 백업 완료 ==="
echo "백업된 파일들:"
ls -la ${BACKUP_DIR}/${NS}-*.yaml 2>/dev/null || echo "백업된 파일이 없습니다."