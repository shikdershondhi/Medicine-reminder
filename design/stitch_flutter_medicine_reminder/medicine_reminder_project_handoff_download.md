# Medicine Reminder Flutter Project Handoff

## Overview

This document describes the hand‑off for a **Medicine Reminder** Flutter application.  The project should be built for Android and iOS using Flutter.  Users authenticate with Google SSO, store their data in a custom file in their Google Drive, manage doctor prescriptions and medicines, and receive reminders and alarms to take their medication.  All code should be generated using **codex** via the **agy** CLI for Google Stitch.

## Authentication & Permissions

### Google Sign‑In (SSO)

Use the `google_sign_in` plugin alongside Firebase Authentication to implement Google SSO.  Firebase’s federated identity flow sets up most of the configuration automatically.  You must enable the **Google** provider in the Firebase console and configure the SHA‑1 fingerprint for Android【504704722438479†L1528-L1535】.  On native platforms (Android and iOS) a third‑party library is required to trigger the authentication flow; the official `google_sign_in` plugin is recommended【504704722438479†L1542-L1549】.  The sign‑in flow typically:

```dart
// Import the plugin
import 'package:google_sign_in/google_sign_in.dart';

Future<UserCredential> signInWithGoogle() async {
  // Trigger the Google authentication flow
  final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

  // Obtain the auth details from the request
  final GoogleSignInAuthentication googleAuth = await googleUser!.authentication;

  // Create a credential using the obtained token
  final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);

  // Sign in to Firebase with the credential
  return await FirebaseAuth.instance.signInWithCredential(credential);
}
```

Once a user signs in, request additional scopes for Google Drive access (see below).  After sign‑out, revoke the Drive scope token.

### Google Drive Permissions & Scopes

The app stores user data in the user’s Google Drive so that it persists across reinstallations.  For security and user trust, request the **non‑sensitive** `drive.file` scope, which allows the app to create new Drive files or modify existing files that the user explicitly opens or shares with the app【41848920796985†L427-L429】.  The `drive.file` scope is easier to verify and lets users control which files the app can access【41848920796985†L515-L538】.  Avoid restricted scopes such as `drive` or `drive.readonly` unless absolutely necessary; these require extra verification【41848920796985†L456-L470】.

#### Application Data Folder (optional)

Google Drive provides an **application data folder** (`appDataFolder`) that’s hidden from the user and created automatically when your app first writes to it.  Only the app that created the data can access this folder【302334968361213†L340-L363】.  However, the folder is deleted when the user uninstalls the app【302334968361213†L345-L347】 and cannot be accessed through the Drive UI.  Because users must be able to restore data after reinstalling and manage their own backup files, this project should **not** use the application data folder by default.  Instead, create a file in the user’s Drive using the `drive.file` scope.  If you opt to support the hidden folder as an advanced backup option, remember that you must request the `drive.appdata` scope【302334968361213†L350-L353】 and that files inside the folder can’t be shared, moved or trashed【302334968361213†L370-L386】.  To create a file in the `appDataFolder`, set `parents: ['appDataFolder']` when calling `files.create`【302334968361213†L388-L396】.

## Data Model

The medicine reminder app needs to track user information, prescriptions and medicines.  Persist this data locally (e.g. using the `isar` or `hive` database) and serialize it to a JSON file for Drive backup.  Suggested model classes:

| Entity                 | Fields / Description |
|------------------------|----------------------|
| `UserProfile`          | `name`, `sex`, `weight`, `age` |
| `DoctorPrescription`   | Unique ID; `prescriptionName`; `doctorName`; `visitDate` (DateTime); `visitNumber` (String/Int) |
| `Medicine`             | Unique ID; `prescriptionId` (foreign key); `medicineNumber`; `medicineName`; `intakePerDay` (number of doses per day); `beforeEating` (bool); `afterEating` (bool); `durationDays`; `notes` (String); `advice` (String) |
| `MedicineTracking`     | Unique ID; `medicineId`; `startDate`; `daysTaken`; `daysRemaining` – computed as `durationDays - daysTaken` |

