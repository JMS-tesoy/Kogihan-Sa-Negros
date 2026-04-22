import '../../domain/entities/agent_profile_entity.dart';

class AgentProfileModel extends AgentProfileEntity {
  const AgentProfileModel({
    required super.id,
    required super.name,
    super.email,
    super.phone,
    super.licenseNumber,
  });
}
