# Repository Guidelines

## Project Structure & Module Organization
The project follows a **Feature-based Clean Architecture** organized within the `lib/` directory. Business logic is separated into layers:
- **`lib/features/`**: Contains feature-specific code (presentation, domain, data).
- **`lib/core/`**: Shared utilities, base classes, and core application logic.
- **`lib/shared/`**: Reusable widgets and UI components across features.
- **`lib/app/`**: Global application configuration and routing.
- **`supabase/`**: Contains database migrations and configuration for the backend.

## Build, Test, and Development Commands
Use the following commands for development:
- **Install dependencies**: `flutter pub get`
- **Run application**: `flutter run`
- **Run linter**: `flutter analyze`
- **Format code**: `flutter format .`
- **Run tests**: `flutter test`
- **Build Android (APK)**: `flutter build apk`
- **Build iOS (IPA)**: `flutter build ios` (requires macOS)
- **Code Generation**: `dart run build_runner build --delete-conflicting-outputs` (if applicable)

## Coding Style & Naming Conventions
- **Naming**: `PascalCase` for classes, `camelCase` for variables/functions, and `snake_case` for file names.
- **Formatting**: Enforced by `dart_format`. Keep lines to **80 characters** or fewer.
- **Linter**: Follows `package:flutter_lints/flutter.yaml`. Defined in [./analysis_options.yaml](./analysis_options.yaml).
- **Best Practices**:
  - Favor **composition over inheritance**.
  - Use **const constructors** wherever possible for widget performance.
  - Avoid `print()`; use `dart:developer`'s `log()` or the `logging` package.
  - Ensure null-safe code and avoid the `!` operator unless safety is guaranteed.

## Testing Guidelines
- **Framework**: Uses `flutter_test` (built-in).
- **Organization**: Tests are located in the `test/` directory, mirroring the `lib/` structure.
- **Pattern**: Follow the **Arrange-Act-Assert** pattern for all test cases.

## Commit & Pull Request Guidelines
Follow the **Conventional Commits** pattern seen in the repository history:
- `feat:` for new features.
- `chore:` for maintenance or dependency updates.
- `refactor:` for code restructuring without functional changes.
- `sync:` for database/Supabase migration updates.
- `document:` for documentation changes.
