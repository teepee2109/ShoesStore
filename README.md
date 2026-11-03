# Adidas Shoe Store - Ung dung ban giay (PRM393)

> File nay vua la README cua du an, **tai lieu ngu canh (context).

---

## 1. Tong quan

- **Ten de tai:** Ung dung ban giay cho Adidas
- **Loai:** Do an ca nhan mon PRM393 (Flutter Mobile Programming)
- **Mo ta:** Ung dung di dong cho phep khach hang duyet, tim kiem, mua giay Adidas, thanh toan online va chat voi cua hang. Quan tri vien quan ly san pham, don hang, nguoi dung va xem thong ke qua Web Admin.
- **Doi tuong su dung:**
  - Khach hang (Customer): dung app Flutter
  - Quan tri vien (Admin): dung Web Admin
- **Luu y thuong hieu:** Day la du an hoc tap, khong lien ket chinh thuc voi Adidas. Dung anh/logo tu thiet ke hoac anh mien phi ban quyen.

## 2. Cong nghe su dung

| Tang | Cong nghe |
|---|---|
| Mobile | Flutter + Dart (Android bat buoc, iOS la diem cong) |
| State management | Provider (hoac Riverpod) |
| HTTP client | `dio` |
| Dieu huong | `go_router` |
| Luu cuc bo | `shared_preferences` (token, trang thai dang nhap) |
| Backend | Node.js + Express |
| Auth | JWT + bcrypt |
| Database | MySQL (KHONG dung SQLite lam DB chinh) |
| API docs | Swagger (swagger-ui-express) + Postman collection |
| Web Admin | React (hoac HTML + Bootstrap) |
| Thanh toan | VNPay sandbox (co the them MoMo / PayPal) |
| Chat | Socket.IO |
| Deploy | Render / Railway / VPS (backend + DB) |

## 3. Chuc nang

### 3.1 Khach hang (Flutter app)
- [x] Dang ky / dang nhap / dang xuat (JWT, luu token bang SharedPreferences)
- [x] Trang chu: banner, danh muc, san pham noi bat, san pham moi
- [x] Danh sach san pham: loc theo danh muc, gia, size, mau; sap xep; tim kiem
- [x] Chi tiet san pham: anh, mo ta, chon size/mau, ton kho, danh gia
- [x] Gio hang: them, sua so luong, xoa
- [x] Yeu thich (wishlist)
- [x] Dat hang: chon dia chi, phuong thuc thanh toan
- [x] Thanh toan minh hoa qua VNPay sandbox
- [x] Lich su don hang va theo doi trang thai
- [x] Danh gia san pham (chi sau khi da nhan hang)
- [x] Chat voi cua hang (real-time qua Socket.IO)
- [x] Thong bao khi doi trang thai don hang
- [x] Quan ly ho so, dia chi va doi mat khau

### 3.2 Quan tri vien (Web Admin)
- [x] Dang nhap (role = admin)
- [x] CRUD san pham, danh muc, bien the (size/mau/ton kho)
- [x] Upload anh san pham
- [x] Quan ly don hang, doi trang thai
- [x] Quan ly nguoi dung
- [x] Thong ke: doanh thu theo ngay/thang, san pham ban chay, ton kho thap, so don theo trang thai
- [x] Tra loi chat khach hang

## 4. Kien truc

```
[Flutter App] --HTTPS/REST--> [Node.js + Express API] --> [MySQL]
[Web Admin]   --HTTPS/REST-->          |
[Flutter/Admin] <--WebSocket (Socket.IO)--+
                                       +--> [VNPay sandbox] (tao URL + IPN callback)
```

Backend theo mo hinh: `routes -> controllers -> services -> models/repositories`.
Flutter theo mo hinh: `data (api, models, repositories) -> providers -> UI (screens, widgets)`.

## 5. Cau truc thu muc

