# Medicine Reminder (MedTrack) Flutter App

A production-ready personal medicine tracking and reminder mobile application built for Android and iOS. 

MedTrack helps users manage doctor prescriptions, schedule daily medicine reminders and ringing alarms, track medication progress offline, and securely synchronize data to their personal Google Drive storage.

---

## 🛠 Core Tech Stack

*   **Frontend Framework:** Flutter (Latest Stable)
*   **Design System:** Material 3 UI (Theme style: *Clinical Clarity*)
*   **State Management:** Flutter Riverpod
*   **Local Database:** Hive (Offline-first key-value storage)
*   **Authentication:** Firebase Auth + Google SSO Sign-in
*   **Cloud Synchronization:** Google Drive API (Scoped access: `drive.file`)
*   **Notifications:** `flutter_local_notifications`
*   **Alarms:** `alarm` (Full-screen active alarm and vibration)

---

## 📂 Folder Structure (Feature-First Architecture)

The app follows **Clean Architecture** patterns separated into core components and feature-specific structures:

```text
lib/
├── core/
│   ├── services/
│   │   ├── alarm_service.dart          # Alarm scheduling & trigger manager
│   │   ├── auth_service.dart           # Google SSO auth logic + mock fallback
│   │   ├── database_service.dart       # Hive DB database initialization & CRUD
│   │   ├── drive_service.dart          # Google Drive multipart JSON backup sync
│   │   ├── medex_service.dart          # MedEx HTML crawler search and caching
│   │   ├── navigation.dart             # GoRouter routing rules and auth redirects
│   │   ├── ocr_service.dart            # OCR prescription camera scanning interface
│   │   └── providers.dart              # Riverpod StateNotifiers mapping
│   ├── shared/
│   │   └── models.dart                 # Typed data schema (Profile, Prescription, Medicine, Logs)
│   └── theme/
│       └── app_theme.dart              # Light & Dark color systems (Clinical Clarity)
├── features/
│   ├── auth/
│   │   └── login_screen.dart           # Onboarding & Google authentication screen
│   ├── dashboard/
│   │   ├── alarm_ring_screen.dart      # Full-screen bell ringing overlay
│   │   └── dashboard_screen.dart       # Today's schedules list, widgets & adherence stats
│   ├── medicines/
│   │   └── medicine_form_screen.dart   # Add/Edit medicine form + debounced autocomplete
│   ├── prescriptions/
│   │   ├── prescription_detail_screen.dart  # Prescription summary details & track progress
│   │   ├── prescription_form_screen.dart    # Add/Edit doctor prescription details
│   │   └── prescription_list_screen.dart    # Prescription list, search, and sorting
│   ├── profile/
│   │   └── profile_screen.dart         # Onboarding & settings user profile inputs
│   ├── scan/
│   │   └── scan_screen.dart            # Camera viewfinder and verification panel
│   └── settings/
│       └── settings_screen.dart        # General settings, toggles, manual sync & restore
└── main.dart                           # Widgets binding and background services boot
```

---

## ⚡ Quick Start & Run Locally

### 1. Prerequisites
Ensure you have the Flutter SDK installed (`flutter --version` checks version 3.44.0+) and an active simulator or connected physical device.

### 2. Install Dependencies
Get packages locally:
```bash
flutter pub get
```

### 3. Running without Firebase Configs (Local Safe Mock Mode)
If you haven't set up Firebase and Google APIs yet, **the app has a built-in safety fallback**. It will detect the absence of configurations, boot in **Offline Mock Mode**, and simulate Google SSO logins locally. All features (adding prescriptions, checking schedules, notifications, custom alarms) are fully operational locally.

Launch the app:
```bash
flutter run
```

---

## 🔑 Firebase SSO Setup Guide

To configure real Google SSO login, follow these steps:

### 1. Create a Firebase Project
1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Click **Add Project** and name it `Medicine Reminder`.
3. Enable or disable Google Analytics depending on preferences.

### 2. Enable Google Sign-In Provider
1. Navigate to **Build > Authentication** in the sidebar.
2. Under the **Sign-in method** tab, click **Add new provider** and select **Google**.
3. Enable the provider, fill in the support email fields, and click **Save**.

### 3. Register Android App
1. Click the **Android** icon in the project dashboard overview.
2. Enter the Package Name: `com.example.medicine_reminder`.
3. Generate and paste your **SHA-1 Fingerprint**:
    *   **Mac / Linux Developer Key:**
        ```bash
        keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android
        ```
    *   Find the row starting with `SHA1:` and paste it.
4. Download the generated `google-services.json` and place it inside `android/app/`.

### 4. Register iOS App
1. Click **Add App** and select **iOS**.
2. Enter the Bundle ID: `com.example.medicine_reminder`.
3. Download the `GoogleService-Info.plist` and drag it into Xcode inside the `Runner` folder.
4. Add the Custom URL Schema (derived from reversed client ID) to your Info.plist URL types.

---

## ☁️ Google Drive Backup API Setup Guide

MedTrack uses the user's personal Google Drive accounts to sync JSON backups to prevent storage fees and respect data ownership.

### 1. Enable Google Drive API in GCP
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Select your Firebase project from the top dropdown list.
3. Search for **Google Drive API** in the API library and click **Enable**.

### 2. Configure OAuth Consent Screen
1. In the Google Cloud Console, navigate to **APIs & Services > OAuth consent screen**.
2. Select **External** and fill in required app metadata.
3. Under the **Scopes** stage, click **Add or Remove Scopes**.
4. Manually add the following scope:
    *   `https://www.googleapis.com/auth/drive.file`
    *(Note: This is a non-sensitive scope allowing the app to read/write only the files it explicitly creates. It does NOT grant access to the user's other Drive files.)*
5. Add test user emails under the **Test users** section before testing.

---

## 🔒 Permission Specifications

### Android Permissions
Defined inside [AndroidManifest.xml](file:///Users/shikdershondhi/Github/Medicine-reminder/android/app/src/main/AndroidManifest.xml):
- `INTERNET`: For SSO, scraping MedEx, and syncing backups.
- `CAMERA`: For scanning medicine prescriptions.
- `POST_NOTIFICATIONS`: To display notifications on Android 13+.
- `SCHEDULE_EXACT_ALARM` & `USE_EXACT_ALARM`: For exact alarm clocks.
- `RECEIVE_BOOT_COMPLETED` & `WAKE_LOCK`: For rescheduling alarms on restart and waking screen.

### iOS Permissions
Defined inside [Info.plist](file:///Users/shikdershondhi/Github/Medicine-reminder/ios/Runner/Info.plist):
- `NSCameraUsageDescription`: Visual description explaining camera usage for prescription scans.
- `UIBackgroundModes` (audio, fetch): Allows alarm sounds to play when device screen is turned off.