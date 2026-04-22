import '../../core/enums/user_role.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.name = '',
    this.role = UserRole.buyer,
  });

  final String id;
  final String email;
  final String name;
  final UserRole role;
}
