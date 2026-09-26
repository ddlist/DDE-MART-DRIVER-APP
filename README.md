# DDE-Mart driver app (clean-room rebuild)

Fresh Flutter app against `admin-panel` API v1 driver surfaces
(`docs/api-v1.md`, Driver app section). No legacy code.

## Run

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

## What's wired

- Launch gate (`/app-config`, `driver` audience) + maintenance/update screens.
- OTP sign-in (`role=driver`), availability toggle, profile, sign out.
- Jobs: my-jobs + open pool across parcel/rental/ride; accept pool jobs;
  advance owned jobs accepted → ongoing → completed.
- Payouts: history + request (bank/paypal/stripe/razorpay/flutterwave/cash).
- SOS: `POST /driver/sos` (manual coordinates for now).

## Next (not yet)

- GPS location plugin (live coordinates + SOS auto-fill), background
  location for active jobs.
- Document upload (image picker → `POST /driver/documents` multipart).
- Push: `firebase_messaging`, topic `drivers`, token at `POST /push-tokens`.
- Firebase native files per environment (not in repo).

## Verify

```sh
flutter analyze
flutter test
```
