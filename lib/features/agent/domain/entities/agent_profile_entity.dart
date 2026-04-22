class AgentProfileEntity {
  const AgentProfileEntity({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.licenseNumber = '',
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String licenseNumber;
}
