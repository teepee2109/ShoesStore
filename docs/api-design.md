# Thiết kế REST API v1 — Adidas Shoe Store

Tài liệu này là hợp đồng API cho Flutter app và Web Admin. Prefix REST là
`/api/v1`; backend dùng MySQL hiện có trong `schema.sql` và mọi thời điểm lưu
giá theo VND nguyên.

**Trạng thái:** `Đã có` nghĩa là route đang tồn tại trong `BackEnd/src`; `Thiết kế`
nghĩa là endpoint đã được đặc tả nhưng chưa có code.

## 1. Quy ước chung

- JSON UTF-8. Field trong JSON request/response dùng `snake_case`. Query param
  sản phẩm giữ tên hiện có `minPrice` và `maxPrice` để tương thích mobile.
- API JSON dùng phong bì `{ "success": true, "data": ..., "message": "..." }`.
  Khi lỗi: `{ "success": false, "data": null, "message": "..." }`.
- Route riêng tư nhận header `Authorization: Bearer <JWT>`.
- Danh sách dùng `page` mặc định `1`, `limit` mặc định `20`, tối đa `50`.
  Response danh sách dùng `data: { "items": [], "pagination": { "page",
  "limit", "total", "total_pages" } }`.
- Không nhận `user_id`, giá bán, tổng tiền, trạng thái thanh toán hoặc role từ
  client nếu server có thể xác định hoặc tính được.
- Dùng mã HTTP: `200` thành công, `201` tạo mới, `400` dữ liệu sai, `401` chưa
  đăng nhập/token hết hạn, `403` sai quyền, `404` không tồn tại, `409` xung đột
  (email trùng, thiếu hàng, sai chuyển trạng thái), `500/503` lỗi server/DB.

### Ví dụ lỗi

```json
{
  "success": false,
  "data": null,
  "message": "Số lượng đặt vượt quá tồn kho."
}
```

## 2. Auth

| Method | Endpoint | Quyền | Trạng thái | Mục đích |
|---|---|---|---|---|
| POST | `/auth/register` | Public | Đã có | Tạo customer |
| POST | `/auth/login` | Public | Đã có | Đăng nhập, trả JWT |
| GET | `/auth/me` | Customer/Admin | Đã có | Lấy user từ JWT |
| PUT | `/auth/me` | Customer/Admin | Đã có | Cập nhật tên và số điện thoại |
| PUT | `/auth/password` | Customer/Admin | Đã có | Đổi mật khẩu sau khi xác thực mật khẩu hiện tại |

`POST /auth/register` body:

```json
{ "name": "Nguyen Van An", "email": "an@example.com", "password": "123456", "phone": "0912345678" }
```

`POST /auth/login` nhận `{ "email": "...", "password": "..." }`, trả `data`
gồm `{ "user": { "id", "name", "email", "phone", "role" }, "token": "..." }`.
Đăng ký luôn tạo role `customer`; server hash mật khẩu bằng bcrypt và không trả
`password_hash`.

## 3. Danh mục và sản phẩm

| Method | Endpoint | Quyền | Trạng thái | Mục đích |
|---|---|---|---|---|
| GET | `/categories` | Public | Đã có | Danh sách danh mục |
| GET | `/products` | Public | Đã có | Tìm kiếm, lọc, phân trang |
| GET | `/products/:product_id` | Public | Đã có | Chi tiết, ảnh, biến thể, điểm trung bình và đánh giá |
| POST | `/categories` | Admin | Đã có | Tạo danh mục |
| PUT | `/categories/:category_id` | Admin | Đã có | Sửa danh mục |
| DELETE | `/categories/:category_id` | Admin | Đã có | Xóa nếu chưa có sản phẩm |
| POST | `/products` | Admin | Đã có | Tạo sản phẩm |
| PUT | `/products/:product_id` | Admin | Đã có | Cập nhật thông tin sản phẩm |
| DELETE | `/products/:product_id` | Admin | Đã có | Ẩn sản phẩm (`is_active = 0`) |
| POST | `/products/:product_id/variants` | Admin | Đã có | Tạo biến thể size/màu |
| PUT | `/products/:product_id/variants/:variant_id` | Admin | Đã có | Sửa biến thể/tồn kho |
| DELETE | `/products/:product_id/variants/:variant_id` | Admin | Đã có | Xóa nếu chưa có trong đơn/giỏ |
| POST | `/products/:product_id/images` | Admin | Đã có | Upload tối đa 8 ảnh JPEG/PNG/WebP |
| DELETE | `/products/:product_id/images/:image_id` | Admin | Đã có | Xóa ảnh và cập nhật ảnh đại diện |

