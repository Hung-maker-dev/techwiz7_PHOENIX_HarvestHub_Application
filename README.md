# HarvestHub Mobile — Người 1 (Hạ tầng dùng chung, Auth, trang tĩnh)

Triển khai đúng theo spec "Người 1": token & theme, i18n, router, thư viện
widget dùng chung, và 6 màn hình (1.1 → 1.6).

## Cài đặt

```bash
flutter pub get
flutterfire configure   # sinh lib/firebase_options.dart, sau đó bỏ comment
                         # dòng import + options trong lib/main.dart
flutter run --dart-define=API_BASE_URL=https://your-api.example.com
```

## Ban do va cho gan day

Trang `/nearby-markets` lay vi tri GPS, truy van cac cho dang hoat dong trong
MySQL, hien thi tren nen OpenStreetMap va ve tuyen duong OSRM ngay tren ban do
khi chon mot cho. Android da khai bao quyen vi tri va Internet.

De chay duoc luong nay, can:

1. Chay backend PHP/MySQL theo huong dan trong `backend_php/README.md`.
2. (Tuy chon) Chay `php bin/sync_markets.php` trong thu muc `backend_php` de
   nhap them du lieu tu Overpass.
3. Cau hinh `OSRM_BASE_URL` trong `backend_php/.env` den instance OSRM co the
   truy cap tu PHP server.
4. Cau hinh `API_BASE_URL` cua Flutter den PHP API; khong goi OSRM truc tiep
   tu ung dung.

## Farmer

Farmer da duoc phe duyet duoc dieu huong den `/farmer/dashboard`; cac tai
khoan khac khong the truy cap khu vuc nay. Cac man san pham, don hang, khung
gio nhan hang, bao cao, danh gia, thong bao va ho so trang trai dung Firebase
ID token hien co, backend lay farmer tu UID dang nhap va chi cho phep thao tac
tren du lieu cua farmer do. API san pham ho tro anh JPEG/PNG/WebP toi da 5 MB,
luu trong `backend_php/public/uploads/products`.

Khach hang co the theo doi/huy theo doi farmer tai `/customer/farmers` va xem
thong bao trong app tai `/customer/notifications`. Farmer xem danh sach follower
va gui thong bao den nhom nay trong tab Cong dong. Thong bao duoc luu vao bang
`notifications` va hien trong app; backend cung gui FCM push den cac thiet bi
da dang ky. De bat FCM push, tao service account rieng co quyen Firebase Cloud
Messaging Admin, luu file JSON ben ngoai web root/repository, va dat
`FCM_PROJECT_ID` cung `FCM_SERVICE_ACCOUNT_PATH` trong `backend_php/.env`.
Khong gui/commit private key. Neu chua cau hinh FCM, thong bao in-app van duoc
luu va UI hien ro trang thai push.

Truoc khi dung tinh nang, chay `database/farmer_followers.sql` trong phpMyAdmin.
Migration tao bang lien ket farmer-customer va token FCM, rang buoc khoa ngoai,
va dong bo lai `farmers.follower_count` theo du lieu theo doi.

## Khach hang — tai khoan va hau mai

Các route `/orders`, `/orders/:id`, `/wishlist`, `/following`, `/farmers/:id`,
`/account/profile`, `/notifications` va `/shop` dung API PHP that va bi gioi
han theo role customer. De bat wishlist, sao luu database truoc roi chay
`backend_php/database/customer_wishlist.sql` mot lan tren `harvesthub`.
Migration tao bang wishlist va rang buoc review khong trung theo don/san
pham/UID; neu da co review trung, can xu ly truoc khi them unique index.

Thong tin don hang, farmer, ton kho, san pham va thong bao lay tu MySQL. Anh
ho so duoc tai len Firebase Storage duoi `avatars/{uid}/`; Storage Security
Rules can chi cho UID dang nhap ghi vao thu muc cua chinh ho. Chatbot yeu cau
cau hinh dich vu AI trong `backend_php/.env`; khi chua cau hinh, API bao loi
thay vi tao cau tra loi/du lieu gia.

Firebase Storage Rules toi thieu cho avatar (them vao rules hien tai, giu
cac rules khac cua du an):

```text
match /avatars/{uid}/{fileName} {
  allow read: if true;
  allow write: if request.auth != null
    && request.auth.uid == uid
    && request.resource.size < 5 * 1024 * 1024
    && request.resource.contentType.matches('image/(jpeg|png|webp)');
}
```

Theo doi, wishlist va chatbot can mang. Cac phan phu thuoc module Nguoi 2 —
gio hang/add-to-cart, don nhap offline va outbox review — chua co trong
workspace nen duoc neu ro trong UI; chua co enqueue hay dong bo nen. Khong can
cau hinh FCM moi cho cac man nay; push notification customer van dung thiet lap
FCM rieng o tren.

## Cấu trúc đã tạo

```
lib/
  core/
    theme/        app_colors.dart, app_theme.dart, app_motion.dart
    router/       app_router.dart (go_router, route transition dùng chung)
    network/      dio_client.dart (Dio + interceptor gắn Firebase ID token)
    auth/         auth_repository.dart (email/password, Google, /api/auth/sync)
    providers/    app_providers.dart (theme mode, connectivity)
  l10n/           vi.json, en.json (khoá common.*)
  shared_widgets/ 16 widget dùng chung theo mục B của spec
  features/common/
    landing_page.dart          1.1  route /
    login_page.dart            1.2  route /auth (chứa cả 2 form login/register)
    register_page.dart         1.2  RegisterForm — nội dung form đăng ký
    forgot_password_page.dart  1.3  route /auth/forgot-password
    about_page.dart            1.4  route /about
    contact_page.dart          1.5  route /contact
    faq_page.dart              1.6  route /faq
  app.dart          MaterialApp.router, mount ToastOverlay + OfflineBanner
  main.dart         khởi tạo Firebase + EasyLocalization + ProviderScope
```

## Quyết định kỹ thuật đáng chú ý

- **`/auth` là một route duy nhất** cho cả đăng nhập và đăng ký, chuyển đổi
  bằng `AnimatedSwitcher` crossfade 150ms trong `login_page.dart`, đúng theo
  mô tả mục 1.2 (không tách thành 2 route riêng).
- **Lỗi Firebase được map sang khoá i18n** (`_mapFirebaseError` trong
  `auth_repository.dart`) trước khi hiển thị — không bao giờ lộ mã lỗi gốc
  (`wrong-password`, `email-already-in-use`...) cho người dùng.
- **Quên mật khẩu luôn phản hồi cùng một thông điệp** bất kể email có tồn
  tại hay không, kể cả khi Firebase trả `user-not-found` (chống dò email).
- **ToastOverlay và OfflineBanner chỉ mount một lần** ở `app.dart` (trong
  `builder:` của `MaterialApp.router`), không lặp lại ở từng màn hình.
- Toàn bộ animation dùng đúng token trong `app_motion.dart` — không
  hard-code `Duration`/`Curve` trong feature code.

## Còn cần tích hợp sau (thuộc phạm vi người khác / bước sau)

- `lib/firebase_options.dart` (sinh bằng `flutterfire configure`, chưa có
  vì phụ thuộc project Firebase thật).
