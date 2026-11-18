# Phương án triển khai chờ khảo sát EC2

Tài liệu dùng để review. Chưa chốt cấu hình thực thi hoặc áp dụng lên EC2.

Chủ máy xác nhận đã start lại `i-061bc0f7bc2e1dce2`. Cần xác nhận trạng thái/status checks, IP mới cùng đường SSH được cấp quyền trước khảo sát, không dùng lại IP cũ mặc định. EC2 compute và public IPv4 có thể phát sinh phí khi chạy, EBS có thể tiếp tục tính phí khi instance dừng.

## Release và điều kiện máy

Trang latest chính thức được kiểm tra ngày 2026-11-18 trỏ đến v1.13.1. Release này công bố bản vá CVE-2024-28185, CVE-2024-28189 và CVE-2024-29021. Cần kiểm tra thêm advisory và image thực tế trước triển khai.

Release khuyến nghị Ubuntu 22.04 và hướng dẫn cgroups v1 qua `systemd.unified_cgroup_hierarchy=0`, cập nhật GRUB rồi reboot. Phải kiểm tra OS, bootloader và cgroups hiện có trước khi đề xuất thay đổi. Reboot chỉ thực hiện sau khi duyệt thời gian gián đoạn và phương án truy cập lại.

Archive v1.13.1 pin `judge0/judge0:1.13.1`, PostgreSQL `16.2`, Redis `7.2.4`. Các phiên bản dependency trong archive là thông tin tham chiếu của release năm 2024. Cần đánh giá bản vá được hỗ trợ và tương thích trước khi chọn image triển khai hiện tại. Nếu đã có database, xác minh major version và backup trước khi chọn image, tránh gắn volume cũ vào major version mới.

Compose trong archive đặt `privileged` cho server và workers, giữ database và Redis không publish port. Compose trong source tag dùng tag image khác archive, vì vậy lấy archive phát hành làm mốc đối chiếu. Xác minh manifest kiến trúc trước khi pull image. EC2 ARM cần phương án image chính thức tương thích được chứng minh.

Nguồn chính thức

