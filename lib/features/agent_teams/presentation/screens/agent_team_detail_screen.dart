import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/agent_team_entity.dart';
import '../../domain/entities/agent_team_member_entity.dart';

class AgentTeamDetailScreen extends StatefulWidget {
  const AgentTeamDetailScreen({super.key, required this.team});

  final AgentTeamEntity team;

  @override
  State<AgentTeamDetailScreen> createState() => _AgentTeamDetailScreenState();
}

class _AgentTeamDetailScreenState extends State<AgentTeamDetailScreen> {
  bool _isCheckingJoinRequest = true;
  bool _isSubmittingJoinRequest = false;
  String? _joinRequestStatus;

  bool get _isCurrentUserMember {
    final String? currentEmail = Supabase.instance.client.auth.currentUser?.email
        ?.trim()
        .toLowerCase();
    if (currentEmail == null || currentEmail.isEmpty) return false;

    return widget.team.members.any(
      (member) => member.email?.trim().toLowerCase() == currentEmail,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadJoinRequestStatus();
  }

  Future<void> _loadJoinRequestStatus() async {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null || _isCurrentUserMember) {
      if (!mounted) return;
      setState(() {
        _isCheckingJoinRequest = false;
      });
      return;
    }

    try {
      final Map<String, dynamic>? response = await Supabase.instance.client
          .from('team_join_requests')
          .select('status')
          .eq('team_id', widget.team.id)
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _joinRequestStatus = response?['status'] as String?;
        _isCheckingJoinRequest = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingJoinRequest = false;
      });
    }
  }

  Future<void> _requestToJoin() async {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null || _isSubmittingJoinRequest) return;

    setState(() {
      _isSubmittingJoinRequest = true;
    });

    try {
      await Supabase.instance.client.from('team_join_requests').upsert({
        'team_id': widget.team.id,
        'user_id': user.id,
        'status': 'pending',
      }, onConflict: 'team_id,user_id');

      if (!mounted) return;
      setState(() {
        _joinRequestStatus = 'pending';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join request sent.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send join request.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingJoinRequest = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.team.name), centerTitle: true),
      body: ListView(
        children: <Widget>[
          _TeamHeader(team: widget.team),
          _JoinRequestSection(
            isCurrentUserMember: _isCurrentUserMember,
            isChecking: _isCheckingJoinRequest,
            isSubmitting: _isSubmittingJoinRequest,
            status: _joinRequestStatus,
            onRequestToJoin: _requestToJoin,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Team Members',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (widget.team.members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No members listed yet.')),
            )
          else
            ...widget.team.members.map((member) => _MemberTile(member: member)),
          const SizedBox(height: 32),
        ],
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
  });

  final bool isCurrentUserMember;
  final bool isChecking;
  final bool isSubmitting;
  final String? status;
  final VoidCallback onRequestToJoin;

  @override
  Widget build(BuildContext context) {
    if (isCurrentUserMember) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Already in this team'),
        ),
      );
    }

    if (isChecking) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (status == 'pending') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.hourglass_top_outlined),
          label: const Text('Request Pending'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: FilledButton.icon(
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

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.team});

  final AgentTeamEntity team;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          if (team.logoUrl != null && team.logoUrl!.isNotEmpty)
            CircleAvatar(
              radius: 40,
              backgroundImage: CachedNetworkImageProvider(team.logoUrl!),
              backgroundColor: colorScheme.primaryContainer,
            )
          else
            CircleAvatar(
              radius: 40,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                team.name.isNotEmpty ? team.name[0].toUpperCase() : 'T',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            team.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          if (team.specialization.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                team.specialization,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (team.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              team.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.group_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '${team.members.length} '
                'member${team.members.length == 1 ? '' : 's'}',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final AgentTeamMemberEntity member;

  Future<void> _openContactLink(BuildContext context, Uri uri) async {
    final bool launched = await launchUrl(uri);
    if (launched || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No app found to handle this action.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String? phone = member.phone;
    final String? email = member.email;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: member.avatarUrl != null && member.avatarUrl!.isNotEmpty
          ? CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(member.avatarUrl!),
              backgroundColor: colorScheme.primaryContainer,
            )
          : CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                member.name.isNotEmpty ? member.name[0].toUpperCase() : 'A',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      title: Text(
        member.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: member.role.isNotEmpty ? Text(member.role) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (phone != null && phone.isNotEmpty)
            IconButton(
              tooltip: 'Call',
              icon: const Icon(Icons.call_outlined),
              onPressed: () {
                _openContactLink(
                  context,
                  Uri(scheme: 'tel', path: phone),
                );
              },
            ),
          if (email != null && email.isNotEmpty)
            IconButton(
              tooltip: 'Email',
              icon: const Icon(Icons.mail_outlined),
              onPressed: () {
                _openContactLink(
                  context,
                  Uri(
                    scheme: 'mailto',
                    path: email,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
