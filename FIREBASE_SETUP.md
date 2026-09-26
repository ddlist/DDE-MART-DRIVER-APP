# Firebase setup — DDE Driver

Push code is wired (`lib/core/push.dart`, topic `drivers`, token at
`POST /driver/push-tokens` after sign-in). Only native config is missing.

1. Firebase project: Android app `com.ddemart.dde_driver`
   (iOS bundle ID identical). May share the project with customer/vendor.
2. `google-services.json` → `android/app/`;
   `GoogleService-Info.plist` → `ios/Runner/` (add to Xcode).
3. No Dart changes. Without the files, push skips gracefully.
4. Test: sign in → place a parcel/ride via the customer app or panel →
   driver gets the broadcast → accept it in Jobs.
