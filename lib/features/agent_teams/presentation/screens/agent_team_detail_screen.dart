import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/agent_team_entity.dart';
import '../../domain/entities/agent_team_member_entity.dart';

class AgentTeamDetailScreen extends StatelessWidget {
  const AgentTeamDetailScreen({super.key, required this.team});

  final AgentTeamEntity team;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(team.name), centerTitle: true),
      body: ListView(
        children: <Widget>[
          _TeamHeader(team: team),
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
          if (team.members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No members listed yet.')),
            )
          else
            ...team.members.map((member) => _MemberTile(member: member)),
          const SizedBox(height: 32),
        ],
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
