#!/bin/bash

NS=test
BACKUP_DIR="helm"

mkdir -p $BACKUP_DIR

echo "=== 네임스페이스 $NS 의 설치된 릴리스 목록 ==="
helm list -n $NS

echo ""
echo "=== Helm 릴리스 values 백업 시작 ==="

helm list -n $NS --short | while read -r RELEASE; do
    if [ -n "$RELEASE" ]; then
        echo "백업 중: $RELEASE"
        BACKUP_FILE="${BACKUP_DIR}/${NS}-${RELEASE}-values.yaml"
        
        # values 백업
        if helm get values $RELEASE -n $NS -o yaml > $BACKUP_FILE; then
            echo "✅ 성공: $BACKUP_FILE"
        else
            echo "❌ 실패: $RELEASE 값 백업 실패"
        fi
        echo ""
    fi
done

echo "=== 백업 완료 ==="
echo "생성된 파일들:"
ls -la ${BACKUP_DIR}/${NS}-*-values.yaml 2>/dev/null || echo "백업된 파일이 없습니다."