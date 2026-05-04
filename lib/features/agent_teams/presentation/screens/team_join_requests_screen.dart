import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/app_snack_bar.dart';

class TeamJoinRequestsScreen extends StatefulWidget {
  const TeamJoinRequestsScreen({super.key});

  @override
  State<TeamJoinRequestsScreen> createState() => _TeamJoinRequestsScreenState();
}

class _TeamJoinRequestsScreenState extends State<TeamJoinRequestsScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  List<_TeamJoinRequest> _requests = const <_TeamJoinRequest>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<dynamic> rows = await _client
          .from('team_join_requests')
          .select('id, team_id, user_id, status, created_at, agent_teams(name)')
          .eq('status', 'pending')
          .order('created_at');

      final List<_TeamJoinRequest> requests = rows
          .map(
            (row) => _TeamJoinRequest.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();

      final List<String> userIds = requests
          .map((request) => request.userId)
          .toList();
      final Map<String, _RequesterProfile> profiles = await _loadProfiles(
        userIds,
      );

      if (!mounted) return;
      setState(() {
        _requests = requests
            .map(
              (request) =>
                  request.copyWith(requester: profiles[request.userId]),
            )
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load join requests.';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, _RequesterProfile>> _loadProfiles(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return const <String, _RequesterProfile>{};

    final List<dynamic> rows = await _client
        .from('profiles')
        .select('id, full_name, email, phone, avatar_url')
        .inFilter('id', userIds);

    final Map<String, _RequesterProfile> profiles =
        <String, _RequesterProfile>{};
    for (final dynamic row in rows) {
      final _RequesterProfile profile = _RequesterProfile.fromJson(
        Map<String, dynamic>.from(row as Map),
      );
      profiles[profile.id] = profile;
    }
    return profiles;
  }

  Future<void> _approveRequest(_TeamJoinRequest request) async {
    final _RequesterProfile? requester = request.requester;
    final String memberName = requester?.displayName ?? 'Agent';

    try {
      await _client.from('team_members').insert({
        'team_id': request.teamId,
        'user_id': request.userId,
        'name': memberName,
        'role': 'Agent',
        'avatar_url': requester?.avatarUrl,
        'phone': requester?.phone,
        'email': requester?.email,
      });

      await _client
          .from('team_join_requests')
          .update({'status': 'approved'})
          .eq('id', request.id);

      if (!mounted) return;

      AppSnackBar.success(context, '$memberName added to ${request.teamName}.');

      await _loadRequests();
    } catch (_) {
      if (!mounted) return;

      AppSnackBar.error(context, 'Failed to approve request.');
    }
  }

  Future<void> _rejectRequest(_TeamJoinRequest request) async {
    try {
      await _client
          .from('team_join_requests')
          .update({'status': 'rejected'})
          .eq('id', request.id);

      if (!mounted) return;

      AppSnackBar.success(context, 'Join request rejected.');

      await _loadRequests();
    } catch (_) {
      if (!mounted) return;

      AppSnackBar.error(context, 'Failed to reject request.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Join Requests'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadRequests,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return const Center(child: Text('No pending team join requests.'));
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final _TeamJoinRequest request = _requests[index];
          return _JoinRequestCard(
            request: request,
            onApprove: () => _approveRequest(request),
            onReject: () => _rejectRequest(request),
          );
        },
      ),
    );
  }
}

class _JoinRequestCard extends StatelessWidget {
  const _JoinRequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final _TeamJoinRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final _RequesterProfile? requester = request.requester;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              requester?.displayName ?? 'Unknown requester',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('Team: ${request.teamName}'),
            if (requester?.email != null) Text('Email: ${requester!.email}'),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onApprove,
                    child: const Text('Approve'),
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

class _TeamJoinRequest {
  const _TeamJoinRequest({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.status,
    required this.teamName,
    this.requester,
  });

  final String id;
  final String teamId;
  final String userId;
  final String status;
  final String teamName;
  final _RequesterProfile? requester;

  factory _TeamJoinRequest.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> teamJson = Map<String, dynamic>.from(
      json['agent_teams'] as Map? ?? const {},
    );
    return _TeamJoinRequest(
      id: json['id'] as String? ?? '',
      teamId: json['team_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      teamName: teamJson['name'] as String? ?? 'Agent Team',
    );
  }

  _TeamJoinRequest copyWith({_RequesterProfile? requester}) {
    return _TeamJoinRequest(
      id: id,
      teamId: teamId,
      userId: userId,
      status: status,
      teamName: teamName,
      requester: requester ?? this.requester,
    );
  }
}

class _RequesterProfile {
  const _RequesterProfile({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
  });

  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;

  String get displayName {
    final String name = fullName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    return email ?? 'Agent';
  }

  factory _RequesterProfile.fromJson(Map<String, dynamic> json) {
    return _RequesterProfile(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
