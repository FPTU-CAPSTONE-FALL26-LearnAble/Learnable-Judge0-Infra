# Chứng chỉ Let's Encrypt và gia hạn

Chủ máy xác nhận đã cấp chứng chỉ thật cho `3.25.120.198`, Certbot báo hết hạn ngày 25/11/2026. HTTPS từ backend đã PASS languages có xác thực, accepted, wrong answer, compilation error và time limit. Đây là kết quả chủ máy cung cấp, Codex chưa đăng nhập EC2 để xác minh trực tiếp.

| Thành phần | Đường dẫn / tên |
| --- | --- |
| Certbot | /opt/certbot/bin/certbot |
| Certificate name | learnable-judge0-ip |
| Full chain gốc | /etc/letsencrypt/live/learnable-judge0-ip/fullchain.pem |
| Private key gốc | /etc/letsencrypt/live/learnable-judge0-ip/privkey.pem |
| Proxy certificate | /opt/learnable-judge0/secrets/tls/server.crt |
| Proxy private key | /opt/learnable-judge0/secrets/tls/server.key |
| Deploy hook trên EC2 | /etc/letsencrypt/renewal-hooks/deploy/learnable-judge0.sh |
| Timer / service | learnable-certbot.timer / learnable-certbot.service |

Giữ nguyên certificate đã cấp. Các file trong `renewal/` dùng để đối chiếu/cập nhật lịch và hook hiện có sau review. Không chạy cấp lại certificate hoặc helper self-signed trong quá trình này.

## Cấu hình hook

Review các unit và hook hiện có trước khi thay đổi. Backup các file cấu hình/hook hiện tại vào vị trí quản trị an toàn. Không sao chép private key vào repository hoặc output bàn giao.

Tạo `/etc/learnable-judge0/renewal.conf` từ `renewal/renewal.conf.example`, root-owned mode 0600. Điền REPO_DIR là đường dẫn tuyệt đối của checkout thực tế trên EC2 và giữ TLS_DIR khớp `.env`. Đặt COMPOSE_FILE trong `.env` nếu dùng override mạng API để mọi thao tác dùng cùng stack. Người có quyền sửa checkout/hook cũng có khả năng ảnh hưởng tác vụ root, cần giới hạn quyền sửa và review commit trước triển khai.

Sau khi đã review khác biệt và backup, cài hook và unit từ repository bằng quyền root. Đảm bảo file cấu hình đã có giá trị REPO_DIR đúng trước bật timer.

```sh
sudo install -m 0755 renewal/learnable-judge0.sh /etc/letsencrypt/renewal-hooks/deploy/learnable-judge0.sh
sudo install -m 0644 renewal/learnable-certbot.service /etc/systemd/system/learnable-certbot.service
sudo install -m 0644 renewal/learnable-certbot.timer /etc/systemd/system/learnable-certbot.timer
sudo systemctl daemon-reload
sudo systemctl enable --now learnable-certbot.timer
```

Service gọi `certbot renew --cert-name learnable-judge0-ip --quiet` rồi đối chiếu fullchain gốc với bản Nginx để phát hiện bản sao chưa cập nhật. Timer kiểm tra mỗi 6 giờ theo UTC, có random delay tối đa 15 phút và Persistent=true. Certbot quyết định lúc cần renew dựa vào renewal configuration/profile/ARI. Lịch kiểm tra thường xuyên phù hợp chứng chỉ IP có thời hạn ngắn.

Hook chỉ xử lý đúng lineage. Nó khóa các lần triển khai đồng thời, kiểm tra expiry, IP SAN và cặp public key, stage bản sao mới trong TLS_DIR, giữ bản cũ để rollback, xác minh mount TLS của Compose và chạy `nginx -t` trước reload. Nếu lỗi trước khi hoàn tất, nó phục hồi hai file certificate/key cũ và trả exit code lỗi. Nginx đang chạy giữ chứng chỉ trong bộ nhớ cho tới khi reload thành công. Hook yêu cầu hai file proxy hiện có là file thường. Kiểm tra thao tác thủ công nếu máy đang dùng symlink.

## Kiểm tra bắt buộc trên EC2

```sh
sudo /opt/certbot/bin/certbot --version
sudo systemctl is-enabled learnable-certbot.timer
sudo systemctl status learnable-certbot.timer --no-pager
sudo systemctl list-timers --all learnable-certbot.timer
sudo systemctl cat learnable-certbot.service learnable-certbot.timer
sudo /opt/certbot/bin/certbot renew --cert-name learnable-judge0-ip --dry-run
```

Dry-run mặc định kiểm tra xác thực/gia hạn với staging CA. Để kiểm tra deploy hook theo cơ chế Certbot, chạy thêm sau khi đã review hook và xác nhận proxy đang chạy.

```sh
sudo /opt/certbot/bin/certbot renew --cert-name learnable-judge0-ip --dry-run --run-deploy-hooks
sudo journalctl -u learnable-certbot.service --since '2 days ago' --no-pager
```

Với Certbot hỗ trợ cờ này, deploy hook trong dry-run dùng certificate active hiện tại, giữ staging certificate ngoài endpoint đang phục vụ. Kiểm tra tài liệu/version cài trên máy. Duy trì đường HTTP-01/DNS-01/standalone theo renewal configuration đang có. Không tự thay authenticator, mở port hoặc dừng proxy. Nếu HTTP-01 yêu cầu port 80, cần giữ challenge responder và security group tương ứng đã được review hoạt động cả lúc renew. Unit không tự tạo challenge server.

Từ backend xác minh TLS bằng system trust, gọi endpoint có token qua cơ chế secret hiện có và đối chiếu certificate đang phục vụ với bản gốc. Chỉ đọc thông tin certificate công khai khi kiểm tra.

```sh
openssl x509 -in /etc/letsencrypt/live/learnable-judge0-ip/fullchain.pem -noout -dates -fingerprint -sha256 -ext subjectAltName
openssl x509 -in /opt/learnable-judge0/secrets/tls/server.crt -noout -dates -fingerprint -sha256
```

Đối chiếu fingerprint này với leaf certificate quan sát từ backend. Ngày hết hạn 25/11/2026 là mốc chủ máy báo tại thời điểm bàn giao, cần lấy expiry mới sau mỗi lần renew. Theo dõi cảnh báo gia hạn và expiry, đặc biệt khi timer lỗi, IP thay đổi hoặc challenge bị chặn. Chưa xác nhận tự gia hạn đầy đủ cho tới khi có kết quả timer, dry-run và hook thực tế.

Nếu Certbot đã renew nhưng hook lỗi, service sẽ báo lỗi khi fullchain gốc khác bản proxy. Sau khi sửa nguyên nhân và xác nhận proxy đang chạy, có thể triển khai lại certificate active bằng hook, không yêu cầu cấp certificate mới.

```sh
sudo env RENEWED_LINEAGE=/etc/letsencrypt/live/learnable-judge0-ip /etc/letsencrypt/renewal-hooks/deploy/learnable-judge0.sh
```

[Certbot changelog chính thức về IP certificates và renewal hooks](https://github.com/certbot/certbot/blob/master/certbot/CHANGELOG.md)