```
PE_PRM393/
├── BackEnd/               # Node.js + Express + MySQL
│   ├── src/               # config, routes, controllers, services, models, middleware
│   ├── .env.example
│   └── package.json
├── FrontEnd/              # Flutter Android app
│   ├── android/
│   ├── lib/                # app, core, data, providers, presentation
│   └── pubspec.yaml
├── schema.sql
├── seed.sql
└── README.md
```

Backend có xác thực JWT, catalog, CRUD quản trị, giỏ hàng, địa chỉ, wishlist,
đặt/hủy đơn có transaction, review sau khi giao hàng, notification, thanh toán
VNPay sandbox, chat Socket.IO và thống kê. Web Admin HTML + Bootstrap phục vụ từ
backend tại `/admin-ui/`.

## 6. Thiet ke co so du lieu (MySQL)

| Bang | Cot chinh |
|---|---|
| `users` | id, name, email (unique), password_hash, phone, role (`customer`/`admin`), avatar, created_at |
| `addresses` | id, user_id, receiver_name, phone, address_line, city, is_default |
| `categories` | id, name, slug, image |
| `products` | id, category_id, name, description, price, discount_price, main_image, is_active, created_at |
| `product_images` | id, product_id, url |
| `product_variants` | id, product_id, size, color, stock |
| `carts` | id, user_id |
| `cart_items` | id, cart_id, variant_id, quantity |
| `wishlists` | id, user_id, product_id |
| `orders` | id, user_id, address_id, total_amount, status, payment_method, payment_status, created_at |
| `order_items` | id, order_id, variant_id, quantity, unit_price |
| `payments` | id, order_id, provider, transaction_id, amount, status, raw_response, created_at |
| `reviews` | id, product_id, user_id, rating (1-5), comment, created_at |
| `messages` | id, sender_id, receiver_id, content, is_read, created_at |
| `notifications` | id, user_id, title, body, is_read, created_at |

**Quan he chinh:** category 1-n products; product 1-n variants; user 1-n orders; order 1-n order_items; order 1-1/n payments; user 1-n reviews.

**Trang thai don hang:** `pending -> confirmed -> shipping -> delivered` (hoac `cancelled`).
**Trang thai thanh toan:** `unpaid | paid | failed | refunded`.

> Quan trong: gia luu trong `order_items.unit_price` la gia tai thoi diem mua, khong tham chieu lai `products.price`.

## 7. Danh sach API (REST, prefix `/api/v1`)

Response chuan: `{ "success": true|false, "data": ..., "message": "..." }`.
Danh sach endpoint, request/response mau, phan quyen va quy tac checkout/IPN nam
trong [docs/api-design.md](docs/api-design.md). Tai lieu danh dau ro endpoint nao
da co trong code va endpoint nao dang la thiet ke.

## 8. Man hinh Flutter

1. Splash (kiem tra token)
2. Login / Register
3. Home (banner, danh muc, noi bat)
4. Product list (loc, tim kiem)
5. Product detail (chon size/mau)
6. Cart
7. Checkout (dia chi, phuong thuc thanh toan)
8. Payment WebView (VNPay)
9. Order list / Order detail
10. Wishlist
11. Chat
12. Profile / Address / Notifications

Bottom navigation: Home - Search - Wishlist - Cart - Profile.

## 9. Quy tac cho AI khi vibe code (BAT BUOC DOC)

1. **Khong hardcode du lieu.** Moi du lieu hien thi phai lay tu API.
2. **Khong dung SQLite lam DB chinh.** Chi dung SharedPreferences cho token/setting.
3. Moi man hinh goi API phai co du 3 trang thai: **loading, error (co nut thu lai), empty**.
4. Moi form phai co **validation** (email, mat khau >= 6 ky tu, so dien thoai...).
5. Dung `async/await` + `Future`; khong chan UI thread.
6. Backend:
   - Mat khau hash bang bcrypt, khong tra `password_hash` ra response.
   - Dung prepared statements / parameterized query (chong SQL injection).
   - Middleware kiem tra JWT va role cho route admin.
   - Tao don hang phai dung **transaction**, tru ton kho, rollback khi loi.
   - Doc cau hinh tu `.env`, khong commit secret.
