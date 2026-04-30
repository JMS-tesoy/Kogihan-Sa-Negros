import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../subscription/data/services/subscription_service.dart';
import '../../../subscription/presentation/navigation/subscription_navigation.dart';
import '../../domain/entities/agent_team_entity.dart';
import '../controllers/agent_teams_controller.dart';
import '../widgets/agent_team_card.dart';
import 'agent_team_detail_screen.dart';

class AgentTeamsScreen extends StatefulWidget {
  const AgentTeamsScreen({super.key});

  @override
  State<AgentTeamsScreen> createState() => _AgentTeamsScreenState();
}

class _AgentTeamsScreenState extends State<AgentTeamsScreen> {
  late final AgentTeamsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AgentTeamsController();
    _controller.addListener(_rebuild);
    if (appSubscriptionNotifier.value.isPremium) {
      _controller.load();
    }
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _controller.dispose();
    super.dispose();
  }

  void _openTeamDetail(AgentTeamEntity team) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AgentTeamDetailScreen(team: team),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agent Teams'), centerTitle: true),
      body: ValueListenableBuilder<UserSubscription>(
        valueListenable: appSubscriptionNotifier,
        builder: (context, subscription, child) {
          if (!subscription.isPremium) {
            return _PremiumGate(
              onUpgrade: () => openSubscriptionPage(context),
            );
          }
          return _TeamsBody(
            controller: _controller,
            onTeamTap: _openTeamDetail,
          );
        },
      ),
    );
  }
}

class _TeamsBody extends StatelessWidget {
  const _TeamsBody({
    required this.controller,
    required this.onTeamTap,
  });

  final AgentTeamsController controller;
  final ValueChanged<AgentTeamEntity> onTeamTap;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) return const AppLoadingIndicator();

    if (controller.error != null) {
      return AppErrorView(
        message: controller.error!,
        onRetry: controller.load,
      );
    }

    if (controller.teams.isEmpty) {
      return const AppEmptyState(message: 'No agent teams available yet.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: controller.teams.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final AgentTeamEntity team = controller.teams[index];
        return AgentTeamCard(team: team, onTap: () => onTeamTap(team));
      },
    );
  }
}

class _PremiumGate extends StatelessWidget {
  const _PremiumGate({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_2_outlined,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Premium Feature',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Access to Agent Teams is exclusive to Premium subscribers. '
              'Upgrade to connect with verified agent teams in your area.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onUpgrade,
                icon: const Icon(Icons.workspace_premium),
                label: const Text('Upgrade to Premium'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Starting at ₱199/month',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
