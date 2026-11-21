import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/moderation_case.dart';

enum ModerationDecision { approve, requestChanges, reject }

class ModerationRepository {
  ModerationRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<ModerationCase>> fetchCases() async {
    final results = await Future.wait<List<dynamic>>([
      _client
          .from('properties')
          .select(
            'id, title, location, status, description, created_at, '
            'agent_id, image_url',
          )
          .eq('status', 'pending')
          .or('moderation_status.is.null,moderation_status.eq.pending')
          .order('created_at'),
      _client
          .from('moderation_reports')
          .select(
            'id, reporter_id, reported_property_id, reported_user_id, reason, '
            'description, status, created_at',
          )
          .eq('status', 'pending')
          .order('created_at'),
    ]);

    final propertyRows = results[0]
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final reportRows = results[1]
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    final propertyIds = reportRows
        .map((row) => row['reported_property_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final profileIds = reportRows
        .map((row) => row['reporter_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (propertyIds.isNotEmpty) {
      final properties = await _client
          .from('properties')
          .select('id, title, image_url')
          .inFilter('id', propertyIds);
      final propertyById = <String, Map<String, dynamic>>{
        for (final row in properties)
          Map<String, dynamic>.from(row as Map)['id'].toString():
              Map<String, dynamic>.from(row as Map),
      };
      for (final row in reportRows) {
        final property = propertyById[row['reported_property_id']?.toString()];
        row['property_title'] = property?['title'];
        row['property_image_url'] = property?['image_url'];
      }
    }

    final reporterIds = <String>{
      ...profileIds,
      ...reportRows
          .map((row) => row['reported_user_id']?.toString())
          .whereType<String>(),
    }.where((id) => id.isNotEmpty).toList();
    if (reporterIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', reporterIds);
      final profileById = <String, String>{
        for (final row in profiles)
          Map<String, dynamic>.from(row as Map)['id'].toString():
              (Map<String, dynamic>.from(row as Map)['full_name'] ?? '')
                  .toString(),
      };
      for (final row in reportRows) {
        row['reporter_name'] =
            profileById[row['reporter_id']?.toString()] ?? 'Community report';
      }
    }

    final cases = <ModerationCase>[
      ...propertyRows.map(ModerationCase.fromProperty),
      ...reportRows.map(ModerationCase.fromReport),
    ];
    cases.sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return cases;
  }

  Future<void> decide({
    required ModerationCase moderationCase,
    required ModerationDecision decision,
    required String reason,
  }) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'A decision reason is required.',
      );
    }

    await _client.rpc(
      'resolve_moderation_case',
      params: {
        'p_case_type': moderationCase.type.name,
        'p_case_id': moderationCase.id,
        'p_decision': switch (decision) {
          ModerationDecision.approve => 'approve',
          ModerationDecision.requestChanges => 'request_changes',
          ModerationDecision.reject => 'reject',
        },
        'p_reason': normalizedReason,
      },
    );
  }

  Future<List<ModerationAuditEntry>> fetchAudit(
    ModerationCase moderationCase,
  ) async {
    final rows = await _client
        .from('moderation_audit_log')
        .select(
          'id, decision, reason, previous_status, new_status, created_at',
        )
        .eq('case_type', moderationCase.type.name)
        .eq('case_id', moderationCase.id)
        .order('created_at', ascending: false);
    return rows
        .map(
          (row) => ModerationAuditEntry.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }
}
