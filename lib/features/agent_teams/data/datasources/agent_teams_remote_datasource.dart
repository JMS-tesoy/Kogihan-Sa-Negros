import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/agent_team_model.dart';

class AgentTeamsRemoteDatasource {
  Future<List<AgentTeamModel>> getAgentTeams() async {
    final List<dynamic> response = await Supabase.instance.client
        .from('agent_teams')
        .select('*, team_members(*)')
        .order('name');
    return response
        .map(
          (item) => AgentTeamModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<AgentTeamModel?> getAgentTeamById(String id) async {
    final Map<String, dynamic>? response = await Supabase.instance.client
        .from('agent_teams')
        .select('*, team_members(*)')
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return AgentTeamModel.fromJson(response);
  }
}