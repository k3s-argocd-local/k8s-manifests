import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 10,            // 10명의 가상 유저가
  duration: '270s',   // 4분 30초 동안 지속해서 요청을 보냄
};

export default function () {
  // AWS EC2의 공인 IP와 백엔드 서버 포트를 입력
  const url = 'http://13.209.68.215:30080/api/delay';
  
  const res = http.get(url);

  // 응답이 200 OK인지 검증
  check(res, {
    'status is 200': (r) => r.status === 200,
  });

  // 응답을 받은 후 가상 유저가 0.5초간 대기 후 다음 요청 진행 (서버 과부하 방지)
  sleep(0.5);
}