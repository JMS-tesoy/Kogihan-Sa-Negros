import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/moderation_repository.dart';
import '../../data/models/moderation_case.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  final ModerationRepository _repository = ModerationRepository();
  late Future<List<ModerationCase>> _cases;
  ModerationCaseType? _filter;

  @override
  void initState() {
    super.initState();
    _cases = _repository.fetchCases();
  }

  void _refresh() {
    setState(() {
      _cases = _repository.fetchCases();
    });
  }

  Future<void> _openCase(ModerationCase moderationCase) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ModerationReviewScreen(
          moderationCase: moderationCase,
          repository: _repository,
        ),
      ),
    );
    if (changed == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Moderation Queue',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<ModerationCaseType?>(
              segments: const [
                ButtonSegment(value: null, label: Text('All')),
                ButtonSegment(
                  value: ModerationCaseType.submission,
                  label: Text('Listings'),
                ),
                ButtonSegment(
                  value: ModerationCaseType.report,
                  label: Text('Reports'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) {
                setState(() => _filter = selection.first);
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _refresh();
                await _cases;
              },
              child: FutureBuilder<List<ModerationCase>>(
                future: _cases,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      padding: const EdgeInsets.all(32),
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 44),
                        const SizedBox(height: 12),
                        Text(
                          'Unable to load moderation cases.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _refresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    );
                  }

                  final cases = (snapshot.data ?? const <ModerationCase>[])
                      .where((item) => _filter == null || item.type == _filter)
                      .toList();
                  if (cases.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(32),
                      children: const [
                        Icon(Icons.verified_outlined, size: 44),
                        SizedBox(height: 12),
                        Text(
                          'No moderation cases are waiting for review.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: cases.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = cases[index];
                      return _ModerationCaseCard(
                        moderationCase: item,
                        onTap: () => _openCase(item),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModerationCaseCard extends StatelessWidget {
  const _ModerationCaseCard({
    required this.moderationCase,
    required this.onTap,
  });

  final ModerationCase moderationCase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isReport = moderationCase.type == ModerationCaseType.report;
    final icon = isReport ? Icons.flag_outlined : Icons.home_work_outlined;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isReport
                      ? colorScheme.errorContainer
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isReport
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moderationCase.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isReport
                          ? moderationCase.reason ??
                                'A community report was submitted.'
                          : moderationCase.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _InfoChip(
                          label: isReport ? 'Buyer report' : 'Listing review',
                          color: isReport
                              ? colorScheme.errorContainer
                              : colorScheme.primaryContainer,
                        ),
                        Text(
                          _formatDate(moderationCase.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class ModerationReviewScreen extends StatefulWidget {
  const ModerationReviewScreen({
    required this.moderationCase,
    required this.repository,
    super.key,
  });

  final ModerationCase moderationCase;
  final ModerationRepository repository;

  @override
  State<ModerationReviewScreen> createState() => _ModerationReviewScreenState();
}

class _ModerationReviewScreenState extends State<ModerationReviewScreen> {
  final _reasonController = TextEditingController();
  late Future<List<ModerationAuditEntry>> _auditEntries;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _auditEntries = widget.repository.fetchAudit(widget.moderationCase);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _decide(ModerationDecision decision) async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      AppSnackBar.warning(context, 'Add a reason before submitting.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.repository.decide(
        moderationCase: widget.moderationCase,
        decision: decision,
        reason: reason,
      );
      if (!mounted) return;
      AppSnackBar.success(context, 'Moderation decision saved.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Unable to save decision: $error');
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.moderationCase;
    final isReport = item.type == ModerationCaseType.report;
    return AppScaffoldShell(
      title: isReport ? 'Report Details' : 'Listing Review',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (item.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                item.imageUrl!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 220,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            item.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(item.subtitle),
          if (item.reason != null) ...[
            const SizedBox(height: 16),
            _ReviewSection(title: 'Report reason', value: item.reason!),
          ],
          if (item.description != null) ...[
            const SizedBox(height: 16),
            _ReviewSection(
              title: isReport ? 'Reporter note' : 'Listing description',
              value: item.description!,
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Decision reason',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            maxLines: 4,
            enabled: !_submitting,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Explain the action for the audit trail and user.',
            ),
          ),
          const SizedBox(height: 20),
          if (!isReport) ...[
            FilledButton.icon(
              onPressed: _submitting
                  ? null
                  : () => _decide(ModerationDecision.approve),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Approve and publish'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _submitting
                  ? null
                  : () => _decide(ModerationDecision.requestChanges),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Request changes'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _submitting
                  ? null
                  : () => _decide(ModerationDecision.reject),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Reject and archive'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: _submitting
                  ? null
                  : () => _decide(ModerationDecision.approve),
              icon: const Icon(Icons.gpp_bad_outlined),
              label: const Text('Confirm report and hide listing'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _submitting
                  ? null
                  : () => _decide(ModerationDecision.reject),
              icon: const Icon(Icons.done_all),
              label: const Text('Dismiss report'),
            ),
          ],
          if (_submitting) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 24),
          Text('Audit history', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FutureBuilder<List<ModerationAuditEntry>>(
            future: _auditEntries,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text(
                  'Audit history is unavailable until the migration is applied: '
                  '${snapshot.error}',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
              final entries = snapshot.data ?? const <ModerationAuditEntry>[];
              if (entries.isEmpty) {
                return const _ReviewSection(
                  title: 'No previous decisions',
                  value: 'This case has not been resolved before.',
                );
              }
              return Column(
                children: entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ReviewSection(
                          title:
                              '${_decisionLabel(entry.decision)} · '
                              '${_formatDate(entry.createdAt)}',
                          value:
                              '${entry.previousStatus} → ${entry.newStatus}\n'
                              '${entry.reason}',
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(value),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return 'Date unavailable';
  final local = date.toLocal();
  return '${local.day}/${local.month}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _decisionLabel(String decision) {
  return switch (decision) {
    'approve' => 'Approved',
    'request_changes' => 'Changes requested',
    'reject' => 'Rejected / dismissed',
    _ => decision,
  };
}
