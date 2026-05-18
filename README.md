# Quote On The Go - Mobile App

A Flutter mobile companion app for the Quote On The Go SaaS platform, supporting both iOS and Android.

## Features

- **Authentication**: Email/password and Google Sign-In
- **Dashboard**: Real-time KPIs and business overview
- **Quotations**: List, view, and manage quotations
- **Invoices**: List, view, and manage invoices
- **Customers**: Customer directory with details
- **Offline Support**: Firestore offline persistence enabled
- **Real-time Sync**: Live updates from Firestore

## Tech Stack

- **Framework**: Flutter 3.x (Dart)
- **Backend**: Firebase (Auth, Firestore, Storage, Messaging)
- **State Management**: Riverpod with code generation
- **Routing**: GoRouter
- **Data Models**: Freezed with JSON serialization
- **UI**: Material 3 design system

## Project Structure

```
lib/
├── models/              # Freezed data models
├── providers/           # Riverpod state management
├── repositories/        # Data access layer
├── router/              # GoRouter configuration
├── screens/             # UI screens
│   ├── auth/           # Login & Register
│   ├── dashboard/      # Dashboard
│   ├── quotations/   # Quotations list & detail
│   ├── invoices/      # Invoices list & detail
│   └── customers/     # Customers list & detail
├── services/           # Firebase services
├── theme/              # App theming
└── main.dart           # Entry point
```

## Getting Started

### Prerequisites

1. **Flutter SDK** (3.6.0 or higher)
   ```bash
   flutter --version
   ```

2. **Firebase Project** 
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Enable Authentication (Email/Password and Google)
   - Enable Cloud Firestore
   - Enable Firebase Storage

3. **FlutterFire CLI**
   ```bash
   dart pub global activate flutterfire_cli
   ```

### Setup

1. **Install dependencies**
   ```bash
   cd qotg-mobile
   flutter pub get
   ```

2. **Configure Firebase**
   ```bash
   flutterfire configure
   ```
   This will generate the `lib/firebase_options.dart` file.

3. **Generate code** (Freezed models and Riverpod providers)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

### Build for Production

**Android:**
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

## Firebase Setup Details

### Firestore Rules

The mobile app uses the same Firestore collections as the web app:

- `users` - User profiles
- `companies` - Company data
- `quotations` - Quotation documents
- `invoices` - Invoice documents
- `customers` - Customer records
- `services` - Service catalog
- `expenses` - Business expenses

### Authentication

- Email/Password authentication
- Google Sign-In (requires Google Cloud OAuth configuration)

### Multi-Tenancy

All data is scoped by `companyId` - the app automatically filters all queries by the current user's company.

## Code Generation

This project uses code generation for:

- **Freezed models** (`*.freezed.dart`, `*.g.dart`)
- **Riverpod providers** (`*.g.dart`)
- **GoRouter** (if using typed routes)

To regenerate:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

For watch mode during development:
```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

## Architecture

### Repository Pattern
- Firestore operations are abstracted in repository classes
- Repositories are provided via Riverpod
- Business logic stays in providers, UI remains pure

### State Management
- `auth_provider.dart` - Authentication state
- `quotation_provider.dart` - Quotations data
- `invoice_provider.dart` - Invoices data
- `customer_provider.dart` - Customers data

### Routing
- GoRouter handles navigation
- Auth redirects automatically (unauthenticated users go to login)
- ShellRoute for bottom navigation

## Troubleshooting

### Build errors

1. **Missing generated files**: Run `flutter pub run build_runner build`

2. **Firebase not configured**: Run `flutterfire configure`

3. **iOS build issues**: Ensure CocoaPods is installed:
   ```bash
   cd ios && pod install
   ```

### Runtime errors

1. **Firebase Auth errors**: Check Firebase Console authentication settings

2. **Firestore permission errors**: Verify Firestore rules allow read/write for authenticated users

3. **Google Sign-In fails**: Check OAuth 2.0 client IDs in Google Cloud Console

## Development

### Adding a New Screen

1. Create screen file in `lib/screens/`
2. Add route in `lib/router/app_router.dart`
3. Add navigation bar item in `lib/screens/shell_scaffold.dart` (if needed)

### Adding a New Model

1. Create file in `lib/models/`
2. Add `@freezed` annotation
3. Run code generation
4. Export from `lib/models/models.dart`

### Adding a New Provider

1. Create file in `lib/providers/`
2. Use `@riverpod` or `@Riverpod` annotations
3. Run code generation
4. Export from `lib/providers/providers.dart`

## License

Same as the main Quote On The Go project.

## Support

For issues or questions, refer to the main project documentation.
