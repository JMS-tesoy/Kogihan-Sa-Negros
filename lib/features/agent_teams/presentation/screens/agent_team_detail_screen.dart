import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../../agent/presentation/screens/agent_dashboard_screen.dart';
import '../../domain/entities/agent_team_entity.dart';

class AgentTeamDetailScreen extends StatefulWidget {
  const AgentTeamDetailScreen({super.key, required this.team});

  final AgentTeamEntity team;

  @override
  State<AgentTeamDetailScreen> createState() => _AgentTeamDetailScreenState();
}

class _AgentTeamDetailScreenState extends State<AgentTeamDetailScreen> {
  bool _isCheckingJoinRequest = true;
  bool _isSubmittingJoinRequest = false;
  bool _isCurrentUserMemberFromDatabase = false;
  String? _joinRequestStatus;

  bool get _isCurrentUserMember {
    final User? currentUser = Supabase.instance.client.auth.currentUser;
    final String? currentEmail = currentUser?.email?.trim().toLowerCase();

    if (currentUser == null) return false;

    if (_isCurrentUserMemberFromDatabase) return true;

    if (_joinRequestStatus?.trim().toLowerCase() == 'approved') {
      return true;
    }

    return widget.team.members.any((member) {
      if (member.userId == currentUser.id) {
        return true;
      }

      if (currentEmail == null || currentEmail.isEmpty) return false;

      return member.email?.trim().toLowerCase() == currentEmail;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadJoinRequestStatus();
  }

  Future<void> _loadJoinRequestStatus() async {
    final SupabaseClient client = Supabase.instance.client;
    final User? user = client.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isCheckingJoinRequest = false;
      });
      return;
    }

    try {
      final Map<String, dynamic>? existingMember = await client
          .from('team_members')
          .select('id')
          .eq('team_id', widget.team.id)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingMember != null) {
        if (!mounted) return;

        setState(() {
          _isCurrentUserMemberFromDatabase = true;
          _joinRequestStatus = 'approved';
          _isCheckingJoinRequest = false;
        });
        return;
      }

      final Map<String, dynamic>? response = await client
          .from('team_join_requests')
          .select('status')
          .eq('team_id', widget.team.id)
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _isCurrentUserMemberFromDatabase = false;
        _joinRequestStatus = response?['status'] as String?;
        _isCheckingJoinRequest = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isCheckingJoinRequest = false;
      });

      AppSnackBar.error(context, 'Failed to check join status: $error');
    }
  }

  Future<void> _requestToJoin() async {
    final SupabaseClient client = Supabase.instance.client;
    final User? user = client.auth.currentUser;

    if (user == null || _isSubmittingJoinRequest) return;

    setState(() {
      _isSubmittingJoinRequest = true;
    });

    try {
      final Map<String, dynamic>? existingMember = await client
          .from('team_members')
          .select('id')
          .eq('team_id', widget.team.id)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingMember != null) {
        if (!mounted) return;

        setState(() {
          _isCurrentUserMemberFromDatabase = true;
          _joinRequestStatus = 'approved';
        });

        AppSnackBar.info(context, 'You are already in this team.');
        return;
      }

      final Map<String, dynamic>? existingRequest = await client
          .from('team_join_requests')
          .select('id, team_id, user_id, status')
          .eq('team_id', widget.team.id)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingRequest != null) {
        final String status =
            (existingRequest['status'] as String? ?? 'pending')
                .trim()
                .toLowerCase();

        if (status == 'pending') {
          if (!mounted) return;

          setState(() {
            _joinRequestStatus = 'pending';
          });

          AppSnackBar.info(
            context,
            'You already have a pending request for this team.',
          );
          return;
        }

        if (status == 'approved') {
          if (!mounted) return;

          setState(() {
            _joinRequestStatus = 'approved';
          });

          AppSnackBar.info(context, 'You are already approved for this team.');
          return;
        }

        await client
            .from('team_join_requests')
            .update(<String, dynamic>{'status': 'pending'})
            .eq('id', existingRequest['id'])
            .eq('team_id', widget.team.id)
            .eq('user_id', user.id);
      } else {
        await client.from('team_join_requests').insert(<String, dynamic>{
          'team_id': widget.team.id,
          'user_id': user.id,
          'status': 'pending',
        });
      }

      if (!mounted) return;

      setState(() {
        _joinRequestStatus = 'pending';
      });

      AppSnackBar.success(context, 'Join request sent.');
    } catch (error) {
      if (!mounted) return;

      AppSnackBar.error(context, 'Failed to send join request: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingJoinRequest = false;
        });
      }
    }
  }

  void _openTeamInbox() {
    final TeamChatTeam chatTeam = TeamChatTeam(
      id: widget.team.id,
      name: widget.team.name,
      specialization: widget.team.specialization,
      logoUrl: widget.team.logoUrl,
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TeamConversationPage(team: chatTeam),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isApprovedMember = _isCurrentUserMember;

    return Scaffold(
      appBar: AppBar(title: Text(widget.team.name), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _loadJoinRequestStatus,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: <Widget>[
            _TeamHeroCard(team: widget.team),
            const SizedBox(height: 16),
            _JoinRequestSection(
              isCurrentUserMember: isApprovedMember,
              isChecking: _isCheckingJoinRequest,
              isSubmitting: _isSubmittingJoinRequest,
              status: _joinRequestStatus,
              onRequestToJoin: _requestToJoin,
              onOpenTeamInbox: _openTeamInbox,
            ),
            const SizedBox(height: 16),
            _InfoCard(
              icon: Icons.info_outline_rounded,
              title: 'About this team',
              body: widget.team.description.trim().isNotEmpty
                  ? widget.team.description.trim()
                  : 'This team coordinates property-related tasks, inquiries, and internal collaboration.',
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.privacy_tip_outlined,
              title: 'Team access',
              body: isApprovedMember
                  ? 'You are an approved member. You can use the private team inbox to coordinate with this team.'
                  : 'Only approved members can access the private team inbox. Member contact details are hidden for privacy.',
            ),
            const SizedBox(height: 12),
            _TeamStatsCard(team: widget.team),
          ],
        ),
      ),
    );
  }
}

