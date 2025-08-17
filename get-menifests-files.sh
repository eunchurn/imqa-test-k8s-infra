#!/bin/bash

# 원하는 네임스페이스 지정
NS=test
CONTEXT=$(kubectl config current-context 2>/dev/null || echo "default")
BASE_DIR="${CONTEXT}/${NS}"

# 리소스 타입별 디렉토리 생성
mkdir -p "${BASE_DIR}/deployments"
mkdir -p "${BASE_DIR}/services"
mkdir -p "${BASE_DIR}/ingress"
mkdir -p "${BASE_DIR}/configmaps"
mkdir -p "${BASE_DIR}/secrets"
mkdir -p "${BASE_DIR}/replicasets"
mkdir -p "${BASE_DIR}/statefulsets"

echo "=== 네임스페이스 $NS 의 배포용 Kubernetes 리소스 생성 시작 ==="
echo "📁 컨텍스트: $CONTEXT"
echo "📁 네임스페이스: $NS"
echo "📁 기본 디렉토리: $BASE_DIR"
echo ""

# Deployment 백업 (배포 가능한 깨끗한 버전)
echo "📦 Deployment 배포용 YAML 생성 중..."
kubectl get deploy -n $NS --no-headers -o custom-columns=":metadata.name" | while read -r DEPLOY; do
    if [ -n "$DEPLOY" ]; then
        BACKUP_FILE="${BASE_DIR}/deployments/${DEPLOY}.yaml"
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
            BACKUP_FILE="${BASE_DIR}/services/${SVC}.yaml"
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
        BACKUP_FILE="${BASE_DIR}/ingress/${ING}.yaml"
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

# ConfigMap 백업 (배포 가능한 깨끗한 버전)
echo "🗂️  ConfigMap 배포용 YAML 생성 중..."
kubectl get cm -n $NS --no-headers -o custom-columns=":metadata.name" | while read -r CM; do
    if [ -n "$CM" ] && [ "$CM" != "kube-root-ca.crt" ]; then
        BACKUP_FILE="${BASE_DIR}/configmaps/${CM}.yaml"
        if kubectl get cm $CM -n $NS -o yaml | \
           grep -v -E "(creationTimestamp|resourceVersion|uid)" | \
           sed '/^status:/,$d' > $BACKUP_FILE; then
            echo "✅ ConfigMap 배포용 YAML 생성 성공: $BACKUP_FILE"
        else
            echo "❌ ConfigMap 배포용 YAML 생성 실패: $CM"
        fi
    fi
done

echo ""

# Secret 백업 (배포 가능한 깨끗한 버전)
echo "🔐 Secret 배포용 YAML 생성 중..."
kubectl get secrets -n $NS --no-headers -o custom-columns=":metadata.name" | while read -r SECRET; do
    if [ -n "$SECRET" ]; then
        # 기본 서비스 어카운트 토큰 스킵
        SECRET_TYPE=$(kubectl get secret $SECRET -n $NS -o jsonpath='{.type}' 2>/dev/null)
        if [ "$SECRET_TYPE" != "kubernetes.io/service-account-token" ]; then
            BACKUP_FILE="${BASE_DIR}/secrets/${SECRET}.yaml"
            if kubectl get secret $SECRET -n $NS -o yaml | \
               grep -v -E "(creationTimestamp|resourceVersion|uid)" | \
               sed '/^status:/,$d' > $BACKUP_FILE; then
                echo "✅ Secret 배포용 YAML 생성 성공: $BACKUP_FILE"
            else
                echo "❌ Secret 배포용 YAML 생성 실패: $SECRET"
            fi
        else
            echo "⏭️  Secret 스킵 (Service Account Token): $SECRET"
        fi
    fi
done

echo ""

# ReplicaSet 백업 (배포 가능한 깨끗한 버전)
echo "📋 ReplicaSet 배포용 YAML 생성 중..."
kubectl get rs -n $NS --no-headers -o custom-columns=":metadata.name" | while read -r RS; do
    if [ -n "$RS" ]; then
        BACKUP_FILE="${BASE_DIR}/replicasets/${RS}.yaml"
        if kubectl get rs $RS -n $NS -o yaml | \
           grep -v -E "(creationTimestamp|generation|resourceVersion|uid)" | \
           sed '/^status:/,$d' > $BACKUP_FILE; then
            echo "✅ ReplicaSet 배포용 YAML 생성 성공: $BACKUP_FILE"
        else
            echo "❌ ReplicaSet 배포용 YAML 생성 실패: $RS"
        fi
    fi
done

echo ""

# StatefulSet 백업 (배포 가능한 깨끗한 버전)
echo "🏛️  StatefulSet 배포용 YAML 생성 중..."
kubectl get sts -n $NS --no-headers -o custom-columns=":metadata.name" 2>/dev/null | while read -r STS; do
    if [ -n "$STS" ]; then
        BACKUP_FILE="${BASE_DIR}/statefulsets/${STS}.yaml"
        if kubectl get sts $STS -n $NS -o yaml | \
           grep -v -E "(creationTimestamp|generation|resourceVersion|uid)" | \
           sed '/^status:/,$d' > $BACKUP_FILE; then
            echo "✅ StatefulSet 배포용 YAML 생성 성공: $BACKUP_FILE"
        else
            echo "❌ StatefulSet 배포용 YAML 생성 실패: $STS"
        fi
    fi
done

echo ""
echo "=== 배포용 YAML 생성 완료 ==="
echo "📁 생성된 폴더 구조:"
echo "   $BASE_DIR/"
echo "   ├── deployments/"
echo "   ├── services/"
echo "   ├── ingress/"
echo "   ├── configmaps/"
echo "   ├── secrets/"
echo "   ├── replicasets/"
echo "   └── statefulsets/"
echo ""
echo "📋 생성된 파일들:"
find "$BASE_DIR" -name "*.yaml" | sort

echo ""
echo "💡 배포 방법:"
echo "  전체 배포: kubectl apply -R -f $BASE_DIR/"
echo "  특정 리소스만: kubectl apply -f $BASE_DIR/deployments/"
echo "  특정 파일만: kubectl apply -f $BASE_DIR/deployments/api.yaml"
