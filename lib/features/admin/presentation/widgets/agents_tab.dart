import 'package:flutter/material.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/models/agent_profile.dart';

typedef FetchAgentProfiles = Future<List<AgentProfile>> Function();

typedef UpsertAgentProfile =
    Future<void> Function({
      required String id,
      required String fullName,
      required String email,
      required String phone,
      String? avatarUrl,
      String? teamId,
      String? role,
    });

typedef DeleteAgentProfile = Future<void> Function(String id);

class AgentsTab extends StatefulWidget {
  const AgentsTab({
    super.key,
    required this.fetchProfiles,
    required this.upsertProfile,
    required this.deleteProfile,
  });

  final FetchAgentProfiles fetchProfiles;
  final UpsertAgentProfile upsertProfile;
  final DeleteAgentProfile deleteProfile;

  @override
  State<AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends State<AgentsTab> {
  List<AgentProfile> _profiles = const <AgentProfile>[];
  bool _isLoading = true;
  String? _error;
  String _search = '';

  List<AgentProfile> get _filtered {
    final String q = _search.trim().toLowerCase();
    if (q.isEmpty) return _profiles;
    return _profiles.where((p) {
      return p.fullName.toLowerCase().contains(q) ||
          p.email.toLowerCase().contains(q) ||
          (p.teamName?.toLowerCase().contains(q) ?? false) ||
          (p.phone.toLowerCase().contains(q));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<AgentProfile> profiles = await widget.fetchProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showEditDialog(AgentProfile profile) {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController fullNameCtrl = TextEditingController(
      text: profile.fullName,
    );
    final TextEditingController emailCtrl = TextEditingController(
      text: profile.email,
    );
    final TextEditingController phoneCtrl = TextEditingController(
      text: profile.phone,
    );
    final TextEditingController avatarCtrl = TextEditingController(
      text: profile.avatarUrl ?? '',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Agent'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: fullNameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: avatarCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Avatar URL (opt)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final bool? confirm = await showDialog<bool>(
                  context: ctx,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Agent?'),
                    content: const Text('This action cannot be undone.'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm ?? false) {
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  try {
                    await widget.deleteProfile(profile.id);
                    if (mounted) {
                      AppSnackBar.success(context, 'Agent deleted.');
                      _load();
                    }
                  } catch (e) {
                    if (mounted) {
                      AppSnackBar.error(context, 'Error: $e');
                    }
                  }
                }
              },
              child: const Text('Delete'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop();
                  try {
                    await widget.upsertProfile(
                      id: profile.id,
                      fullName: fullNameCtrl.text,
                      email: emailCtrl.text,
                      phone: phoneCtrl.text,
                      avatarUrl: avatarCtrl.text.trim().isEmpty
                          ? null
                          : avatarCtrl.text.trim(),
                    );
                    if (mounted) {
                      AppSnackBar.success(context, 'Agent updated.');
                      _load();
                    }
                  } catch (e) {
                    if (mounted) {
                      AppSnackBar.error(context, 'Error: $e');
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    final List<AgentProfile> filtered = _filtered;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search agents...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                _search.isEmpty ? 'No agents found.' : 'No results.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final AgentProfile profile = filtered[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      onTap: () => _showEditDialog(profile),
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        backgroundImage:
                            profile.avatarUrl != null &&
                                profile.avatarUrl!.isNotEmpty
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child:
                            profile.avatarUrl == null ||
                                profile.avatarUrl!.isEmpty
                            ? Icon(
                                Icons.person_outline_rounded,
                                color: cs.onPrimaryContainer,
                              )
                            : null,
                      ),
                      title: Text(
                        profile.fullName.isEmpty
                            ? '(no name)'
                            : profile.fullName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            profile.email.isEmpty ? '—' : profile.email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (profile.teamName != null &&
                              profile.teamName!.isNotEmpty)
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.group_outlined,
                                  size: 13,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  profile.teamName!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Missing Error View Widget ──────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Requests Tab ─────────────────────────────────────────────────────────────