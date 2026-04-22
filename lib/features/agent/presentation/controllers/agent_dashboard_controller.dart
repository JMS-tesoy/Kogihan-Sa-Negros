import 'package:flutter/foundation.dart';

import '../../domain/entities/agent_profile_entity.dart';
import '../../domain/usecases/get_agent_profile_usecase.dart';

class AgentDashboardController extends ChangeNotifier {
  AgentDashboardController({this.getAgentProfileUsecase});

  final GetAgentProfileUsecase? getAgentProfileUsecase;

  AgentProfileEntity? _profile;

  AgentProfileEntity? get profile => _profile;

  Future<void> load() async {
    _profile = await getAgentProfileUsecase?.call();
    notifyListeners();
  }
}
