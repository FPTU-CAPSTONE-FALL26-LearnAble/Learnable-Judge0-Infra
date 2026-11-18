# Hiện trạng khảo sát

Ngày ghi nhận 2026-11-18. Đây là kết quả từ cloud session, chưa phải kết quả khảo sát EC2.

## Thông tin do chủ máy cung cấp

| Mục | Giá trị |
| --- | --- |
| Instance name | learnable-judge0-demo |
| Instance ID | i-061bc0f7bc2e1dce2 |
| Region | ap-southeast-2 |
| Trạng thái theo chủ máy | Running, status checks 3/3 đạt theo chủ máy |
| Security group | sg-0901437459d870153 |
| Inbound SSH | TCP 22 từ 171.252.249.65/32 |
| IAM role | Chưa gắn |
| SSH user | ubuntu |
| EC2 key pair name | learnable-kp |
| Public IPv4 hiện tại | 3.25.120.198, theo xác nhận của chủ máy |
| Public IP cũ | 54.206.145.128, hết hiệu lực, không dùng để kết nối |
| Private IP | 10.0.2.25 |
| Domain/HTTPS | Chưa cấu hình |
| SSM | Chưa thiết lập IAM role cần thiết theo thông tin chủ máy |

## Kết quả thực sự đã kiểm tra

- Checkout không có commit, file dự án hoặc AGENTS.md tại thời điểm bắt đầu. Origin không quảng bá branch trong lần kiểm tra trước.
- Cloud session không có thư mục SSH mặc định, SSH agent sử dụng được hoặc profile trong các file AWS config/credentials được inject. Chỉ kiểm tra tên và trạng thái, không đọc giá trị secret ra output.
- Cloud environment metadata không khai báo secret, runtime variable hoặc outbound identity.
- Lần thử TCP trước đây đến IP cũ nhận `Connection refused`. Chủ máy sau đó xác nhận instance đang Stopped và IP đó đã hết hiệu lực. Kết quả này không dùng để chẩn đoán SSH của instance. Dừng sử dụng IP cũ.
- Đã đọc release page v1.13.1, source config và Compose trong archive phát hành chính thức.
- Script `scripts/inspect-host.sh` đã vượt kiểm tra cú pháp Bash và chạy hoàn tất trên cloud session. Lần chạy này xác nhận script hoạt động với môi trường cloud đang dùng, chưa xác minh nhánh khảo sát mount/container vì cloud không có container. Toàn bộ kiểm thử EC2 và submission vẫn đang chờ.

Chưa thử xác thực SSH vì session chưa được cấp khóa. Chưa kiểm tra OS, architecture, RAM, disk, cgroups, Docker, container, volume, firewall, security group hoặc dữ liệu trên EC2. Chưa tạo tài nguyên AWS hoặc chạy lệnh thay đổi trên EC2.

## Thông tin cần bổ sung qua kênh phù hợp

1. Đã nhận xác nhận từ chủ máy về Running, IP mới và status checks 3/3. Cần kết quả khảo sát bên trong máy qua kết nối SSH được cấp quyền.
2. Chủ máy xác nhận chưa cấp khóa hoặc SSH agent cho session. Có thể khảo sát từ máy quản trị đang được security group cho phép theo docs/ssh-access.md.
3. Fingerprint SSH host key qua kênh tin cậy trước lần đăng nhập đầu.
4. Security group chỉ cho SSH từ 171.252.249.65/32. Chưa xác minh IP outbound session, không suy luận đường SSH đã được cho phép.
5. Domain sẵn có hoặc phương án HTTPS được chấp thuận.

Không đưa private key, mật khẩu hoặc OTP vào chat, Git hoặc output khảo sát. Không mở SSH toàn Internet để xử lý sự cố mặc định.

## Cập nhật sau khi chủ máy start instance

Chủ máy xác nhận đã start lại instance ngày 2026-11-18. Session kiểm tra lại và vẫn chưa có thư mục SSH mặc định, SSH agent hoặc AWS profile được cấp. Chủ máy sau đó cung cấp IP mới `3.25.120.198` và trạng thái Running. Thử TCP trực tiếp đến IP mới trên cổng 22 nhận `Connection refused` từ đường kết nối của session. Chưa xác định lỗi ở egress của session, đường mạng hay SSH trên máy đích. Kết quả chưa xác thực danh tính máy. Chủ máy sau đó xác nhận status checks 3/3 đạt, security group sg-0901437459d870153 chỉ cho TCP 22 từ 171.252.249.65/32. Chưa xác minh sshd bên trong máy. Chưa chạy lệnh trên EC2.

## Chuẩn bị host qua EC2 Instance Connect

Chủ máy báo Docker 29.10.0, Compose v5.8.0, cgroups v1, Docker/SSH active và hello-world thành công sau reboot. Codex chưa xác minh trực tiếp hoặc kiểm thử Judge0. EC2 Instance Connect trong Console không cấp private key/agent cho cloud session. Architecture, RAM/disk, phiên bản Judge0 hiện có và dữ liệu cần giữ vẫn cần output khảo sát. Chủ máy yêu cầu commit/push bộ triển khai không chứa secret để tiếp tục review và triển khai.

## Chứng chỉ và kiểm thử từ backend theo chủ máy

Chủ máy xác nhận đã có Let's Encrypt IP certificate tại lineage `learnable-judge0-ip` cho 3.25.120.198, expiry được báo 25/11/2026. Proxy dùng bản sao server.crt/server.key trong TLS_DIR. Authenticated languages, accepted, wrong answer, compilation error và time limit đã PASS từ backend qua HTTPS theo báo cáo chủ máy. Timer và renew --dry-run còn cần kiểm tra, Codex chưa xác minh trực tiếp hoặc đọc private key.
