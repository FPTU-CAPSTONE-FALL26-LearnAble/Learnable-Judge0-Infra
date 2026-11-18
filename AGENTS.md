# Phạm vi và quy tắc vận hành

- Chỉ quản lý hạ tầng Judge0 trong repository này. Giữ nghiệp vụ thi trong repository backend.
- Mỗi cloud task đã có môi trường riêng. Dùng checkout hiện có, chỉ tạo Git worktree khi người dùng yêu cầu.
- Trước thay đổi EC2, đọc tài liệu hiện trạng, khảo sát container, volume, OS, CPU architecture, RAM, disk, Docker/Compose và cgroups.
- Trình cấu hình triển khai và tác động trước khi áp dụng lên EC2. Reboot, thay đổi cgroups, security group và di chuyển dữ liệu phải nằm trong phương án được duyệt.
- Cần đồng ý rõ ràng trước khi tạo tài nguyên tính phí, đổi instance type, tăng disk, mở rộng dịch vụ hoặc mua domain.
- Bảo toàn cấu hình và dữ liệu có sẵn. Backup và xác minh khả năng phục hồi trước migration. Tránh `docker compose down -v`, volume prune và thao tác xóa dữ liệu mặc định.
- Dùng image/release Judge0 chính thức, pin phiên bản rõ ràng, xác minh architecture và bản vá. Đọc hướng dẫn đúng release và kiểm tra archive phát hành vì Compose trong source tag có thể khác archive.
- Giữ TLS, chữ ký và checksum verification khi tải hoặc cài đặt. Không tắt sandbox để vượt kiểm thử.
- Chỉ cấp privileged cho dịch vụ được tài liệu release yêu cầu và đã review.
- Giữ database/Redis trong mạng nội bộ. Render và kiểm tra Compose ports trước khi triển khai. Judge0 bind localhost, public qua reverse proxy HTTPS có xác thực.
- Secret thật ở ngoài Git. Không in file secret, process environment, Compose đã nội suy secret, Docker inspect đầy đủ hoặc log chưa được kiểm tra vào bàn giao.
- Khóa SSH được cấp qua cơ chế bảo mật. Giữ kiểm tra SSH host key, đối chiếu fingerprint qua kênh tin cậy.
- Ghi rõ máy nào đã được kiểm tra. Kiểm thử trên cloud task không xác nhận kết quả EC2.
- Chỉ ghi mapping language, Base URL và kết quả test là đã xác minh khi có bằng chứng trên endpoint triển khai. Batch/callback cần kiểm thử riêng.
