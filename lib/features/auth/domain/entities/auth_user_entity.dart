class AuthUserEntity {
  const AuthUserEntity({
    required this.id,
    required this.email,
    this.name = '',
  });

  final String id;
  final String email;
  final String name;
}