The JSON file stored in Drive should contain arrays of prescriptions and medicines linked by their IDs.  Keep the schema versioned to handle migrations.

## User Flow & Features

### 1 – Login & On‑boarding

1. **Google SSO login** – On first launch, prompt the user to sign in with Google.  After sign‑in, request `drive.file` scope to allow file access.  Persist the user’s basic profile locally.
2. **Permissions** – Ask for notification/alarms permissions.  Provide clear justifications to the user.
3. **Check for existing backup** – After login, use the Drive API to search for an existing backup file (e.g. named `medicine_reminder_backup.json`).  If found, download and merge data into the local database; if not, create a new blank file.

### 2 – User Profile

* Allow the user to view and edit their profile: name, sex, weight and age.  Validate inputs.
* Provide a **Dark Mode** toggle in settings; implement using Flutter’s `ThemeMode`.
* Include a **logout** option that signs out from Firebase and revokes Drive access.

### 3 – Doctor Prescriptions

* Display a list of prescriptions with a “Add” button.
* When adding a prescription, request:
  1. **Prescription name** (e.g. “Dr. Ahmed – March 2026”).
  2. **Doctor’s name**.
  3. **Visit date** (date picker) and **visit number**.
* Save the prescription locally and sync to Drive.
* Support editing and deleting prescriptions.

### 4 – Medicines

Inside each prescription, users can add multiple medicines.  For each medicine, collect:

* **Medicine number** and **name**.
* **Intake per day** – how many times to take the medicine daily.
* **Before/After eating** – booleans or enumeration (before, after, or unspecified).
* **Duration in days** – how long the course lasts.
* **Notes** – optional free‑text notes.
* **Advice** – additional doctor’s advice.

Automatically create `MedicineTracking` entries when a medicine is added.  As the user marks doses as taken (see reminders), increment `daysTaken` and recompute `daysRemaining`.  Provide a progress indicator.

### 5 – Medicine Tracking

* In the **Dashboard**, show upcoming doses and progress:
  * A list of medicines that need to be taken today with times.
  * Progress bars indicating how many days remain for each medicine.
* Allow the user to mark each scheduled dose as **taken**.  This updates the tracking record and recalculates days remaining.
* Provide a **sync** button on the dashboard to upload local changes to Drive and download any remote changes.

### 6 – Reminders & Notifications

Use the `flutter_local_notifications` plugin to schedule notifications.  This plugin supports scheduling notifications at specified times, repeating notifications (daily or weekly), retrieving pending notifications, and cancelling them【644574872089496†L142-L153】.  For example, to schedule daily reminders for a medicine at 8 am and 8 pm, schedule two notifications with distinct IDs.  The plugin also lets you handle notification taps so you can mark a dose as taken.

For louder alarms, use the `alarm` plugin.  It provides a native interface to set alarms with custom audio, vibration and full‑screen intents【753234786332966†L65-L70】.  Initialize the alarm service in your `main()` function (`await Alarm.init()`) and define `AlarmSettings` specifying the `dateTime`, audio file and notification settings【753234786332966†L103-L139】.  When the alarm fires, show a high‑priority notification and optionally open the app to the medicine detail page.

### 7 – Synchronization Workflow

1. **Initial sync** – On login or when the user presses the sync button, search the user’s Drive for the backup file using the `drive.file` scope.  If found, download it and merge with local data.
2. **Uploading changes** – Serialize the local data model to JSON and update the backup file using `files.update` with `uploadType=multipart`.  Include a timestamp in the metadata.
3. **Conflict resolution** – Compare timestamps; if the remote file is newer than local data, prompt the user to overwrite local data or keep local changes.
4. **Automatic periodic sync** – Optionally schedule background sync using `workmanager` or platform‑specific background tasks.

## UI & Design Considerations