7. Code ngan gon, dat ten ro rang, tach lop theo cau truc o muc 5. Moi lan chi sua/them mot phan nho.
8. Sau moi tinh nang: chay duoc, khong loi analyzer (`flutter analyze`), cap nhat README neu doi API.
9. Tra loi/giai thich ngan gon; neu thay doi nhieu file, liet ke file da doi.
10. **Toi can hieu code de van dap**: khi sinh code phuc tap (JWT, thanh toan, state), kem 2-3 dong giai thich luong xu ly.

## 10. Lo trinh theo moc nop bai

### Tuan 3 (Slot 6) - Thiet ke
- [ ] Khoi tao Flutter project, cau truc thu muc ro rang
- [ ] UI cac man hinh chinh + navigation (du lieu tam thoi chi de dung layout)
- [ ] Mockup (Figma/anh/PDF) trong `docs/mockup`
- [ ] ERD + danh sach bang trong `docs/`
- [ ] README (ten de tai, mo ta, chuc nang, cong nghe)

### Tuan 6 (Slot 12) - Backend & API
- [x] Backend chay duoc, ket noi MySQL (can cau hinh `.env` local)
- [x] `schema.sql` + `seed.sql` (co du lieu mau)
- [x] API Auth + CRUD san pham/don hang va tai lieu Postman/Swagger
- [x] Web Admin CRUD co ban
- [x] README: huong dan chay backend + danh sach API

### Tuan 9 (Slot 16) - Tich hop
- [x] Flutter goi API that, xu ly loading/loi/validation
- [x] State management (Provider) + async/await
- [x] SharedPreferences luu token/login state
- [x] Tich hop VNPay sandbox, chat, thong ke (can cau hinh merchant va IPN public URL)
- [x] README: huong dan chay app va tai khoan test

### Slot 18 - Nop cuoi
- [ ] Video demo YouTube
- [ ] Link GitHub (mobile + backend + admin)
- [ ] Deploy backend, build APK/AAB, dua len Google Play hoac APKPure

## 11. Huong dan chay base code

### 1) Tao database va du lieu mau
```bash
# Canh bao: schema.sql xoa database adidas_shop neu database nay da ton tai.
# Hay sao luu du lieu cu truoc khi chay hai lenh import ben duoi.
mysql -u root -p < schema.sql
mysql -u root -p < seed.sql
```

### 2) Chay backend
```powershell
# Chay tu thu muc goc cua repo
Copy-Item BackEnd/.env.example BackEnd/.env
# Tao secret bang lenh duoi day, roi dan ket qua vao BackEnd/.env
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
# Sua BackEnd/.env: DB_USER, DB_PASSWORD va JWT_SECRET (toi thieu 32 ky tu)
# Neu DB da duoc tao tu schema cu, chay migration BackEnd/migrations/001_payments_provider_transaction_unique.sql
cd BackEnd
npm install
npm run dev                  # http://localhost:3000
```

Swagger UI: `http://localhost:3000/api-docs/` · OpenAPI JSON:
`http://localhost:3000/openapi.json` · Web Admin: `http://localhost:3000/admin-ui/`.
Postman collection: [docs/api.postman.json](docs/api.postman.json).

### VNPay sandbox va IPN

Trong `BackEnd/.env`, dien `VNPAY_TMN_CODE` va `VNPAY_HASH_SECRET` theo tai khoan
sandbox; giu `VNPAY_URL` o dia chi sandbox. De VNPay goi IPN khi chay local, mo
cong backend bang `ngrok http 3000`, roi dat `VNPAY_RETURN_URL` va
`VNPAY_IPN_URL` theo domain HTTPS ngrok. Khai bao cung URL IPN trong merchant
portal VNPay. URL return co dang
`https://<domain>/api/v1/payments/vnpay/return`; URL IPN co dang
`https://<domain>/api/v1/payments/vnpay/ipn`. Domain ngrok thay doi thi cap nhat
ca `.env` va merchant portal, sau do khoi dong lai backend. IPN la noi cap nhat
trang thai thanh toan chinh thuc; return URL chi hien ket qua cho nguoi dung.

