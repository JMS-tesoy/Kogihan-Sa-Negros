# Land Finder (Kogihan Sa Negros)

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=flat&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)

## Project Overview

Land Finder is a Flutter-based mobile application prototype designed to help users browse, filter, and save real estate property listings. The app focuses on properties in the Negros region (Philippines), providing a localized experience with features like search, filtering by location, lot size, and budget, and a personal saved properties list.

## Screenshots

> *[Add screenshots or GIFs of your app here to demonstrate the UI/UX]*

## Features Implemented

- 🏠 **Property Listing**: Displays a list of mock property listings.
- 🔍 **Search Functionality**: Users can search properties by title, location, or price.
- 🎛️ **Filtering**: Filter properties by:
  - Location (e.g., Cagayan de Oro City, Bukidnon)
  - Lot Size (e.g., Below 500 sqm, 500 - 1000 sqm, Above 1000 sqm)
  - Budget (e.g., Below ₱1M, ₱1M - ₱3M, Above ₱3M)
- ℹ️ **Property Details**: View detailed information for each property.
- ❤️ **Save/Unsave Properties**: Users can mark properties as favorites, which are then listed in the "Saved" tab.
- 👤 **Profile Tab**: A placeholder for user profile information and settings.
- ⚙️ **Settings Page**: Basic settings with toggle switches for notifications, dark mode (currently not functional), and location services.
- 📱 **Responsive UI**: Designed with Flutter's Material Design principles for a consistent look and feel.

## Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK**: [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Dart SDK**: Comes with Flutter.
- **Git**: [Install Git](https://git-scm.com/downloads)
- **IDE**: Visual Studio Code with the Flutter extension, or Android Studio with the Flutter and Dart plugins.

### Installation

1. **Clone the repository:**
   ```bash
   git clone git@github.com:JMS-tesoy/flutter_application_1.git
   cd flutter_application_1
   ```

2. **Get Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Check for any missing dependencies or setup issues:**
   ```bash
   flutter doctor
   ```
   Address any issues reported by `flutter doctor` before proceeding.

## Running the Project

### Development Mode

To run the application in development mode on a connected device or emulator:

```bash
flutter run
```

This command will compile the app and launch it. It also enables hot reload, allowing you to see changes instantly as you modify the code.

### Dart MCP and Flutter MCP Notes

This repo can be used with both Dart MCP and Flutter MCP.

- **Dart MCP** works without a running app for lightweight tooling actions such as listing available devices.
- **Flutter MCP** needs a running Flutter app session and a valid DTD URI.

#### How to connect Flutter MCP in VS Code

1. Start the app normally on your Android Emulator from VS Code.
2. Open the Command Palette with `Ctrl+Shift+P`.
3. Search for `Copy DTD Uri`.
4. Use `Dart: Copy DTD Uri to Clipboard` or `Flutter: Copy DTD Uri to Clipboard`.
5. Paste that URI into the agent chat so the agent can connect.

Example DTD URI:

```text
ws://127.0.0.1:57358/UCFJOTDqprE=
```

#### What works after Flutter MCP is connected

- Read current runtime errors
- Inspect the widget tree
- Inspect the selected widget
- Hot reload
- Hot restart

#### Important note

The DTD URI is tied to the current running app session. If you stop and rerun the app, copy a new DTD URI before trying to reconnect.

### Specific Commands

- **List available devices:**
  ```bash
  flutter devices
  ```
  Then, run on your desired device (replace `device_id` with the actual ID):
  ```bash
  flutter run -d <device_id>
  ```
- **Build for Android (APK):**
  ```bash
  flutter build apk
  flutter build apk --release --target-platform android-arm64   (for latest android)
  flutter build apk --release --split-per-abi --target-platform android-arm64
  flutter build apk --release --target-platform android-arm64
  ```
- **Build for iOS (IPA - requires macOS):**
  ```bash
  flutter build ios
  ```





### Things to Be Aware Of

- **Hardcoded Data**: Currently, property listings are hardcoded within `lib/main.dart`. For a production application, this data would typically come from an API or a database.
- **Single File Architecture**: The entire application logic and UI are contained within `lib/main.dart`. As the project grows, it's highly recommended to refactor this into a multi-file, modular structure (e.g., `lib/models`, `lib/screens`, `lib/widgets`, `lib/services`).
- **State Management**: The app uses `setState` for local state management. For more complex state, consider adopting a dedicated state management solution like Provider, Riverpod, or BLoC.
- **Placeholder Features**: The "Map" tab is a placeholder. The "Dark Mode" toggle in settings is currently not wired up to change the actual theme.
- **Error Handling**: Minimal error handling is implemented.
- **Testing**: No unit or widget tests are currently included.

### Standard Procedures

1. **Branching**: Always work on a new branch for new features or bug fixes.
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. **Commit Messages**: Write clear and concise commit messages.
   ```bash
   git commit -m "feat: Add search bar functionality"
   ```
3. **Code Formatting**: Ensure your code is formatted correctly before committing.
   ```bash
   flutter format .
   ```
4. **Linting**: Run the linter to catch potential issues.
   ```bash
   flutter analyze
   ```
5. **Pull Requests**: Submit a pull request to `main` for review once your feature is complete and tested.

## License

This project is open-source and available under the MIT License.

---

**Note**: This `README.md` provides a basic overview. For more detailed documentation or specific implementation details, refer directly to the source code.



