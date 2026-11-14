class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id']?.toString() ?? '',
      fullName: (map['full_name'] ?? '').toString().trim(),
      email: (map['email'] ?? '').toString().trim(),
      role: (map['role'] ?? 'user').toString().trim(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}
