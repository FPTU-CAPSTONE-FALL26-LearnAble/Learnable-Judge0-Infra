# LearnAble Judge0 infrastructure

Repository quản lý triển khai Judge0 CE trên EC2 `learnable-judge0-demo`, region `ap-southeast-2`.

Instance ID `i-061bc0f7bc2e1dce2`. Chủ máy xác nhận đã start lại instance ngày 2026-11-18. Chủ máy cung cấp Public IPv4 mới `3.25.120.198`, trạng thái Running. Chủ máy xác nhận status checks 3/3 đạt. Session chưa có quyền truy cập SSH. IP cũ đã hết hiệu lực.

Hiện tại đang ở bước khảo sát và review phương án. Chưa đăng nhập được EC2, chưa triển khai Judge0, chưa xác minh dữ liệu hoặc chạy kiểm thử submission.

- [Phương án cần review](docs/deployment-review.md)
- [Trạng thái khảo sát](docs/discovery.md)
- [Khảo sát qua máy quản trị có SSH](docs/ssh-access.md)
- Script khảo sát chỉ đọc tại `scripts/inspect-host.sh`.

Chạy script trên đúng EC2 sau khi xác minh SSH host key bằng nguồn tin cậy. Script không cài đặt hoặc thay đổi dịch vụ. Xem output trước khi chia sẻ vì có thông tin hạ tầng nội bộ.

```sh
bash scripts/inspect-host.sh
```

## Bộ triển khai để review

Compose pin tag và digest cho Judge0 CE 1.13.1, PostgreSQL 16.16-bookworm, Redis 7.2.17-bookworm và Nginx 1.30.6. Registry xác nhận image Judge0 là amd64. API bind localhost, database/Redis ở mạng internal, Redis có AOF và volume riêng. Một worker xử lý job. Chỉ server và worker privileged theo release.

- [Runbook cài mới, HTTPS, kiểm thử và vận hành](docs/operations.md)
- [Hợp đồng integration cho backend](docs/integration.md)
- [Các kiểm tra đã chạy và phần còn chờ](docs/validation.md)

Chủ máy báo Docker 29.10.0, Compose v5.8.0, cgroups v1, Docker/SSH active và hello-world thành công sau reboot qua EC2 Instance Connect. Codex chưa xác minh architecture, RAM/disk, dữ liệu hay submission trên EC2.

HTTPS là profile tùy chọn dùng chứng chỉ IP SAN tự ký cho demo, backend cần trust certificate riêng. Chưa có endpoint HTTPS được nghiệm thu. Chạy preflight và review volume names/tài nguyên trước `up`. Secret thật được tạo ngoài checkout. Wrapper lọc dòng export mà startup upstream có thể in secret ra log.
