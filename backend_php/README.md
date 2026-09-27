# HarvestHub PHP API

Backend PHP cho app Flutter HarvestHub, ket noi MySQL database `harvesthub`.

## Cai dat

1. Cai PHP, Composer va bat MySQL trong XAMPP.
2. Tao file `.env` tu `.env.example` va dien thong tin MySQL.
3. Dien `FIREBASE_WEB_API_KEY` trong `.env`.
4. Chay:

```powershell
composer install
php -S 0.0.0.0:8080 -t public
```

Composer dependencies, bao gom PHPMailer, phai duoc cai tu thu muc backend:

```powershell
composer install --working-dir=backend_php
```

## Kiem tra

Mo tren may tinh:

```text
http://127.0.0.1:8080/api/health
```

Mo tren dien thoai cung Wi-Fi:

```text
http://10.18.211.168:8080/api/health
```

Flutter xac thuc email/mat khau hoac Google voi Firebase. Tai khoan moi chi
duoc dong bo vao MySQL sau khi nguoi dung chon customer/farmer o buoc hoan tat
tai khoan.

Backend xac minh token qua Firebase Auth REST API, nen van chay duoc voi PHP 8.0
va khong can cai Firebase Admin SDK hay service-account JSON.

## Xac thuc va phan quyen

- Firebase ID token xac nhan danh tinh; backend lay Firebase UID tu token va
  dung UID do de truy van cot `users.uid` trong MySQL.
- `GET /api/auth/me` tra ho so va role da duoc luu trong MySQL. Neu user chua
  duoc dong bo, API tra `404 user_not_synced`; app dua user den buoc chon loai
  tai khoan, khong tu dong cap customer.
- `/api/auth/sync` chi tao user moi voi role `customer`; role hien tai cua user
  khong bi ghi de khi sync lai. Role `farmer`/`admin` phai duoc cap boi quy
  trinh quan tri tin cay, khong lay tu tham so URL hay role client yeu cau.
- Cap role admin thu cong bang lenh CLI, khong dat script trong `public`:

```powershell
php cli/grant_admin.php admin@example.com
```

## Tich hop module quan tri

Truoc khi su dung cac man quan tri, chay mot lan `database/admin_features_schema.sql`
tren database `harvesthub`. Migration bo sung `users.is_locked`,
`farmers.user_uid`, `farmers.is_locked`, `products.is_hidden`,
`products.hide_reason`, `farmers_market.name_en`, va tao `audit_logs` neu chua
co. Cac cot danh muc (`name_en`, `display_order`, `is_active`) da co trong schema
hien tai. Migration dung `ALTER TABLE ... ADD COLUMN`, nen khong chay lai sau
khi da ap dung.

Flutter goi `/api/admin/*` va `/api/reports/*` tren cung PHP entrypoint
`public/index.php`. Moi request quan tri bat buoc co Firebase Bearer token va
backend tra cuu `users.uid` de xac nhan `role='admin'`; guard trong Flutter chi
la lop UX, khong thay the kiem tra phia server.

De mot ho so ban hang duoc gan vao tai khoan, ghi Firebase UID vao
`farmers.user_uid`. Cac ho so cu se co `user_uid = NULL` sau migration va can
duoc lien ket truoc khi duyet neu can cap role tu dong. Khi admin duyet farmer
da duoc lien ket, backend cap role `farmer`; tu choi ho so se ha quyen tai khoan
do ve `customer`.

### Don farmer va gioi han mot admin

Sau migration `admin_features_schema.sql`, chay them mot lan
`database/farmer_approval_single_admin.sql`. Truoc khi chay, kiem tra khong co
UID nao lap trong `farmers.user_uid` va chi co toi da mot user co role `admin`.
Migration them dia chi trang trai, rang buoc moi UID chi lien ket mot ho so,
va unique generated column de database tu choi moi thao tac tao admin thu hai.
Kiem tra bang cac truy van sau trong phpMyAdmin:

```sql
SELECT user_uid, COUNT(*) AS profile_count
FROM farmers
WHERE user_uid IS NOT NULL
GROUP BY user_uid
HAVING COUNT(*) > 1;

SELECT uid, email
FROM users
WHERE role = 'admin';
```

Truy van dau tien phai khong tra ve dong nao; truy van admin chi duoc tra ve
toi da mot tai khoan.