1. **Responsive layouts** – Support both phones and tablets.  Use `LayoutBuilder` or `MediaQuery` to adjust UI.
2. **Navigation** – Use `Navigator 2.0` or `go_router` to manage routes: Login → Dashboard → Prescription List → Medicine List → Medicine Detail.
3. **Dark Mode** – Provide light and dark themes and allow the user to toggle in settings.
4. **Accessibility** – Ensure sufficient color contrast, larger tap targets, and semantics labels for screen readers.
5. **Scan feature** – If implementing a “Scan” feature (e.g., scanning prescription images), integrate with `flutter_barcode_scanner` or `google_mlkit_text_recognition` to parse text and pre‑fill medicine data.

## Tasks for Codex via Agy CLI

The code agent should scaffold the project and implement the following tasks.  Suggested steps (you may adapt based on `agy` commands):

1. **Project setup**
   * Initialize a new Flutter project: `agy new medicine_reminder --org com.example --template app`.
   * Add dependencies in `pubspec.yaml`:
     * `firebase_core`, `firebase_auth`, `google_sign_in` for authentication.
     * `googleapis` or `googleapis_auth` to interact with Drive.
     * `isar` or `hive` for local persistence.
     * `flutter_local_notifications` for scheduling notifications.
     * `alarm` for alarm functionality.
     * `provider` or `riverpod` for state management.

2. **Authentication module**
   * Configure Firebase for Android/iOS and enable Google sign‑in.
   * Implement the `signInWithGoogle()` function shown above and expose it via a provider.
   * Request `drive.file` scope after initial sign‑in and store the obtained refresh token securely (e.g. using `flutter_secure_storage`).

3. **Drive integration**
   * Implement a service class that uses the Drive API to search, create, download and upload the backup file.  Use the `drive.file` scope; avoid broader scopes.【41848920796985†L427-L431】
   * Provide methods: `initBackupFile()`, `downloadBackup()`, `uploadBackup(data)`, `listBackupFiles()`.

4. **Local data layer**
   * Define the model classes and type adapters for the local database.
   * Implement CRUD operations for prescriptions, medicines and tracking entries.

5. **Synchronization logic**
   * On app launch and when the user presses “Sync”, call the Drive service to retrieve the remote file and merge with local data.
   * After local changes (e.g. adding a medicine or marking a dose), schedule an upload.

6. **UI implementation**
   * Build screens for login, profile, prescription list/form, medicine list/form, dashboard, settings.
   * Use `ListView` and `Card` widgets to display prescriptions and medicines.
   * Provide dialogs for confirmation (e.g. delete prescription) and conflict resolution.

7. **Reminders & alarms**
   * Integrate `flutter_local_notifications` to schedule notifications at intake times.  Use the `tzdata` package to handle time zones.
   * For each medicine, compute the notification schedule based on intake per day and start/end dates and register notifications.  Make sure to cancel notifications when a medicine course ends or is deleted.
   * Integrate the `alarm` plugin to trigger full‑screen alarms if the user enables this option.  Initialize the service in `main()` and call `Alarm.set()` with appropriate `AlarmSettings`【753234786332966†L103-L139】.

8. **Settings & extras**
   * Implement dark mode toggling and persistence (e.g. using `shared_preferences`).
   * Provide a scanning feature using a text recognition plugin (optional).  Parse scanned text into medicine entries.

## Security & Compliance

* **Least‑privilege** – Use only the `drive.file` scope to minimize access to the user’s Drive【41848920796985†L515-L538】.  Never request full Drive access unless you meet Google’s restricted‑scope verification requirements.
* **Data privacy** – Store sensitive tokens using secure storage.  Encrypt local database files if they contain personal health information.
* **Error handling** – Gracefully handle network errors, authentication failures and Drive quota errors.  Provide user feedback and allow retry.
* **Offline support** – Users should be able to access and update data without connectivity.  Queue sync operations until a network connection is available.

## Illustrative Concept

Below is a conceptual illustration of the medicine reminder app showing a smartphone with pill icons, medicine bottle, and calendar notifications.

![Medicine reminder concept]({{file:file-5f1oodUKHgFdXoWfx8hBvQ}})

---

This hand‑off outlines the expected functionality, data structures and implementation plan for the Medicine Reminder Flutter app.  Follow the tasks above using the **agy** CLI and **codex** to generate the project, implement the authentication and Drive integration, build the user interface, and schedule notifications and alarms.