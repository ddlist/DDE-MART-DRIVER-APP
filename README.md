# DDE-Mart Driver App

The driver Flutter app for the DDE-Mart platform: job inbox across food,
parcel, rental and ride work, GPS tracking, payouts, documents and SOS —
against one backend API.

- Backend: [DDE-MART-BACKEND](https://github.com/ddlist/DDE-MART-BACKEND) (`master`)
- API reference: `admin-panel/docs/api-v1.md` (Driver app section)

## Features

- **Auth** — OTP sign-in (`role=driver`), availability toggle, profile
  with vehicle info, sign out.
- **Jobs** — my-jobs + open pool, job detail (fare hero, bill, timeline),
  pool accept, machine moves (accepted → ongoing → completed) for every
  job type.
- **Tracking** — GPS position pings during active work.
- **Payouts** — history + requests (bank/paypal/stripe/razorpay/
  flutterwave/cash).
- **Documents** — verification document upload with review status.
- **Chat & SOS** — order threads with reply, SOS with GPS auto-fill.
- **Platform** — launch gate (`/app-config`), FCM push (`drivers`
  topic), dark mode, runtime permission flows (location, photos,
  notifications).

## Setup

Prerequisites: Flutter 3.41+ (`flutter doctor` clean), Android Studio or
Xcode, and the backend running (see backend README).

```sh
git clone https://github.com/ddlist/DDE-MART-DRIVER-APP.git driver
cd driver
flutter pub get
```

## Run

```sh
# Herd/Valet domain (default baked into lib/core/config.dart):
flutter run --dart-define=API_BASE_URL=http://dde-mart-admin.test/api/v1

# Android emulator when .test doesn't resolve there:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

# Physical phone (same Wi-Fi; backend on 0.0.0.0:8000):
flutter run --dart-define=API_BASE_URL=http://<pc-lan-ip>:8000/api/v1
```

Test accounts: create the driver in the admin panel (Drivers page,
status `active`, kind `delivery`), then sign in with phone + OTP. Demo
OTP codes appear in the backend log outside production. Seed demo data
with `php artisan db:seed --class=DemoSeeder` (driver `0301111111`).

## Release build

```sh
flutter build appbundle --dart-define=API_BASE_URL=https://api.your-domain.com/api/v1
flutter build ipa      --dart-define=API_BASE_URL=https://api.your-domain.com/api/v1
```

Push needs `google-services.json` / `GoogleService-Info.plist` per
environment (see `FIREBASE_SETUP.md`) — never committed.

## Verify

```sh
flutter analyze   # clean
flutter test      # 11 tests: job machine, media API, nav guards, boot
```

## Support

Installation, tech support, customization: **shariqq.com@gmail.com** ·
WhatsApp **@shareeq9**.

## Credits

Built by [DDLIST](https://ddlist.github.io).
