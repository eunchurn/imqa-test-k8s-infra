#!/bin/bash

# 원하는 네임스페이스 지정
NS="test"
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

# 공통 YAML 정리 함수
clean_yaml_common() {
    # 클러스터가 자동으로 추가하는 메타데이터만 제거
    sed '/^[[:space:]]*creationTimestamp:/d' | \
    sed '/^[[:space:]]*resourceVersion:/d' | \
    sed '/^[[:space:]]*uid:/d' | \
    sed '/^[[:space:]]*generation:/d' | \
    sed '/^[[:space:]]*deployment\.kubernetes\.io\/revision:/d' | \
    # status 섹션 제거
    sed '/^status:/,$d' | \
    # last-applied-configuration 완전 제거 (name과 namespace는 보존)
    awk '
    BEGIN { skip_config = 0 }
    /kubectl\.kubernetes\.io\/last-applied-configuration:/ { 
        skip_config = 1; 
        next 
    }
    skip_config && /^[[:space:]]*name:/ { 
        skip_config = 0; 
        print $0; 
        next 
    }
    skip_config && /^[[:space:]]*namespace:/ { 
        skip_config = 0; 
        print $0; 
        next 
    }
    skip_config && /^[[:space:]]*[^[:space:]]/ && !/^[[:space:]]+/ { 
        skip_config = 0; 
        print $0; 
        next 
    }
    skip_config && /^[^[:space:]]/ { 
        skip_config = 0; 
        print $0; 
        next 
    }
    !skip_config { print $0 }
    ' | \
    # 특정 annotations 제거 (클러스터나 시스템이 자동으로 추가하는 것들)
    sed '/^[[:space:]]*kubectl\.kubernetes\.io\/restartedAt:/d' | \
    sed '/^[[:space:]]*meta\.helm\.sh\/release-name:/d' | \
    sed '/^[[:space:]]*meta\.helm\.sh\/release-namespace:/d' | \
    # annotations 섹션 정리 (checksum 등 유용한 annotations는 보존)
    awk '
    BEGIN { 
        in_annotations = 0; 
        has_useful_annotations = 0;
        annotations_buffer = "";
        annotations_start_line = "";
        in_template_metadata = 0;
        prev_line = "";
    }
    # template.metadata 섹션 감지
    /^[[:space:]]*template:[[:space:]]*$/ { 
        in_template_metadata = 0; 
        prev_line = $0;
        print $0; 
        next; 
    }
    /^[[:space:]]*metadata:[[:space:]]*$/ {
        if (prev_line ~ /template:/) {
            in_template_metadata = 1;
        }
        prev_line = $0;
        print $0;
        next;
    }
    /^[[:space:]]*annotations:[[:space:]]*$/ { 
        in_annotations = 1; 
        has_useful_annotations = 0;
        annotations_buffer = "";
        annotations_start_line = $0;
        prev_line = $0;
        next;
    }
    in_annotations && /^[[:space:]]*[^[:space:]]/ && !/^[[:space:]]+/ { 
        # annotations 블록 끝
        if (has_useful_annotations || in_template_metadata) {
            print annotations_start_line;
            print annotations_buffer;
        }
        in_annotations = 0;
        in_template_metadata = 0;
        prev_line = $0;
        print $0;
        next;
    }
    in_annotations && /^[^[:space:]]/ { 
        # annotations 블록 끝
        if (has_useful_annotations || in_template_metadata) {
            print annotations_start_line;
            print annotations_buffer;
        }
        in_annotations = 0;
        in_template_metadata = 0;
        prev_line = $0;
        print $0;
        next;
    }
    in_annotations {
        # annotations 내용 확인
        if (/^[[:space:]]*checksum\/|^[[:space:]]*[^[:space:]]+:/) {
            has_useful_annotations = 1;
            annotations_buffer = annotations_buffer $0 "\n";
        }
        prev_line = $0;
        next;
    }
    !in_annotations { 
        prev_line = $0;
        print $0; 
    }
    END {
        if (in_annotations && (has_useful_annotations || in_template_metadata)) {
            print annotations_start_line;
            printf "%s", annotations_buffer;
        }
    }
    '
}

# Ingress 전용 YAML 정리 함수 (애플리케이션 annotations 보존)
clean_yaml_ingress() {
    # 클러스터가 자동으로 추가하는 메타데이터만 제거
    sed '/^[[:space:]]*creationTimestamp:/d' | \
    sed '/^[[:space:]]*resourceVersion:/d' | \
    sed '/^[[:space:]]*uid:/d' | \
    sed '/^[[:space:]]*generation:/d' | \
    # status 섹션 제거
    sed '/^status:/,$d' | \
    # last-applied-configuration만 제거 (다른 annotations는 보존)
    awk '
    BEGIN { skip_config = 0 }
    /kubectl\.kubernetes\.io\/last-applied-configuration:/ { 
        skip_config = 1; 
        next 
    }
    skip_config && /^[[:space:]]*[^[:space:]]/ && !/^[[:space:]]+/ { 
        skip_config = 0; 
        print $0; 
        next 
    }
    skip_config && /^[^[:space:]]/ { 
        skip_config = 0; 
        print $0; 
        next 
    }
    !skip_config { print $0 }
    '
}

