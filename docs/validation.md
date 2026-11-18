# Hồ sơ kiểm tra bộ triển khai

Ngày 2026-11-18. Các kiểm tra dưới đây do Codex chạy trong cloud session. Đây chưa phải nghiệm thu EC2.

| Kiểm tra | Kết quả |
| --- | --- |
| Registry image tags/digests và architecture | Các tag tồn tại, có amd64; Judge0 manifest đơn là amd64 |
| Render Compose bằng config thử ngoài repo | Qua; API bind 127.0.0.1, DB/Redis không publish port, data network internal |
| Privileged và resource budgets | Qua; chỉ API/worker privileged, mọi service có CPU/memory budget |
| Pin image | Qua; mọi image có tag rõ ràng và sha256 digest |
| Python/Bash syntax | Qua |
| Smoke client với HTTP stub cục bộ | Qua các nhánh auth/polling/verdict; dữ liệu mô phỏng, chưa kiểm tra engine |
| Sinh secret config | Qua; mode 0600, không in giá trị, từ chối ghi đè |
| Bộ lọc startup export | Qua với sentinel thử, dòng thường được giữ |
| Sinh TLS IP SAN | Qua; xác minh IP/trust bằng OpenSSL, từ chối ghi đè |
| Nginx nginx -t | Qua bằng image đã pin và chứng chỉ thử |
| PostgreSQL/Redis health | Qua bằng container cloud thử riêng |
| PostgreSQL dump/restore | Qua; custom dump và restore vào database thử riêng, marker còn nguyên |
| PostgreSQL/Redis restart | Qua; marker DB và Redis còn sau restart |
| Judge0 API/worker/sandbox | Chưa chạy; cloud dùng cgroups v2, release yêu cầu cấu hình v1 được review |
| Languages/token/submission/verdict/network/concurrency | Có script smoke, chưa chạy trên Judge0 thật |
| HTTPS kết nối backend thật | Chưa chạy, chưa cài chứng chỉ/trust trên EC2/backend |
| Kiểm tra lỗ hổng toàn bộ image | Chưa thực hiện; release notes đã đối chiếu, cần review advisory trước vận hành |

Container và volume thử do Codex tạo riêng trong cloud đã được dọn sau kiểm tra, có đối chiếu Compose project label. Không truy cập hoặc thay đổi volume EC2. Secret/certificate/dump thử nằm ngoài checkout và không được đưa vào Git.

Chủ máy báo host EC2 có Docker 29.10.0, Compose v5.8.0, cgroups v1, Docker/SSH active và hello-world thành công sau reboot qua Console. Chưa có bằng chứng trực tiếp từ Codex về architecture/RAM/disk, Judge0 hay dữ liệu trên host.

Chạy smoke localhost và HTTPS, lưu mapping language và kết quả verdict, network, hai job demo, rồi restart và chạy lại. Đồng thời xác minh token submission trước restart còn truy xuất được. Ghi giới hạn cuối và CPU/RAM/queue quan sát được. Giữ batch/callback tắt cho đến khi có nhu cầu và test riêng.

Chi phí AWS chưa được đọc. Bộ cấu hình dùng instance hiện có, disk hiện có và không khai báo provisioning. EC2 compute/EBS/public IPv4/data transfer vẫn tính theo cấu hình thực tế của tài khoản. Không tạo AWS resource hoặc mua domain trong session này. Chứng chỉ demo tự ký được tạo cục bộ và cần quản lý trust/expiry riêng.
