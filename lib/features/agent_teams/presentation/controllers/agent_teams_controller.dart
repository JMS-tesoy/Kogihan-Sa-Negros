import 'package:flutter/foundation.dart';

import '../../data/repositories/agent_teams_repository_impl.dart';
import '../../domain/entities/agent_team_entity.dart';
import '../../domain/usecases/get_agent_teams_usecase.dart';

class AgentTeamsController extends ChangeNotifier {
  AgentTeamsController({GetAgentTeamsUsecase? getAgentTeamsUsecase})
      : _getAgentTeamsUsecase = getAgentTeamsUsecase ??
            GetAgentTeamsUsecase(AgentTeamsRepositoryImpl());

  final GetAgentTeamsUsecase _getAgentTeamsUsecase;

  List<AgentTeamEntity> _teams = const <AgentTeamEntity>[];
  bool _isLoading = false;
  String? _error;

  List<AgentTeamEntity> get teams => _teams;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _teams = await _getAgentTeamsUsecase();
    } catch (_) {
      _error = 'Failed to load agent teams. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}