Tai app, nguoi dung moi xac thuc bang email/mat khau hoac Google, sau do chon
customer hoac farmer. Customer duoc vao app ngay voi role `customer`. Farmer
duoc tao ban ghi customer truoc, roi gui ten trang trai, cho hoat dong, dia chi,
so dien thoai lien he, mo ta va toa do GPS bat buoc lay tu vi tri thiet bi qua
`POST /api/farmer-applications`. Backend tu choi ho so neu thieu toa do GPS hop
le. Ho so duoc tao o trang thai `pending`; farmer
chi duoc cap role sau khi admin duyet. Khi duyet, role trong `users` duoc doi
tu `customer` sang `farmer`. Ho so bi tu choi co the duoc gui lai. Tai khoan
da ton tai se khong duoc hoi chon lai va luon duoc dieu huong theo role da co
trong MySQL.

Cap admin qua `php cli/grant_admin.php <email>` chi hoat dong neu chua co admin
khac. Unique constraint trong database la lop bao ve cuoi cung; khong cap role
admin bang cach khac bo qua migration nay.

App mo truc tiep man dang nhap. Tai khoan da co trong MySQL duoc dinh tuyen
theo role hien co cua Firebase UID. Tai khoan Firebase moi duoc dua toi man
chon customer/farmer; ca hai deu duoc tao trong MySQL voi role `customer`.
Chon farmer se mo form nop ho so, trang thai `pending` va khong co quyen farmer
truoc khi admin duyet.

Man `Tai khoan` trong admin doc user tu MySQL va ghep voi ho so farmer de loc
theo loai `customer`/`farmer` va trang thai `pending`/`approved`/`rejected`.
Farmer dang cho duyet van co `users.role = customer`, nen duoc nhan dien bang
ho so `farmers` lien ket, khong chi dua vao role. Khach hang khong nop ho so
farmer hien trang thai `not_applicable`. API:
`GET /api/admin/accounts?type=all|customer|farmer&status=all|pending|approved|rejected|not_applicable&q=...`.

De gui email khi admin duyet ho so:

1. Bat xac minh 2 buoc cho tai khoan Gmail gui email, sau do tao Google App
   Password trong trang quan ly tai khoan Google. Khong dung mat khau Gmail
   thuong.
2. Dien `SMTP_USERNAME` va `SMTP_FROM_EMAIL` bang dia chi Gmail gui,
   `SMTP_PASSWORD` bang App Password, va giu `SMTP_HOST=smtp.gmail.com`,
   `SMTP_PORT=587`, `SMTP_ENCRYPTION=tls` trong file `backend_php/.env`.
3. Khoi dong lai PHP server sau khi sua `.env`. Thu duyet mot ho so pending;
   giao dien admin se bao email da gui hay chua. Neu chua gui, xem PHP error
   log va kiem tra SMTP/App Password, ket noi Internet va email Firebase cua
   tai khoan nhan.

Khong commit file `.env`, App Password, Firebase keys hay credentials vao Git.

## Cho gan day va chi duong

### Theo doi farmer va thong bao trong ung dung

Chay mot lan `database/farmer_followers.sql` tren database `harvesthub`. Bang
`farmer_followers` luu moi quan he theo doi duy nhat giua farmer va customer;
API cap nhat `farmers.follower_count` cung transaction. Khach hang theo doi
farmer tai `GET/POST/DELETE /api/farmers/{id}/follow`; farmer lay danh sach tai
`GET /api/farmer/following`. Farmer gui thong bao in-app den nhom follower tai
`POST /api/farmer/announcements`; khach hang doc va danh dau thong bao qua
`/api/customer/notifications`. API kiem tra Firebase UID va role o moi request.
Migration cung tao `user_fcm_tokens`; app tu dang ky/huy token tai
`POST/DELETE /api/devices/fcm-token`.
Push duoc gui qua FCM HTTP v1. Tao service account rieng co quyen Firebase
Cloud Messaging Admin, luu JSON ben ngoai web root/repository va dat
`FCM_PROJECT_ID`/`FCM_SERVICE_ACCOUNT_PATH` trong `.env`. Server cap OAuth
access token tu service account; private key khong duoc dua len app. Neu chua
co credentials hoac follower chua dang ky device token, thong bao in-app van
duoc luu va API tra trang thai push rieng.

Tren Firebase Console > Project settings > Service accounts, tao private key
cho service account rieng; gan role `Firebase Cloud Messaging Admin` toi thieu
can thiet va dam bao Firebase Cloud Messaging API duoc bat trong Google Cloud.
Khong dat JSON trong `backend_php/public` hoac commit vao repository. Vi du
duong dan Windows trong `.env`:

