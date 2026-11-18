# Vận hành Judge0 CE demo

Hướng dẫn dành cho quản trị viên trên EC2. Codex chưa chạy các bước triển khai trên EC2. Review cấu hình trước khi áp dụng, dùng checkout hiện có.

## Điều kiện trước triển khai

Đọc AGENTS.md và chạy `bash scripts/inspect-host.sh`. Xác minh amd64, cgroups v1, CPU/RAM/disk, container/mount và dữ liệu cần giữ. Chủ máy mới báo Docker/Compose, cgroups v1 và hello-world thành công.

Ngân sách container mặc định khoảng 1,8 GiB cộng proxy 64 MiB, chưa gồm OS/cache và chi phí sandbox. Khuyến nghị ít nhất 3 GiB RAM để review cấu hình mặc định. Máy nhỏ hơn cần điều chỉnh có kiểm thử. Judge0 có khoảng 3,3 GB layer nén, cần dự trù dung lượng giải nén, image cũ, submission và backup. Ưu tiên ít nhất 15 GiB trống trước lần pull đầu rồi đo thực tế. Kiểm tra Docker root directory bằng `docker info --format '{{.DockerRootDir}}'`. Không tự tăng disk hoặc đổi instance type.

Host hiện có Docker 29.10.0 và Compose v5.8.0 theo chủ máy. Nếu cài máy khác, làm theo tài liệu Docker Engine Ubuntu và Compose plugin chính thức, giữ signature/TLS verification. Không cần cài lại host hiện có mặc định.