Chat realtime: Socket.IO cung origin voi backend. Client gui JWT trong handshake
`auth.token`; events: `join`, `message:send`, `message:new`, `typing`.

### 3) Chay Flutter app
```bash
cd FrontEnd
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```
`10.0.2.2` la dia chi de Android emulator truy cap may chu chay tren may tinh.
Neu chay tren dien thoai that, thay bang IP LAN cua may tinh; khi deploy, dung HTTPS.

### Tai khoan test
| Vai tro | Email | Mat khau |
|---|---|---|
| Admin | admin@shop.com | admin123 |
| Customer | user@shop.com | 123456 |

### API da co
| Method | Endpoint | Mo ta |
|---|---|---|
| GET | `/health` | Kiem tra backend |
| POST | `/api/v1/auth/register` | Tao tai khoan customer |
| POST | `/api/v1/auth/login` | Dang nhap, tra JWT |
| GET | `/api/v1/auth/me` | Lay user hien tai (Bearer token) |
| PUT | `/api/v1/auth/me` | Cap nhat ten va so dien thoai |
| PUT | `/api/v1/auth/password` | Doi mat khau sau khi xac thuc mat khau hien tai |
| GET | `/api/v1/categories` | Danh sach danh muc |
| GET | `/api/v1/products` | Tim/loc san pham (`q`, `category`, `minPrice`, `maxPrice`, `size`, `color`, `sort`, `page`, `limit`) |
| GET | `/api/v1/products/:id` | Chi tiet, anh, bien the, danh gia trung binh va review |
| POST/PUT/DELETE | `/api/v1/products` , `/api/v1/products/:id` | CRUD san pham (admin) |
| POST/PUT/DELETE | `/api/v1/products/:id/variants` , `/api/v1/products/:id/variants/:variantId` | CRUD bien the (admin) |
| POST/DELETE | `/api/v1/products/:id/images` , `/api/v1/products/:id/images/:imageId` | Upload/xoa anh (admin) |
| GET/POST/PUT/DELETE | `/api/v1/cart` va `/api/v1/cart/items` | Gio hang (customer) |
| GET/POST/DELETE | `/api/v1/wishlist` va `/api/v1/wishlist/items` | Yeu thich (customer) |
| GET/POST/PUT/DELETE | `/api/v1/addresses` va `/api/v1/addresses/:id` | Dia chi (customer) |
| POST/GET/PUT | `/api/v1/orders` va `/api/v1/orders/:id/cancel` | Dat/huy don, lich su va chi tiet (customer) |
| POST/PUT/DELETE | `/api/v1/categories` va `/api/v1/categories/:id` | CRUD danh muc (admin) |
| GET/PUT | `/api/v1/admin/orders` va `/api/v1/admin/orders/:id/status` | Quan ly don va gui notification khi doi status (admin) |
| GET/PUT/DELETE | `/api/v1/admin/users` va `/api/v1/admin/users/:id` | Quan ly tai khoan, khong tra password hash (admin) |
| GET/POST | `/api/v1/products/:id/reviews` | Liet ke review; tao review neu da co don delivered |
| GET/PATCH | `/api/v1/notifications` va `/api/v1/notifications/:id/read` | Thong bao cua tai khoan dang dang nhap |
| POST/GET | `/api/v1/payments/vnpay/create`, `/return`, `/ipn` | Tao URL sandbox, xac minh return va IPN cap nhat payment |
| GET | `/api/v1/admin/stats/*` | Doanh thu, top products, ton kho thap, dem don theo status |
| GET | `/api/v1/admin/chats` va `/api/v1/admin/chats/:customerId/messages` | Danh sach hoi thoai va lich su chat |

Moi API tra ve phong bi `{ "success": true|false, "data": ..., "message": "..." }`.
