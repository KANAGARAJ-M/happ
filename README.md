# MedicoLegal Records App

A comprehensive medical records management system built with Flutter that enables patients and healthcare providers to securely store, access, and share medical records while maintaining strict privacy controls.

---

## Overview

MedicoLegal Records is a cross-platform application designed to simplify the management of medical records while ensuring data privacy and security. The app provides different interfaces for patients and doctors, allowing healthcare providers to manage patient records while giving patients control over their own medical data.

This app is built using Flutter, making it available on **Android**, **iOS**, **Web**, and **Tablet** platforms. It integrates with Firebase for authentication, data storage, and file management.

---

## Features

### Core Functionality
- **Secure Record Storage**: All records are private and only viewable by the record owner and authorized healthcare providers.
- **Document Scanning**: Scan physical documents using your device camera with text recognition.
- **File Attachments**: Attach various file types (PDF, images, etc.) to medical records.
- **Categorized Records**: Organize records by category (medical, doctor, patient).
- **Tagged Records**: Add custom tags to records for easier searching.
- **Appointments Management**: Request, schedule, and manage medical appointments.

### User Roles
- **Patient Features**:
  - View personal medical records.
  - Schedule appointments with doctors.
  - Upload and manage health documents.
  - View healthcare provider information.

- **Doctor Features**:
  - View patients' profiles and medical records.
  - Add records to patient profiles.
  - Approve/reject appointment requests.
  - Manage patient list.

### UI/UX
- **Modern Interface**: Clean, intuitive design following Material Design principles.
- **Responsive Layout**: Adapts to different screen sizes and orientations.
- **Dark/Light Themes**: Support for both dark and light mode.
- **Dashboard**: Visual summary of records, appointments, and statistics.

---

## Works On

- **Mobile**: Android and iOS devices.
- **Web**: Modern web browsers.
- **Tablet**: Optimized for larger screens.

---

## Installation

### Prerequisites
- Flutter SDK (v3.7.0 or higher).
- Dart SDK.
- Firebase account.
- Android Studio / Xcode (for mobile deployment).
- Connected devices or emulators.

### Getting Started

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/happ.git
   cd happ
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

---

### Firebase Configuration

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/).

2. Enable the following Firebase services:
   - Firebase Authentication (Email/Password).
   - Cloud Firestore.
   - Firebase Storage.

3. Add platforms to your Firebase project:
   - For Android: Register the app with the package name from `AndroidManifest.xml`.
   - For iOS: Register the app with the bundle ID from `Info.plist`.
   - For Web: Register the app and get the configuration.

4. Download the configuration files:
   - `google-services.json` (Android) → Place it in `android/app/`.
   - `GoogleService-Info.plist` (iOS) → Place it in `ios/Runner/`.

5. Update Firestore security rules to match the app's privacy requirements:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;

         match /records/{recordId} {
           allow read: if request.auth != null && (
             request.auth.uid == userId || 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'doctor'
           );
           allow write: if request.auth != null && (
             request.auth.uid == userId || 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'doctor'
           );
         }
       }
     }
   }
   ```

6. For Web, update the `web/index.html` file with Firebase configuration:
   ```html
   <script src="https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js"></script>
   <script src="https://www.gstatic.com/firebasejs/8.10.0/firebase-auth.js"></script>
   <script src="https://www.gstatic.com/firebasejs/8.10.0/firebase-firestore.js"></script>
   <script src="https://www.gstatic.com/firebasejs/8.10.0/firebase-storage.js"></script>

   <script>
     var firebaseConfig = {
       apiKey: "YOUR_API_KEY",
       authDomain: "YOUR_AUTH_DOMAIN",
       projectId: "YOUR_PROJECT_ID",
       storageBucket: "YOUR_STORAGE_BUCKET",
       messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
       appId: "YOUR_APP_ID"
     };
     firebase.initializeApp(firebaseConfig);
   </script>
   ```

---

### Web Deployment

1. Add web support to the Flutter project:
   ```bash
   flutter create --platforms=web .
   ```

2. Build the web version:
   ```bash
   flutter build web
   ```

3. Deploy to Firebase Hosting (optional):
   ```bash
   firebase deploy --only hosting
   ```

---

## Project Structure

```
lib/
  ├── core/
  │   ├── models/            # Data models
  │   ├── providers/         # State management
  │   └── services/          # Business logic
  └── ui/
      ├── screens/           # App screens
      │   ├── auth/          # Authentication screens
      │   ├── doctor/        # Doctor-specific screens
      │   ├── patient/       # Patient-specific screens
      │   └── records/       # Record management screens
      ├── theme/             # App theming
      └── widgets/           # Reusable widgets
```

---

## Usage

### Authentication
- Register as either a patient or doctor.
- Log in with email and password.

### Adding Records
- Use the "+" floating action button on the Records screen.
- Fill in record details and attach documents if needed.
- For doctors: Add records to patient profiles through the patient details screen.

### Document Scanning
- Navigate to the Scan Document screen.
- Take a photo of a document.
- Review the scanned text and save it as a new record.

### Profile Management
- Update personal information.
- View medical history and statistics.

### Appointment Management
- Patients can request appointments with doctors.
- Doctors can approve, reject, or reschedule appointments.

---

## Key Technologies Used

- **Flutter**: Cross-platform framework for building the app.
- **Firebase**: Backend services for authentication, Firestore database, and file storage.
- **Google ML Kit**: For text recognition in scanned documents.
- **Provider**: State management for app-wide data sharing.
- **Dart**: Programming language for Flutter.

---

## Contributing

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/amazing-feature`).
3. Commit your changes (`git commit -m 'Add some amazing feature'`).
4. Push to the branch (`git push origin feature/amazing-feature`).
5. Open a Pull Request.

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.

