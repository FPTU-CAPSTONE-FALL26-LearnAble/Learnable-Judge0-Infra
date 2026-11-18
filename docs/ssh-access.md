# Khảo sát qua SSH từ máy quản trị

Chủ máy xác nhận instance `i-061bc0f7bc2e1dce2` ở Sydney đang Running, IP `3.25.120.198`, status checks 3/3 đạt. Security group `sg-0901437459d870153` chỉ cho SSH từ `171.252.249.65/32`. Status checks chưa xác nhận sshd hoạt động.

Cloud session chưa được cấp private key hoặc SSH agent và chưa xác minh được đường SSH được cho phép. Phương án hiện tại là chạy khảo sát từ máy quản trị có private key tương ứng, đang đi ra Internet qua IP được rule cho phép. Dùng bản repository có các file mới của session này trên máy quản trị. Bộ triển khai sẽ được bàn giao bằng branch/commit trên GitHub. Checkout đúng commit đã bàn giao trước khi khảo sát hoặc triển khai.

## Xác minh và kết nối

Các lệnh sau dành cho Bash/OpenSSH trên máy quản trị. Thay đường dẫn ví dụ bằng file khóa thật trên máy đó. Giữ khóa ngoài checkout và không chia sẻ nội dung khóa.

```sh
ssh -i '/duong-dan-an-toan/learnable-kp.pem' \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=ask \
  -o ConnectTimeout=10 \
  ubuntu@3.25.120.198
```

Trước khi chấp nhận host key lần đầu, đối chiếu fingerprint qua kênh tin cậy, chẳng hạn EC2 system log nếu có fingerprint từ lúc khởi tạo. Nếu host key thay đổi, xác minh nguyên nhân trước khi cập nhật known_hosts. Kết thúc phiên bằng `exit` sau khi xác nhận đúng máy.

## Chạy khảo sát chỉ đọc

Từ thư mục repository trên máy quản trị, chạy lệnh sau sau khi đã xác minh và lưu host key. File output có thông tin hạ tầng, cần xem trước khi chia sẻ.

```sh
mkdir -p artifacts
chmod 700 artifacts
umask 077
ssh -i '/duong-dan-an-toan/learnable-kp.pem' \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=yes \
  -o ConnectTimeout=10 \
  ubuntu@3.25.120.198 'bash -s' \
  < scripts/inspect-host.sh > artifacts/ec2-inspection.txt 2>&1
```

Nếu Docker daemon báo thiếu quyền và tài khoản ubuntu có quyền sudo phù hợp, chạy lại cùng lệnh với remote command `sudo -n bash -s`. Không thay quyền Docker socket hoặc thêm quyền quản trị để vượt lỗi mặc định. Script chỉ khảo sát, không cài đặt, restart hoặc xóa dữ liệu. Không chạy các lệnh này trong cloud session đang thiếu khóa và đường mạng.

Kiểm tra exit code ngay sau lệnh SSH bằng `echo $?`, rồi đọc `artifacts/ec2-inspection.txt` trước khi gửi kết quả khảo sát. File này nằm trong đường dẫn Git ignore. Báo cả lỗi hoặc phần bị thiếu để phân biệt khảo sát đầy đủ với khảo sát một phần.

## Nếu chưa kết nối được

Kiểm tra máy quản trị thực sự có public IP nguồn được rule cho phép, IP đích còn đúng và private key tương ứng với tài khoản ubuntu. Lỗi timeout/refused cần kiểm tra đường mạng và sshd bằng quyền quản trị hiện có. Lỗi publickey cần kiểm tra đúng key/user và authorized_keys qua đường truy cập được cấp. Không suy ra sshd đã hỏng chỉ từ một lần kết nối thất bại từ cloud session.

Nếu chuyển sang SSH trực tiếp từ cloud session, cần cấp khóa/agent qua cơ chế bảo mật và xác minh egress SSH trước khi đề xuất rule source cụ thể. Mọi thay đổi security group cần được review theo phạm vi đã thống nhất.
