class ProfileEntity {
  const ProfileEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.avatarUrl = '',
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String avatarUrl;
}