# Deployment 백업 (배포 가능한 깨끗한 버전)
echo "📦 Deployment 배포용 YAML 생성 중..."
kubectl get deploy -n $NS --no-headers -o custom-columns=":metadata.name" | while read -r DEPLOY; do
    if [ -n "$DEPLOY" ]; then
        BACKUP_FILE="${BASE_DIR}/deployments/${DEPLOY}.yaml"
        kubectl get deploy $DEPLOY -n $NS -o yaml | clean_yaml_common > "$BACKUP_FILE" && \
        echo "✅ Deployment 배포용 YAML 생성 성공: $BACKUP_FILE" || \
        echo "❌ Deployment 배포용 YAML 생성 실패: $DEPLOY"
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
            kubectl get svc $SVC -n $NS -o yaml | \
            clean_yaml_common | \
            # Service 특화: 클러스터가 자동으로 할당하는 필드들 제거
            sed '/^[[:space:]]*clusterIP:/d' | \
            sed '/^[[:space:]]*clusterIPs:/d' | \
            # externalIPs 제거 (spec 아래의 잘못된 항목들)
            awk '
            BEGIN { in_spec = 0 }
            /^spec:[[:space:]]*$/ { in_spec = 1; print $0; next }
            in_spec && /^[^[:space:]]/ { in_spec = 0 }
            in_spec && /^[[:space:]]*-[[:space:]]*[0-9]/ { next }
            in_spec && /^[[:space:]]*externalIPs:[[:space:]]*$/ { 
                while ((getline line) > 0 && line ~ /^[[:space:]]*-[[:space:]]*/) { }
                if (line !~ /^[[:space:]]*$/) print line
                next
            }
            { print $0 }
            ' > "$BACKUP_FILE" && \
               echo "✅ Service 배포용 YAML 생성 성공: $BACKUP_FILE" || \
               echo "❌ Service 배포용 YAML 생성 실패: $SVC"
        else
            echo "⏭️  Service 스킵 (Helm 관리): $SVC"
        fi
    fi
done

echo ""

# Ingress 백업 (배포 가능한 깨끗한 버전, 애플리케이션 annotations 보존)
echo "🌍 Ingress 배포용 YAML 생성 중..."
kubectl get ing -n $NS --no-headers -o custom-columns=":metadata.name" | while read -r ING; do
    if [ -n "$ING" ]; then
        BACKUP_FILE="${BASE_DIR}/ingress/${ING}.yaml"
        kubectl get ing $ING -n $NS -o yaml | clean_yaml_ingress > "$BACKUP_FILE" && \
        echo "✅ Ingress 배포용 YAML 생성 성공: $BACKUP_FILE" || \
        echo "❌ Ingress 배포용 YAML 생성 실패: $ING"
    fi
done

echo ""

# ConfigMap 백업 (배포 가능한 깨끗한 버전)
echo "🗂️  ConfigMap 배포용 YAML 생성 중..."
kubectl get cm -n $NS --no-headers -o custom-columns=":metadata.name" | while read -r CM; do
    if [ -n "$CM" ] && [ "$CM" != "kube-root-ca.crt" ]; then
        BACKUP_FILE="${BASE_DIR}/configmaps/${CM}.yaml"
        kubectl get cm $CM -n $NS -o yaml | clean_yaml_common > "$BACKUP_FILE" && \
        echo "✅ ConfigMap 배포용 YAML 생성 성공: $BACKUP_FILE" || \
        echo "❌ ConfigMap 배포용 YAML 생성 실패: $CM"
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
            kubectl get secret $SECRET -n $NS -o yaml | clean_yaml_common > "$BACKUP_FILE" && \
            echo "✅ Secret 배포용 YAML 생성 성공: $BACKUP_FILE" || \
            echo "❌ Secret 배포용 YAML 생성 실패: $SECRET"
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
        kubectl get rs $RS -n $NS -o yaml | clean_yaml_common > "$BACKUP_FILE" && \
        echo "✅ ReplicaSet 배포용 YAML 생성 성공: $BACKUP_FILE" || \
        echo "❌ ReplicaSet 배포용 YAML 생성 실패: $RS"
    fi
done

echo ""

# StatefulSet 백업 (원본 그대로 - cleaning 안함)
echo "🏛️  StatefulSet 배포용 YAML 생성 중..."
kubectl get sts -n $NS --no-headers -o custom-columns=":metadata.name" 2>/dev/null | while read -r STS; do
    if [ -n "$STS" ]; then
        BACKUP_FILE="${BASE_DIR}/statefulsets/${STS}.yaml"
        # StatefulSet은 복잡한 상태를 가지므로 기본적인 cleaning만 수행
        kubectl get sts $STS -n $NS -o yaml | \
        sed '/^[[:space:]]*creationTimestamp:/d' | \
        sed '/^[[:space:]]*resourceVersion:/d' | \
        sed '/^[[:space:]]*uid:/d' | \
        sed '/^[[:space:]]*generation:/d' | \
        sed '/^status:/,$d' > "$BACKUP_FILE" && \
        echo "✅ StatefulSet 배포용 YAML 생성 성공: $BACKUP_FILE" || \
        echo "❌ StatefulSet 배포용 YAML 생성 실패: $STS"
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