- [Release và deployment procedure v1.13.1](https://github.com/judge0/judge0/releases/tag/v1.13.1)
- [Archive triển khai v1.13.1](https://github.com/judge0/judge0/releases/download/v1.13.1/judge0-v1.13.1.zip)
- [Các tùy chọn cấu hình của release](https://github.com/judge0/judge0/blob/v1.13.1/judge0.conf)

## Kiến trúc dự kiến

Backend EC2 gọi reverse proxy HTTPS trên EC2 Judge0. Reverse proxy gọi API qua localhost. API và worker dùng PostgreSQL cùng Redis trong mạng Docker riêng. Frontend gọi backend và không giữ token Judge0.

- Giữ các thành phần trên instance hiện có để hạn chế chi phí.
- Ưu tiên reverse proxy hiện có trên host nếu phù hợp. Chọn proxy và chứng chỉ sau khi khảo sát port 80/443 và điều kiện HTTPS.
- Bind API `127.0.0.1:2358:2358`. Dùng một Compose hoàn chỉnh hoặc kiểm tra kỹ cấu hình merge để tránh giữ port public từ file gốc.
- PostgreSQL có volume bền vững. Redis cần quyết định persistence theo yêu cầu giữ queue và kiểm thử restart. Archive gốc tắt appendonly và không khai báo Redis volume.
- Tên Compose project và volume được chọn sau kiểm kê để tránh khởi tạo nhầm một bộ dữ liệu rỗng thay cho dữ liệu hiện có.
- Secret nằm ngoài checkout trên EC2 với quyền file phù hợp. Chỉ đưa placeholder và tên biến vào file example.
- API dùng `AUTHN_HEADER=X-Auth-Token` và token riêng. Giữ token trong header. Cấu hình log proxy tránh ghi token trong URL và log ứng dụng cần được kiểm tra trước bàn giao.
- Giới hạn truy cập HTTPS theo backend và quản trị thực tế. Giới hạn SSH theo đường quản trị đã xác minh, tránh tự khóa phiên truy cập.

## Giới hạn demo đề xuất

Các giá trị sau là điểm bắt đầu để review, chưa xác minh trên máy. Chốt container CPU/RAM sau khi biết dung lượng máy và ngân sách cho OS, PostgreSQL, Redis, API và compile job.

| Mục | Đề xuất ban đầu |
| --- | --- |
| Worker COUNT | 1 |
| MAX_QUEUE_SIZE | 20 |
| CPU_TIME_LIMIT và MAX_CPU_TIME_LIMIT | 2 giây |
| CPU_EXTRA_TIME và MAX_CPU_EXTRA_TIME | 0.5 giây |
| WALL_TIME_LIMIT và MAX_WALL_TIME_LIMIT | 5 giây |
| MEMORY_LIMIT và MAX_MEMORY_LIMIT | 128000 KB |
| MAX_PROCESSES_AND_OR_THREADS và mức tối đa | 32 |
| MAX_FILE_SIZE và MAX_MAX_FILE_SIZE | 1024 KB |
| NUMBER_OF_RUNS và MAX_NUMBER_OF_RUNS | 1 |
| ENABLE_NETWORK | false |
| ALLOW_ENABLE_NETWORK | false |
| Per-process time/memory override | Cấm bằng các cờ ALLOW tương ứng |
| Batch, callbacks, additional files | Đề xuất tắt cho demo ban đầu |

Giới hạn file sandbox cần kiểm thử riêng để xác minh ảnh hưởng lên stdout/stderr. Giới hạn HTTP request body dự kiến 256 KiB tại proxy cho input/source JSON, cần thống nhất với backend và cách base64 encoding. Java và một số runtime có thể cần điều chỉnh memory/process theo test thực tế. Không công bố hỗ trợ toàn bộ language trước kiểm thử.

Đề xuất polling bắt đầu sau 1 giây, tăng dần đến tối đa 3 giây với deadline 60 giây ở client. Đây là chính sách dự kiến. Rate limit và cách đếm job đồng thời phải được chốt cùng lưu lượng backend, một submission thường tương ứng một testcase cần chạy.

## Thay đổi và chi phí cần review trước áp dụng

- Có thể cần cài Docker/Compose chính thức, tải image, tạo file cấu hình/volume, cấu hình proxy và cập nhật firewall theo hiện trạng.
- Có thể cần reboot nếu cgroups hiện tại không tương thích. Cần thông báo gián đoạn và phương án quay lui.
- Image, log, backup và dữ liệu submission dùng dung lượng disk hiện có. Kiểm tra dung lượng trước pull hoặc backup.
- Chi phí EC2, EBS, public IPv4 và data transfer phụ thuộc tài nguyên thực tế cùng billing AWS. Chưa có dữ liệu để tính số tiền.
- Mọi nhu cầu tạo tài nguyên tính phí, đổi instance type, tăng disk, mở rộng dịch vụ hoặc mua domain phải được đồng ý rõ ràng.

## Điều kiện nghiệm thu và bàn giao

Sau triển khai cần kiểm tra readiness, languages, thiếu/sai token, tạo submission và polling đến kết thúc, accepted, wrong answer, compilation error, time limit, chặn network, mức đồng thời demo và restart giữ dữ liệu. Dùng test nhỏ an toàn, không thử thoát sandbox.

Tài liệu integration cuối sẽ lấy Base URL HTTPS, language ID và giới hạn từ deployment đã xác minh. Batch/callback chỉ ghi hỗ trợ khi có kiểm thử riêng. Tài liệu vận hành cần có start/stop/restart/log, queue và tài nguyên, backup/restore, retention, nâng cấp và rollback trước nghiệm thu.

## Bộ cấu hình đã chuẩn bị để review

Chủ máy báo host đã có Docker 29.10.0, Compose v5.8.0, cgroups v1 và hello-world thành công sau reboot qua Instance Connect. Bộ Compose hiện pin digest cho Judge0 CE 1.13.1, PostgreSQL 16.16-bookworm, Redis 7.2.17-bookworm và Nginx 1.30.6. Các dependency mới giữ cùng major/minor với archive, cần test tích hợp Judge0 trên EC2 trước nghiệm thu. Registry đã xác minh tag tồn tại và có amd64.

Runbook và integration đi kèm mô tả các giới hạn thực thi, resource budgets, secret, TLS IP SAN tự ký tùy chọn, backup/restore và rollback. Đây là lựa chọn chuẩn bị để review khi chưa có domain. Codex chưa áp dụng lên EC2. Cấu hình TLS/backend trust và security group cần review trước bật profile HTTPS.
