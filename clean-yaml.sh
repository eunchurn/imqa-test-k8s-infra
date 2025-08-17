#!/bin/bash

# 배포용 YAML 파일들을 더 깨끗하게 정리하는 스크립트
CLEAN_DIR="deployments-clean"

echo "=== 배포용 YAML 파일 후처리 시작 ==="

# 각 YAML 파일을 정리
for file in ${CLEAN_DIR}/*.yaml; do
    if [ -f "$file" ]; then
        echo "정리 중: $(basename $file)"
        
        # 임시 파일 생성
        temp_file=$(mktemp)
        
        # 불필요한 라인들 제거
        grep -v -E "(- [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|externalTrafficPolicy|internalTrafficPolicy|ipFamilies|ipFamilyPolicy)" "$file" | \
        sed '/^  annotations:/,/^  [^ ]/{ /^  [^ ]/!d; }' | \
        sed '/kubectl.kubernetes.io\/last-applied-configuration/d' > "$temp_file"
        
        # 원본 파일 교체
        mv "$temp_file" "$file"
        
        echo "✅ 정리 완료: $(basename $file)"
    fi
done

echo ""
echo "=== 후처리 완료 ==="
echo "이제 다음 명령으로 배포할 수 있습니다:"
echo "kubectl apply -f ${CLEAN_DIR}/"
