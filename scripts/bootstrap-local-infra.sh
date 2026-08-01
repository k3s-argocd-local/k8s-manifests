#!/usr/bin/env bash
# 스크립트가 실행될 때 bash 쉘 환경을 사용하겠다는 선언입니다.

set -euo pipefail
# 스크립트 실행 중 에러(-e), 선언되지 않은 변수(-u), 파이프라인 에러(-o pipefail)가 발생하면 즉시 실행을 중단시키는 안전장치 설정입니다.

CLUSTER_NAME="${CLUSTER_NAME:-local-cicd}"
# 환경변수에 CLUSTER_NAME이 지정되어 있지 않다면 기본값으로 'local-cicd'라는 이름을 사용합니다.

# k3d를 사용하여 로컬 쿠버네티스 클러스터를 생성하는 명령입니다.
k3d cluster create "${CLUSTER_NAME}" \
  --servers 1 \
  --agents 2 \
  --port "8080:30080@server:0" \
  --port "8443:443@loadbalancer" \
  --k3s-arg "--disable=traefik@server:*"
# --servers 1 / --agents 2: 마스터 노드 1개와 워커 노드 2개를 생성합니다.
# --port "8080:30080@server:0": 호스트 PC의 8080 포트를 쿠버네티스 노드포트 30080 포트와 연결합니다.
# --port "8443:443@loadbalancer": 로드밸런서용 포트를 바인딩합니다.
# --k3s-arg "--disable=traefik...": k3s에 내장된 기본 인그레스 컨트롤러(Traefik)를 비활성화합니다.

kubectl config use-context "k3d-${CLUSTER_NAME}"
# 방금 생성한 k3d 클러스터로 kubectl 명령어가 전달되도록 작업 컨텍스트(Target 클러스터)를 전환합니다.

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
# 'argocd'라는 네임스페이스(독립된 작업 공간)가 존재하지 않으면 새로 생성하고, 이미 있으면 에러 없이 넘어갑니다.

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# ArgoCD 공식 원격 저장소에서 설치 매니페스트 파일을 다운로드하여 argocd 네임스페이스에 설치합니다.

kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
# ArgoCD 웹 서버(Deployment)의 모든 파드가 완전히 정상 구동될 때까지 최대 300초 동안 대기합니다.

# [추가된 안전장치] 초기 비밀번호가 담긴 시크릿(Secret) 리소스가 쿠버네티스 내부에 물리적으로 생성 완료될 때까지 최대 60초간 대기합니다.
kubectl -n argocd wait --for=jsonpath='{.metadata.name}' secret/argocd-initial-admin-secret --timeout=60s

echo "ArgoCD admin initial password:"
# 화면에 비밀번호 안내 문구를 출력합니다.

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
# ArgoCD 초기 관리자 비밀번호가 저장된 시크릿을 조회한 뒤, 암호화(Base64)된 문자열을 사람이 읽을 수 있도록 복호화하여 화면에 출력합니다.
echo
# 가독성을 위해 한 줄 개행(줄바꿈)을 처리합니다.

echo "Run this in another terminal to open ArgoCD locally:"
echo "kubectl -n argocd port-forward svc/argocd-server 8081:443"
# 사용자가 로컬 브라우저에서 ArgoCD UI에 접속할 수 있도록 포트 포워딩 명령어를 안내합니다.

echo "After syncing the app, call the API at: http://localhost:8080/api/version"
# 배포가 완전히 끝난 후 애플리케이션 버전을 테스트해 볼 수 있는 최종 curl 주소를 안내합니다.