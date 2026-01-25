# NurseAssist - Wound Care Assessment Application

A comprehensive Flutter application for wound assessment and management using AI-powered analysis.

## Features

- 🔐 **Firebase Authentication** - Secure staff login with department validation
- 📊 **Patient Management** - Track patients and their wound assessments
- 📷 **Image Capture** - Use camera or gallery to capture wound images
- 🤖 **AI-Powered Analysis** - Automatic wound classification and assessment
- 📋 **Comprehensive Results** - Detailed wound characteristics, treatment recommendations
- ⚕️ **8 Wound Types** - Classification system based on necrotic tissue, infection, and exudate levels
- ✅ **Specialist Confirmation** - Required approval for debridement procedures (Types 3, 4, 6)
- 💾 **Cloud Storage** - All data stored securely in Firebase

## Wound Classification System

### Type 1
- Necrotic tissue/slough < 25%
- No infection
- Dry/minimal exudate
- **Treatment**: Foam, polymeric membrane, island dressing

### Type 2
- Necrotic tissue/slough < 25%
- No infection
- Moderate exudate/wet
- **Treatment**: Foam, alginate, hydrofiber, polymeric membrane

### Type 3 ⚠️
- Necrotic tissue/slough < 25%
- Presence of infection
- Dry/minimal exudate
- **Treatment**: Tulle, hydrogel, hydrocolloid, silver dressing, iodine dressing
- **Requires specialist confirmation for debridement**

### Type 4 ⚠️
- Necrotic tissue/slough < 25%
- Presence of infection
- Moderate exudate/wet
- **Treatment**: Alginate, foam, silver, hydrofiber, polymeric membrane
- **Requires specialist confirmation for debridement**

### Type 5
- Necrotic tissue/slough > 25%
- No infection
- Dry/minimal exudate
- **Treatment**: Hydrogel, hydrocolloid, polymeric membrane, medical grade honey

### Type 6 ⚠️
- Necrotic tissue/slough > 25%
- No infection
- Moderate exudate/wet
- **Treatment**: Alginate, foam, polymeric membrane, hydrofiber
- **Requires specialist confirmation for debridement**

### Type 7
- Necrotic tissue/slough > 25%
- Presence of infection
- Dry/minimal exudate
- **Treatment**: Silver, hydrogel, hydrocolloid, iodine dressing, polymeric membrane

### Type 8
- Necrotic tissue/slough > 25%
- Presence of infection
- Moderate exudate/wet
- **Treatment**: Alginate, hydrofiber, foam, polymeric membrane, iodine, silver, charcoal
- **Note**: Requires combination antimicrobial dressing

## Setup Instructions

### 1. Prerequisites

- Flutter SDK (3.10.7 or higher)
- Firebase account
- Android Studio / Xcode (for emulators)
- VS Code (recommended)

### 2. Firebase Setup

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project named "NurseAssist"
3. Enable the following services:
   - Authentication (Email/Password)
   - Cloud Firestore
   - Storage

#### Configure Firebase for Flutter

**For Android:**
1. Add Android app in Firebase Console
2. Download `google-services.json`
3. Place it in `android/app/`

**For iOS:**
1. Add iOS app in Firebase Console
2. Download `GoogleService-Info.plist`
3. Place it in `ios/Runner/`

**For Web:**
1. Add Web app in Firebase Console
2. Copy the Firebase config
3. Update `web/index.html` with Firebase configuration

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Run the Application

```bash
# For development
flutter run

# For specific platform
flutter run -d chrome  # Web
flutter run -d android # Android
flutter run -d ios     # iOS
```

### 5. Login Credentials

**Sample Staff Account:**
- Staff ID: `AISHA`
- Department: `Nursing`

### 6. AI Model Integration

The app currently uses a mock AI service for demonstration. To integrate a real AI model:

1. **Option A: Use TensorFlow Lite**
   - Train or download a wound classification model
   - Convert to TFLite format
   - Place in `assets/models/`
   - Update `wound_analysis_service.dart`

2. **Option B: Use Cloud API**
   - Train model on Google Cloud AI, Roboflow, or custom service
   - Update `apiEndpoint` in `wound_analysis_service.dart`
   - Implement API authentication

3. **Recommended Models:**
   - MobileNet for wound classification
   - U-Net for wound segmentation
   - Custom CNN trained on wound datasets

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── models/                            # Data models
│   ├── patient.dart
│   ├── staff.dart
│   └── wound_assessment.dart
├── services/                          # Business logic
│   ├── auth_service.dart              # Authentication
│   ├── firestore_service.dart         # Database operations
│   └── wound_analysis_service.dart    # AI analysis
└── screens/                           # UI screens
    ├── login_screen.dart
    ├── dashboard_screen.dart
    ├── patient_list_screen.dart
    ├── patient_profile_screen.dart
    ├── capture_wound_screen.dart
    └── analysis_results_screen.dart
```

## Dependencies

Key packages used:
- `firebase_core` - Firebase initialization
- `firebase_auth` - Authentication
- `cloud_firestore` - Database
- `firebase_storage` - Image storage
- `camera` - Camera functionality
- `image_picker` - Gallery picker
- `tflite_flutter` - TensorFlow Lite (for AI)

## Features in Detail

### Authentication
- Staff login with ID and department
- Persistent sessions
- Secure Firebase authentication

### Patient Management
- View all patients
- Search by name or MRN
- Patient profiles with medical records
- Wound assessment history

### Wound Assessment
- Capture images via camera or gallery
- AI-powered analysis
- Confidence scoring
- Wound segmentation visualization
- Detailed characteristics analysis

### Treatment Recommendations
- Wound type classification (1-8)
- Dressing material suggestions
- Antibiotic recommendations
- Surgical procedure guidance
- Specialist confirmation workflow

### Data Storage
- Cloud-based storage
- Real-time synchronization
- Image storage in Firebase Storage
- Structured Firestore database

## Security Considerations

1. **Firebase Rules** - Configure proper security rules in Firebase Console
2. **Authentication** - Staff credentials should be properly managed
3. **Image Storage** - Implement proper access controls
4. **HIPAA Compliance** - Ensure compliance if used in production

## Future Enhancements

- [ ] Export reports to PDF
- [ ] Multi-language support
- [ ] Offline mode with sync
- [ ] Advanced analytics dashboard
- [ ] Integration with hospital systems
- [ ] Real-time collaboration features
- [ ] Advanced AI models with higher accuracy

## Troubleshooting

### Camera Issues
- Ensure camera permissions are granted
- Check `AndroidManifest.xml` and `Info.plist` for permissions

### Firebase Connection
- Verify Firebase configuration files are in correct locations
- Check internet connectivity
- Ensure Firebase services are enabled in console

### Build Errors
```bash
flutter clean
flutter pub get
flutter run
```

## License

This project is for educational purposes.

## Support

For issues and questions, please refer to the Flutter and Firebase documentation.

