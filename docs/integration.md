# Integration cho Backend LearnAble

Hợp đồng theo API v1.13.1. Chủ máy báo HTTPS từ backend đã PASS authenticated languages, accepted, wrong answer, compilation error và time limit. Codex chưa xác minh trực tiếp. Mapping language, restart/network/concurrency và tự gia hạn còn cần kết quả tương ứng.

| Mục | Giá trị / trạng thái |
| --- | --- |
| Base URL HTTPS | https://3.25.120.198, chủ máy báo đã kiểm thử từ backend |
| Header xác thực | X-Auth-Token, token cấp riêng qua kênh bảo mật |
| Language mapping | Chưa xác minh, lấy từ GET /languages và output smoke |
| Batch/callback | Tắt trong cấu hình demo |
| TLS trust | Let's Encrypt IP SAN, backend dùng system CA trust |

Backend EC2 gọi Judge0, frontend gọi backend. Token ở secret/config backend và chỉ gửi bằng header. AUTHZ_TOKEN dành cho quản trị, không cần để tạo submission và lấy kết quả.

## Endpoint và ví dụ

GET `/languages` trả danh sách `{id, name}`. Dùng ID từ endpoint thực tế, không lấy bảng README upstream làm mapping nghiệm thu.

POST `/submissions?base64_encoded=true&wait=false` nhận JSON dưới đây. Thay placeholder language_id bằng số nguyên đã xác minh trước khi gửi.

```json
{
  "source_code": "cHJpbnQoNDIpCg==",
  "language_id": "<verified-python-id>",
  "expected_output": "NDIK"
}
```

HTTP 201 có response `{ "token": "<submission-id>" }`. Poll GET `/submissions/<submission-id>?fields=status`. Khi status kết thúc, lấy kết quả qua GET `/submissions/<submission-id>?base64_encoded=true&fields=token,status,stdout,stderr,compile_output,time,memory,message,exit_code,exit_signal`. Thêm header X-Auth-Token trong mọi request, không đặt token trong URL. Với base64_encoded=true, backend decode các trường source/input/output tương ứng.

Ví dụ response accepted theo hợp đồng gồm `status.id=3`, `stdout="NDIK"`, `stderr=null`. time/memory lấy từ kết quả thật. Đây chưa phải response đã quan sát trên EC2.

## Trạng thái và lỗi

| status.id | Xử lý |
| --- | --- |
| 1 | In Queue, tiếp tục poll |
| 2 | Processing, tiếp tục poll |
| 3 | Accepted |
| 4 | Wrong Answer |
| 5 | Time Limit Exceeded |
| 6 | Compilation Error |
| 7–12 | Runtime errors, xem description/exit_code/exit_signal |
| 13 | Internal Error, báo quản trị và xử lý lỗi dịch vụ |
| 14 | Exec Format Error |

Polling đề xuất từ 1 giây, backoff tối đa 3 giây có jitter, deadline demo 90 giây. Timeout client không hủy job và không đồng nghĩa chương trình sai. Lưu submission token ngay khi nhận. POST timeout có thể đã tạo job, tránh retry mù vì idempotency chưa được xác minh.

- HTTP 401 cho thiếu/sai token. Kiểm tra secret thay vì retry liên tục.
- HTTP 403 cho quyền quản trị hoặc policy IP.
- HTTP 422 cho payload/giới hạn không hợp lệ.
- HTTP 429 từ proxy, backoff có giới hạn.
- HTTP 503 có thể do queue đầy/maintenance. HTTP 502/504 có thể do upstream chưa sẵn sàng. Phân biệt lỗi dịch vụ với verdict bài làm.
- Lỗi TLS cần sửa trust/IP/expiry, giữ certificate verification.

## Giới hạn cấu hình demo

CPU mặc định/tối đa 2 giây, extra 0.5 giây, wall 5 giây, memory 128000 KB, stack 64000 KB, process/thread 32, max file size 1024 KB, một lần chạy. Server chặn nâng quá các mức tối đa, bật network và per-process overrides. Output chịu giới hạn file sandbox, cần kiểm thử thực tế trước công bố hạn mức transport. Proxy giới hạn request body 256 KiB gồm JSON/base64.

Compiler options, arguments, additional files, wait-result, batch và callback bị tắt. Java và một số runtime có thể cần memory/process cao hơn, cần test trước ghi hỗ trợ.

Một worker chạy một job tại một thời điểm, queue cap 20. Queue cap là kiểm tra ở cấp ứng dụng, không phải bảo đảm tuyệt đối khi producer gửi đồng thời. Backend bắt đầu một job in-flight và giới hạn backlog/testcase. Proxy cho 5 request/giây/IP, burst 10, tối đa 10 connection/IP. Polling cũng dùng rate budget. Đây là giới hạn cấu hình, chưa phải capacity đo trên EC2.

Trước bàn giao ghi commit, Base URL HTTPS đã test, certificate fingerprint/expiry, language mapping từ smoke, giới hạn cuối, kết quả restart/network/concurrency và backup/restore trong hồ sơ nghiệm thu. Hiện các mục đó đang chờ EC2.