Query `GET /products`:

| Tham số | Ý nghĩa |
|---|---|
| `q` | Tìm trong tên/mô tả |
| `category` | Slug danh mục, ví dụ `running` |
| `minPrice`, `maxPrice` | Khoảng giá theo giá đang bán (`discount_price` nếu có, ngược lại `price`) |
| `size`, `color` | Lọc theo biến thể |
| `sort` | `latest`, `price_asc`, `price_desc` |
| `page`, `limit` | Phân trang; `limit` tối đa 50 |

Ví dụ response `GET /products?page=1&limit=20`:

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": 1,
        "name": "Ultraboost Light",
        "price": 4500000,
        "discount_price": 3990000,
        "main_image": "/uploads/products/ultraboost-light-1.jpg",
        "category_name": "Running",
        "category_slug": "running",
        "stock": 12
      }
    ],
    "pagination": { "page": 1, "limit": 20, "total": 1, "total_pages": 1 }
  },
  "message": "Lấy sản phẩm thành công."
}
```

Sản phẩm mới nhận `category_id`, `name`, `description`, `price`, `discount_price`.
Upload ảnh bằng `multipart/form-data`, field `images`, mỗi ảnh tối đa 5 MB. Server
lưu file trong `BackEnd/uploads/` và trả URL `/uploads/<filename>`. Tạo/sửa biến thể
dùng `{ "size": "42", "color": "Core Black", "stock": 8 }`. Giá do admin gửi
khi tạo/sửa sản phẩm; giá đơn hàng luôn được server đọc lại từ DB. Sản phẩm dùng
trong lịch sử đơn không bị xóa cứng; `DELETE` chuyển `is_active` về `0`.

Response chi tiết trả `images`, `variants`, `reviews`, `rating_average` (0 nếu
chưa có review) và `review_count`. Danh sách review trả tối đa 10 review mới nhất;
điểm trung bình được tính trên toàn bộ review của sản phẩm.

## 4. Giỏ hàng, yêu thích, địa chỉ

| Method | Endpoint | Quyền | Trạng thái | Mục đích |
|---|---|---|---|---|
| GET | `/cart` | Customer | Đã có | Xem giỏ và tổng tạm tính |
| POST | `/cart/items` | Customer | Đã có | Thêm biến thể |
| PUT | `/cart/items/:item_id` | Customer | Đã có | Đặt số lượng mới |
| DELETE | `/cart/items/:item_id` | Customer | Đã có | Xóa một dòng |
| DELETE | `/cart/items` | Customer | Đã có | Xóa toàn bộ giỏ |
| GET | `/wishlist` | Customer | Đã có | Xem sản phẩm yêu thích |
| POST | `/wishlist/items` | Customer | Đã có | Thêm `{ "product_id": 12 }` |
| DELETE | `/wishlist/items/:product_id` | Customer | Đã có | Bỏ yêu thích |
| GET | `/addresses` | Customer | Đã có | Danh sách địa chỉ của tôi |
| POST | `/addresses` | Customer | Đã có | Tạo địa chỉ |
| PUT | `/addresses/:address_id` | Customer | Đã có | Sửa địa chỉ của tôi |
| DELETE | `/addresses/:address_id` | Customer | Đã có | Xóa địa chỉ của tôi |

`POST /cart/items`: `{ "variant_id": 25, "quantity": 1 }`. Nếu biến thể đã có
trong giỏ, cộng số lượng; server từ chối nếu tổng số lượng vượt tồn kho.
`PUT` đặt số lượng tuyệt đối, không phải số tăng/giảm.

Địa chỉ dùng các trường `receiver_name`, `phone`, `address_line`, `city`,
`is_default`. Mỗi thao tác kiểm tra `user_id` từ JWT; khi đặt mặc định, server
đổi cờ mặc định trong một transaction.

## 5. Đơn hàng và thanh toán

| Method | Endpoint | Quyền | Trạng thái | Mục đích |
|---|---|---|---|---|
| POST | `/orders` | Customer | Đã có | Tạo đơn từ giỏ hàng |
| GET | `/orders` | Customer | Đã có | Lịch sử đơn của tôi |
| GET | `/orders/:order_id` | Chủ đơn | Đã có | Chi tiết đơn |
| PUT | `/orders/:order_id/cancel` | Chủ đơn | Đã có | Hủy đơn `pending`, chưa thanh toán |
| GET | `/admin/orders` | Admin | Đã có | Lọc/phân trang tất cả đơn |
| PUT | `/admin/orders/:order_id/status` | Admin | Đã có | Cập nhật trạng thái đơn và gửi notification |
| POST | `/payments/sepay/create` | Chủ đơn | Đã có | Tạo form checkout SePay đã ký |
| GET | `/payments/sepay/return` | Public callback | Đã có | Đưa khách về app; không cập nhật trạng thái thanh toán |
| GET | `/payments/sepay/status/:order_id` | Chủ đơn | Đã có | Xem trạng thái thanh toán đã được IPN xác nhận |
| POST | `/payments/sepay/ipn` | SePay callback | Đã có | Xác thực IPN bằng secret key, cập nhật payment/order |
| GET | `/payments/:payment_id` | Chủ đơn/Admin | Thiết kế | Xem kết quả thanh toán đã lọc thông tin nhạy cảm |

`POST /orders` nhận `{ "address_id": 3, "payment_method": "cod" }` hoặc
`payment_method: "sepay"`. V1 hỗ trợ `cod` và `sepay`; có thể mở rộng thêm provider
sau. Server lấy các dòng hàng từ giỏ của user, lấy giá hiện
tại từ DB, kiểm tra địa chỉ thuộc user, khóa các biến thể tồn kho, trừ kho, ghi
`orders`/`order_items` với snapshot `unit_price`, rồi xóa giỏ hàng — tất cả trong
một transaction. Client không được gửi `total_amount` hoặc `unit_price`.

Luồng SePay: app tạo đơn trước, sau đó gọi `/payments/sepay/create` với
`{ "order_id": 101 }`. Backend tự tính số tiền, tạo mã hóa đơn và ký form
checkout HMAC-SHA256 theo Merchant Secret Key; app POST form sang checkout SePay.
Return chỉ phục vụ điều hướng giao diện. IPN POST phải có `X-Secret-Key` khớp
`SEPAY_IPN_SECRET_KEY`, đúng mã hóa đơn, số tiền và tiền tệ trước khi cập nhật
payment/order; callback lặp được xử lý idempotent. Cấu hình `SEPAY_RETURN_URL` và
`SEPAY_IPN_URL` bằng HTTPS public, rồi đăng ký IPN URL và cùng secret trong SePay.

`PUT /admin/orders/:order_id/status` nhận `{ "status": "confirmed" }`; backend
kiểm tra chuyển trạng thái hợp lệ và ghi notification cho khách hàng.

Trạng thái đơn: `pending -> confirmed -> shipping -> delivered`; đơn có thể chuyển
sang `cancelled` khi còn đủ điều kiện hủy. Customer chỉ hủy đơn `pending` chưa trả
tiền. Khi hủy, server hoàn tồn kho trong transaction. Admin không được chuyển
ngược tùy ý; mọi bước chuyển trạng thái phải qua allowlist.

Trạng thái thanh toán: `unpaid`, `paid`, `failed`, `refunded`. Trạng thái payment
attempt trong bảng `payments`: `pending`, `success`, `failed`, `refunded`. Không
trả `raw_response` ra client.

## 6. Đánh giá, thông báo, chat

| Method | Endpoint | Quyền | Trạng thái | Mục đích |
|---|---|---|---|---|
| GET | `/products/:product_id/reviews` | Public | Đã có | Danh sách/điểm trung bình đánh giá |
| POST | `/products/:product_id/reviews` | Customer | Đã có | Tạo đánh giá sau đơn delivered |
| PATCH | `/reviews/:review_id` | Chủ đánh giá | Thiết kế | Sửa nội dung/điểm |
| DELETE | `/reviews/:review_id` | Chủ đánh giá/Admin | Thiết kế | Xóa đánh giá |
| GET | `/notifications` | Customer/Admin | Đã có | Danh sách thông báo của tôi |
| PATCH | `/notifications/:notification_id/read` | Customer/Admin | Đã có | Đánh dấu đã đọc |
| PATCH | `/notifications/read-all` | Customer/Admin | Đã có | Đánh dấu tất cả đã đọc |
| GET | `/admin/chats` | Admin | Đã có | Danh sách hội thoại cần trả lời |
| GET | `/admin/chats/:customer_id/messages` | Admin | Đã có | Lịch sử chat với khách |

Chỉ cho tạo review khi user có đơn `delivered` chứa sản phẩm; schema hiện giới
hạn mỗi user một review/sản phẩm. Chat chỉ cho phép customer trò chuyện với admin;
không cho customer gửi tin trực tiếp cho customer khác. API REST lưu/đọc lịch sử,
Socket.IO phát tin nhắn mới theo cùng quy tắc quyền.

Socket.IO dùng JWT trong handshake (`auth.token`). Client phát `join`,
`message:send`, `typing`; server phát `chat:history`, `message:new`, `typing`,
`chat:error` và admin inbox event `chat:inbox`. Server tự xác định người gửi từ
token, kiểm tra quyền customer/admin trước khi join room hoặc ghi tin.

## 7. Admin và thống kê

| Method | Endpoint | Quyền | Trạng thái | Mục đích |
|---|---|---|---|---|
| GET | `/admin/users` | Admin | Đã có | Tìm kiếm/phân trang user |
| GET | `/admin/users/:user_id` | Admin | Đã có | Chi tiết user |
| PUT | `/admin/users/:user_id` | Admin | Đã có | Sửa tên, phone, role |
| DELETE | `/admin/users/:user_id` | Admin | Đã có | Xóa user chưa có đơn; không thể tự xóa hoặc xóa admin cuối cùng |
| GET | `/admin/stats/revenue` | Admin | Đã có | Doanh thu theo ngày/tháng |
| GET | `/admin/stats/top-products` | Admin | Đã có | Sản phẩm bán chạy |
| GET | `/admin/stats/low-stock` | Admin | Đã có | Biến thể tồn thấp |
| GET | `/admin/stats/orders-by-status` | Admin | Đã có | Số đơn theo trạng thái |

Báo cáo doanh thu, sản phẩm bán chạy và đơn theo trạng thái nhận `from`, `to` dạng
`YYYY-MM-DD`; báo cáo doanh thu nhận thêm `group=day|month`. Báo cáo tồn kho nhận
`threshold` (mặc định 5) và đọc số lượng hiện tại. Doanh thu chỉ tính đơn đã thanh
toán, loại đơn đã hủy. User gắn với đơn hàng không bị hard-delete; schema có khóa
ngoại `RESTRICT` từ `orders`.

Admin order status chỉ đi theo luồng `pending -> confirmed -> shipping -> delivered`;
đơn chưa thanh toán có thể bị hủy từ `pending` hoặc `confirmed`, khi đó tồn kho
được hoàn lại trong transaction. Đơn đã thanh toán phải được hoàn tiền trước khi
hủy. Danh mục CRUD dùng `/categories` và yêu cầu role `admin` cho thao tác ghi.

Swagger UI: `/api-docs/` (OpenAPI JSON: `/openapi.json`). Web Admin HTML/Bootstrap:
`/admin-ui/`. Postman collection: `docs/api.postman.json`.

## 8. Quy tắc bảo mật và dữ liệu

1. Dùng prepared statements cho mọi truy vấn; `sort`/`group_by` phải nằm trong
   allowlist, không nối trực tiếp query từ người dùng.
2. Kiểm tra quyền sở hữu cart, wishlist, address, order, review, notification và
   conversation ở service/model; không tin ID từ client.
3. Tạo đơn và trừ kho trong một transaction với `SELECT ... FOR UPDATE`; rollback
   nếu thiếu hàng hoặc bất kỳ bước nào lỗi.
4. SePay IPN kiểm secret, mã tiền tệ, số tiền, mã hóa đơn và trạng thái đơn; cập
   nhật payment/order trong transaction, idempotent khi SePay gửi lại callback.
5. Không trả password hash, JWT secret, thông tin cấu hình hoặc `raw_response`.
6. Ẩn sản phẩm (`is_active = 0`) thay vì xóa cứng sản phẩm đã có trong lịch sử đơn.

### Điểm cần gia cố trước khi triển khai production

- Thêm `expires_at`/cơ chế dọn đơn online chưa thanh toán để tự hoàn kho khi khách
  bỏ dở checkout; nếu chưa có cơ chế hết hạn, chỉ hoàn kho khi đơn được hủy.
- Nếu cần chống tạo hai đơn khi app retry request, thêm bảng lưu
  `Idempotency-Key` theo user hoặc cột key có unique constraint trước khi bật
  retry tự động cho `POST /orders`.

## 9. Thứ tự triển khai đề xuất

1. Cart + address + checkout/order transaction.
2. Admin CRUD product/category/variant và quản lý trạng thái đơn.
3. SePay create/IPN/return.
4. Reviews, wishlist, notifications.
5. Chat Socket.IO và dashboard thống kê.
