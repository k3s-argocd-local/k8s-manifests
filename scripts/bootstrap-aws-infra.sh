#!/usr/bin/env bash
# 스크립트가 실행될 때 bash 쉘 환경을 사용하겠다는 선언입니다.

set -euo pipefail
# 실행 중 에러 발생 시 즉시 중단시키는 안전장치 설정입니다.

# [AWS 핵심 변경점] 로컬 k3d(도커 위 가상 클러스터) 대신, AWS EC2 가상 서버 자체에 
# 가볍고 강력한 경량화 쿠버네티스인 'K3s'를 직접 다운로드하여 설치합니다.
# 기본 내장 인그레스(Traefik)는 비활성화 처리하며, 8081 포트 사용을 위해 NodePort 서비스 포트 범위를 전체(1-65535)로 확장합니다.
curl -sfL https://get.k3s.io | sh -s - --disable=traefik --kube-apiserver-arg="service-node-port-range=1-65535"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
# K3s 서버가 실행된 후, 관리자 명령어(kubectl)가 인증 에러 없이 
# 쿠버네티스 엔진과 바로 통신할 수 있도록 설정 파일의 권한과 경로를 환경 변수에 바인딩합니다.

# ---- 선언형 엔진 로직 시작 ----

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
# 'argocd'라는 독립된 시스템 작업 공간(네임스페이스)을 생성합니다.

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# ArgoCD 공식 원격 저장소에서 검증된 설치 파일을 가져와 클러스터 내부에 배포합니다.

kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
# ArgoCD의 메인 웹 서버 엔진 파드가 완전히 정상 구동될 때까지 최대 300초간 대기합니다.

kubectl -n argocd wait --for=jsonpath='{.metadata.name}' secret/argocd-initial-admin-secret --timeout=60s
# AWS EC2 환경에서 리소스 생성 지연으로 인해 초기 비밀번호 시크릿을 찾지 못하는 문제를 방지하기 위해 
# 시크릿 오브젝트가 물리적으로 생성 완료될 때까지 안전하게 대기합니다.

echo "ArgoCD admin initial password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
# 암호화되어 있는 ArgoCD 초기 관리자 비밀번호를 복호화(Base64 Decode)하여 터미널 화면에 출력합니다.
echo
# 가독성을 위한 줄바꿈 처리입니다.

# [네트워크 노출 설정 추가] ClusterIP로 설정된 argocd-server 서비스를 NodePort 타입으로 변경하고 외부 포트를 8081로 고정 매핑합니다.
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"name": "http", "port": 80, "targetPort": 8080, "nodePort": 8081}, {"name": "https", "port": 443, "targetPort": 8080, "nodePort": 8082}]}}'

echo "================================================================"
echo "[안내] AWS 클라우드 인프라 셋업이 성공적으로 완료되었습니다."
echo "1. AWS 웹 콘솔 -> EC2 인바운드 보안 그룹에서 아래 포트를 반드시 열어주세요."
echo "   - 8081 (ArgoCD 웹 UI 접근용)"
echo "   - 30080 (스프링부트 자바 API 서버 접근용)"
echo "2. 외부 접속 시 포트 포워딩 명령어가 더 이상 필요하지 않습니다."
echo "   - 접속 주소: https://<당신의-AWS-EC2-공인IP>:8081"
echo "================================================================"