[Docker Engine Ubuntu](https://docs.docker.com/engine/install/ubuntu/) và [Compose plugin](https://docs.docker.com/compose/install/linux/).

Trước `up`, kiểm tra tên volume trong `.env`. Tên mặc định dành cho cài mới. Với dữ liệu cũ phải giữ đúng tên volume và kiểm tra PostgreSQL major version. Không gắn volume major cũ trực tiếp vào PostgreSQL 16. Startup server sẽ chạy migration/seed theo release nên cần backup trước nâng cấp.

## Secret và khởi động

Từ root repository, tạo bộ secret mới khi đã xác định cài mới. Script từ chối ghi đè file có sẵn.

```sh
cp -n .env.example .env
sudo python3 scripts/init-config.py /opt/learnable-judge0/secrets/judge0.conf
sudo chown 1000:1000 /opt/learnable-judge0/secrets/judge0.conf
sudo bash scripts/preflight.sh
sudo docker compose config --quiet
sudo docker compose pull
sudo docker compose up -d --wait --wait-timeout 240 db redis server workers
sudo docker compose ps
```

UID 1000 là user judge0 của image. Config mode 0600 cho phép user đó đọc bind mount, Docker daemon root truy cập đường dẫn cha. Người chạy Compose cần quyền đọc env_file, các lệnh dùng sudo nhất quán. Nếu có config sẵn, bảo toàn và đối chiếu policy thay vì tạo lại.

Script tạo AUTHN_TOKEN, AUTHZ_TOKEN, SECRET_KEY_BASE, mật khẩu PostgreSQL/Redis ngẫu nhiên. Chuyển riêng AUTHN_TOKEN cho backend qua kênh bảo mật. AUTHZ_TOKEN dành cho quản trị. Theo cơ chế release, env_file chung đưa cả biến khác vào database/Redis, Docker administrators có quyền tiếp cận secret. Không dump environment/inspect/config đã render. Đổi file mật khẩu không đổi password của PostgreSQL đã khởi tạo, rotation cần cập nhật database và các bên đồng bộ trong maintenance window.

Healthcheck kiểm tra PostgreSQL, Redis và API có xác thực. Worker readiness cần submission kết thúc. Nếu sandbox/cgroups hoặc OOM lỗi, chẩn đoán và điều chỉnh theo release, giữ sandbox hoạt động.

## Override mạng API

Nếu API cần routed bridge cho đường truy cập qua port localhost, dùng file `docker-compose.api-network.yml`. Ghi lựa chọn vào `.env` trên host để các script và renewal hook cùng dùng cấu hình đó.

```dotenv
COMPOSE_FILE=docker-compose.yml:docker-compose.api-network.yml
```

Override chỉ thêm mạng `api` cho server, giữ mạng `data` internal, port `127.0.0.1:2358`, network của worker và các cờ sandbox. Database/Redis giữ mạng internal và không publish port. API có thêm khả năng egress qua bridge này, cần review theo policy vận hành.

Sau khi review cấu hình render bằng công cụ riêng tư, kiểm tra và cập nhật riêng server trong thời gian cho phép gián đoạn API.

```sh
sudo docker compose config --quiet
sudo docker compose up -d --no-deps --wait --wait-timeout 240 server
sudo docker compose ps
```

Lệnh không yêu cầu xóa volume hoặc recreate database/Redis. Chạy lại auth và submission qua localhost/HTTPS sau cập nhật. Khi quay lui override, bỏ COMPOSE_FILE bổ sung trong `.env` và recreate server theo cách trên, giữ nguyên volume names.

## HTTPS khi chưa có domain

Chủ máy đã cấp chứng chỉ Let's Encrypt thật cho IP `3.25.120.198` và đặt bản Nginx sử dụng tại TLS_DIR. Giữ nguyên hai file `server.crt`/`server.key` đang có. Các kiểm thử HTTPS từ backend đã PASS theo báo cáo chủ máy. Review và kiểm tra gia hạn theo tài liệu riêng trước khi xác nhận tự gia hạn hoạt động đầy đủ.

```sh
sudo docker compose --profile https run --rm --no-deps proxy nginx -t
sudo docker compose --profile https up -d proxy
```

Proxy dùng Linux host network để gọi API localhost và listen 443. Kiểm tra xung đột port trước startup. Review security group TCP 443 từ backend và nguồn quản trị thực tế. Giữ SSH theo IP quản trị, giữ 2358/5432/6379 ngoài inbound public. Challenge cho gia hạn cần giữ đường mạng tương ứng với authenticator thực tế. Mọi thay đổi security group cần nằm trong phương án được duyệt.

Backend dùng system CA trust để xác minh Let's Encrypt và IP SAN. Private key ở Judge0 host. Khi IP đổi cần review certificate và Base URL. Đường dẫn Certbot, deploy hook, timer và lệnh dry-run có trong [hướng dẫn gia hạn](certificate-renewal.md).

## Kiểm thử thực tế

Chạy trên EC2. Lấy DB IP và xác nhận DB reachable từ worker trước test network để tránh kết luận do đích vốn bị chặn.

```sh
DB_IP=$(sudo docker compose exec -T workers getent ahostsv4 db | awk 'NR==1 {print $1}')
sudo docker compose exec -T workers ruby -rsocket -e 'TCPSocket.new(ARGV[0],5432).close' "$DB_IP"
sudo python3 scripts/smoke.py --config /opt/learnable-judge0/secrets/judge0.conf --network-target "$DB_IP"
```

Script kiểm tra thiếu/sai token, languages thực tế, accepted, wrong answer, compilation error, timeout, chặn nâng CPU/network, chặn kết nối sandbox tới DB và hai submission gửi đồng thời để kiểm tra queue với một worker. Network probe chỉ mở rồi đóng TCP, không gửi lệnh hoặc đăng nhập DB. Theo dõi `docker stats` và queue khi chạy. Hai job là kiểm thử demo nhỏ, chưa xác định năng lực chịu tải.

Với Let's Encrypt, chạy lại cùng script thêm `--url https://3.25.120.198`, dùng system CA trust. Script không in secret hoặc source/output job, có in languages và PASS. Polling chỉ yêu cầu `fields=status` để tránh đọc output không cần thiết trước verdict. Batch/callback bị tắt.

## Điều khiển và giám sát

```sh
sudo docker compose start
sudo docker compose stop
sudo docker compose restart
sudo docker compose ps
sudo docker compose logs --tail 100 server workers
sudo docker stats --no-stream
sudo docker system df
```

Thêm `--profile https` khi thao tác proxy. Stop/restart giữ volume. `down` gỡ container/network và gây gián đoạn, named volume vẫn còn khi không có `-v`. Tránh `down -v`, volume prune hoặc xóa dữ liệu mặc định. Trước maintenance, dừng nhận job mới và chờ queue/processing kết thúc. Sau restart lấy DB_IP mới, chạy lại smoke và xác minh một submission token trước restart còn đọc được.

Wrapper lọc dòng export của upstream. Xem log riêng tư và rà soát trước chia sẻ. Log Docker xoay tối đa 3 file mỗi container, mỗi file 10 MiB. Nginx access log bỏ query/header. Backend chỉ gửi token bằng header.

Theo dõi queue qua GET `/workers` bằng client đọc token từ file, hoặc Redis CLI với REDISCLI_AUTH trong container, không đưa password lên command line. Endpoint vận hành cần kiểm tra policy thực tế trước bàn giao. Theo dõi RAM/OOM, CPU, disk, queue, lỗi/latency và CPU credits nếu instance burstable. AWS metrics/billing cần quyền riêng. Không tự thay đổi tài nguyên để xử lý thiếu capacity.

## Backup và restore

Chọn đích backup ngoài checkout, có đủ chỗ và quyền truy cập hạn chế. Dump chứa source/submission. Script tạo file exclusive mode 0600, file dở có thể còn nếu dump lỗi. Kiểm tra exit code và archive trước sử dụng.

```sh
sudo bash scripts/backup.sh /secure/backup/judge0-before-change.dump
sudo cat /secure/backup/judge0-before-change.dump | sudo docker compose exec -T db pg_restore --list
```

Để DB/queue nhất quán, dừng ingress và chờ queue/processing rỗng trước backup. Nếu cần giữ pending queue, dừng producer/worker có kiểm soát và backup Redis AOF cùng DB tại cùng điểm dừng. Không restore DB cũ cùng queue hiện tại. Backup secret/config/TLS riêng bằng cơ chế bảo vệ phù hợp. Kiểm thử phục hồi vào đích được duyệt trước khi dựa vào backup. Tạo thêm tài nguyên backup cần đồng ý riêng.

Restore cần xác nhận đích, backup hiện tại và maintenance. Khôi phục vào database/volume trống được duyệt, cùng PostgreSQL major. Dùng `pg_restore --exit-on-error --no-owner -U ... -d ...` trong container, lấy POSTGRES_USER/POSTGRES_DB từ environment bên trong container. Tránh `--clean` trên DB đang phục vụ. Đổi volume name sau review, khởi động API/worker, chạy smoke và kiểm tra token cũ. Chưa diễn tập restore trên EC2.

## Retention, cập nhật và rollback

Đề xuất giữ submission terminal 7 ngày, cần chủ máy duyệt theo yêu cầu dữ liệu. Trước cleanup, đếm/review row `status_id NOT IN (1,2)` có `created_at` cũ hơn ngưỡng, backup và kiểm chứng. Chỉ xóa theo batch được duyệt bằng quản trị DB. Không lập cron xóa mặc định và không xóa volume.

Trước cập nhật lưu commit/image digests, config được bảo vệ và backup kiểm chứng. Đọc release/advisory, kiểm tra architecture/cgroups/migration và test trên dữ liệu phục hồi được duyệt. Đổi tag/digest qua commit review. Rollback commit/image cũ khi schema tương thích, hoặc restore bộ backup DB/queue/config tương ứng trong maintenance. Không rollback PostgreSQL major bằng cách gắn volume mới vào image cũ.