```dotenv
FCM_PROJECT_ID=your-firebase-project-id
FCM_SERVICE_ACCOUNT_PATH=C:/secure/firebase/harvesthub-fcm-service-account.json
```

Tren Android, Firebase phai duoc cau hinh cho dung project trong
`android/app/google-services.json`. App xin quyen notifications, dang ky FCM
token theo user dang nhap, hien notification khi app dang mo va mo hop thu khi
nguoi dung cham vao notification. De build iOS, can them Firebase iOS app,
FlutterFire options va cau hinh APNs key trong Firebase Console.

- `GET /api/nearby-markets?latitude=...&longitude=...&radius=10000` tim cho
  trong MySQL (ban kinh tinh bang met).
- Neu ten cho hien dau `?`/ky tu loi, chay `database/fix_market_utf8.sql` mot
  lan trong phpMyAdmin. Migration doi charset bang sang `utf8mb4` va upsert lai
  bon cho mau Can Tho de phuc hoi chu Viet. Viec doi charset don thuan khong
  khoi phuc duoc ky tu da bi thay thanh `?`; cac ban ghi OSM se duoc nhap lai
  tu Overpass bang `php bin/sync_markets.php`.
- File seed `database/nearby_markets_cantho.sql` dung `SET NAMES utf8mb4` va
  upsert, nen co the chay lai de sua du lieu mau bi loi ma khong tao ban ghi
  trung.
- Cai dat OSRM tren cung server hoac mang noi bo va dat `OSRM_BASE_URL` trong
  `.env` (mac dinh `http://127.0.0.1:5000`). PHP proxy endpoint
  `GET /api/route?from_lat=...&from_lng=...&to_lat=...&to_lng=...` va tra
  GeoJSON route OSRM cho Flutter; khong mo cong OSRM truc tiep ra Internet.
- Dung `php bin/sync_markets.php` de dong bo chợ tu Overpass vao bang
  `farmers_market`. Script dung ID `osm_<type>_<id>` de khong trung voi cac
  cho da co va chi upsert du lieu, khong xoa du lieu cu neu Overpass khong tra
  ve day du. Overpass public co the timeout voi truy van toan quoc; neu gap loi,
  chay lai vao thoi diem khac hoac dat `OVERPASS_URL` den instance rieng.
- Tren Linux, co the len lich dong bo hang tuan bang cron:

```cron
0 3 * * 0 cd /path/to/backend_php && php bin/sync_markets.php
```

### Khach hang: don hang, wishlist, ho so va chatbot

Sao luu database truoc, sau do chay mot lan `database/customer_wishlist.sql`
tren `harvesthub`. Migration tao `customer_wishlist` va rang buoc moi review
duy nhat theo don/san pham/khach hang. Neu bang `reviews` da co review trung
theo ba cot nay, can xu ly du lieu trung truoc khi them unique index.

API khach hang xac minh Firebase UID va quyen customer tren server:

- `GET /api/orders?status=` va `GET /api/orders/{id}` chi doc don cua UID dang
  nhap. `PATCH /api/orders/{id}/cancel` chi huy don `Pending` va giai phong
  cho trong slot nhan hang neu co.
- `POST /api/reviews` chi chap nhan danh gia san pham thuoc don `Completed`
  cua khach hang; rating farmer duoc tinh lai tu bang `reviews`.
- `GET/POST/DELETE /api/wishlist` luu/xoa san pham trong wishlist tren MySQL.
- `GET /api/users/me` va `PATCH /api/users/me` tra/cap nhat ho so theo UID.
  Avatar chi nhan download URL Firebase Storage nam trong `avatars/{uid}/`.
  Storage Security Rules can gioi han ghi vao thu muc UID cua user da dang nhap.
- `GET /api/farmers/{id}` tra ho so farmer va danh gia; `GET /api/products?farmer={id}`
  chi tra san pham dang ban, khong bi an va chua xoa.
- `PATCH /api/customer/notifications/read-all` danh dau thong bao cua UID hien
  tai da doc.
- `POST /api/chatbot/message` truy van du lieu san pham, farmer, cho va slot
  nhan hang hien co truoc khi gui context cho AI. Can cau hinh `AI_API_URL`,
  `AI_API_KEY`, `AI_MODEL`; endpoint tra loi 503 ro rang neu AI chua duoc cau
  hinh.

Danh sach theo doi va wishlist hien chi hoat dong online. Don nhap offline,
outbox review va them nhanh vao gio chua duoc bat vi module cart/offline cua
Nguoi 2 chua co trong workspace; app khong tao du lieu mau hay hien thanh cong
gia.
