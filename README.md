# k8s-manifests

k3s 클러스터 환경의 선언적 인프라 관리를 위한 GitOps 배포 매니페스트 저장소입니다.  
ArgoCD를 통해 클러스터 상태와 지속적으로 동기화(Sync)됩니다.

## 🛡️ 무중단 배포를 위한 Deployment 핵심 명세
- **RollingUpdate 전략 채택**
  - `maxSurge: 1` / `maxUnavailable: 0` 설정을 통해 배포 전환 중에도 최소 가용 파드 개수를 엄격히 유지하여 서비스 단절을 방지합니다.
- **Readiness Probe (`[GET /api/health]`)**
  - 새 파드가 구동된 후 스프링 부트 애플리케이션이 완벽히 초기화되어 트래픽을 처리할 수 있는 상태인지 검증 후 라우팅(Endpoints)에 투입합니다.
- **PreStop Lifecycle Hook (`sleep 10`)**
  - 구버전 파드가 종료 절차에 들어갈 때, 인프라 라우팅에서 먼저 격리될 수 있도록 10초간 배포 대기 시간을 부여하여 전환기 잔여 요청의 유실을 차단합니다.
- **유예 시간 정합성**
  - `terminationGracePeriodSeconds: 40`으로 설정하여 Infrastructure 대기(10s)와 Application Graceful Shutdown 유예(30s) 시간의 물리적 타이밍을 일치시켰습니다.