class _TeamHeroCard extends StatelessWidget {
  const _TeamHeroCard({required this.team});

  final AgentTeamEntity team;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          children: <Widget>[
            if (team.logoUrl != null && team.logoUrl!.trim().isNotEmpty)
              CircleAvatar(
                radius: 46,
                backgroundImage: CachedNetworkImageProvider(team.logoUrl!),
                backgroundColor: colorScheme.primaryContainer,
              )
            else
              CircleAvatar(
                radius: 46,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  team.name.isNotEmpty ? team.name[0].toUpperCase() : 'T',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              team.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            if (team.specialization.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  team.specialization.trim(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.groups_2_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '${team.members.length} '
                  'member${team.members.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinRequestSection extends StatelessWidget {
  const _JoinRequestSection({
    required this.isCurrentUserMember,
    required this.isChecking,
    required this.isSubmitting,
    required this.status,
    required this.onRequestToJoin,
    required this.onOpenTeamInbox,
  });

  final bool isCurrentUserMember;
  final bool isChecking;
  final bool isSubmitting;
  final String? status;
  final VoidCallback onRequestToJoin;
  final VoidCallback onOpenTeamInbox;

  @override
  Widget build(BuildContext context) {
    final String normalizedStatus = status?.trim().toLowerCase() ?? '';

    if (isChecking) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (isCurrentUserMember || normalizedStatus == 'approved') {
      return _AccessCard(
        icon: Icons.verified_rounded,
        title: 'You are approved for this team',
        message: 'Use the private team inbox for internal coordination.',
        action: FilledButton.icon(
          onPressed: onOpenTeamInbox,
          icon: const Icon(Icons.forum_outlined),
          label: const Text('Open Team Inbox'),
        ),
      );
    }

    if (normalizedStatus == 'pending') {
      return const _AccessCard(
        icon: Icons.hourglass_top_outlined,
        title: 'Request pending',
        message:
            'Your join request is waiting for team approval. Team inbox access will unlock after approval.',
      );
    }

    return _AccessCard(
      icon: Icons.lock_outline_rounded,
      title: 'Private team access',
      message:
          'Request approval to access this team’s private collaboration tools.',
      action: FilledButton.icon(
        onPressed: isSubmitting ? null : onRequestToJoin,
        icon: isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.group_add_outlined),
        label: Text(isSubmitting ? 'Sending request...' : 'Request to Join'),
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.82),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, color: colorScheme.onPrimaryContainer, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.82,
                          ),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamStatsCard extends StatelessWidget {
  const _TeamStatsCard({required this.team});

  final AgentTeamEntity team;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Team summary',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _SummaryRow(
              icon: Icons.category_outlined,
              label: 'Specialization',
              value: team.specialization.trim().isNotEmpty
                  ? team.specialization.trim()
                  : 'General real estate support',
            ),
            const SizedBox(height: 12),
            _SummaryRow(
              icon: Icons.groups_2_outlined,
              label: 'Members',
              value:
                  '${team.members.length} member${team.members.length == 1 ? '' : 's'}',
            ),
            const SizedBox(height: 12),
            _SummaryRow(
              icon: Icons.shield_outlined,
              label: 'Privacy',
              value: 'Member contacts are hidden from the public team profile.',
              valueColor: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                height: 1.35,
              ),
              children: <TextSpan>[
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: valueColor ?? colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
