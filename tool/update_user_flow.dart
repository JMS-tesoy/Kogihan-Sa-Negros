import 'dart:convert';
import 'dart:io';

const sourcePath = 'docs/app_user_flow.md';
const outputPath = 'mockups/app_user_flow/flow-data.js';
const routeNamesPath = 'lib/app/router/route_names.dart';

const laneColumns = <String, int>{
  'entry': 28,
  'shell': 302,
  'journey': 636,
  'upgrade': 970,
  'agent': 1304,
  'admin': 1572,
};

const validRoles = {'entry', 'buyer', 'agent', 'admin'};
const validStatuses = {
  'complete',
  'integration',
  'guarded',
  'planned',
  'blocked',
};

final nodeDeclaration = RegExp(
  r'^\s*([A-Za-z][\w-]*)\["([^"]+)"\]:::(\w+)\s*$',
);
final edgeDeclaration = RegExp(
  r'^\s*([A-Za-z][\w-]*)\s*-->\s*(?:\|"([^"]*)"\|)?\s*'
  r'([A-Za-z][\w-]*)\s*$',
);

Never fail(String message) {
  stderr.writeln('Flow update failed: $message');
  exitCode = 1;
  throw StateError(message);
}

Map<String, String> parseFields(String text) {
  final fields = <String, String>{};
  for (final part in text.split(' | ')) {
    final separator = part.indexOf('=');
    if (separator == -1) {
      continue;
    }
    final key = part.substring(0, separator).trim();
    final value = part.substring(separator + 1).trim();
    if (key.isNotEmpty) {
      fields[key] = value;
    }
  }
  return fields;
}

String requireField(Map<String, String> fields, String name, String context) {
  final value = fields[name];
  if (value == null || value.isEmpty) {
    fail('$context is missing "$name".');
  }
  return value;
}

List<Map<String, dynamic>> readNodes(String source) {
  final titles = <String, String>{};
  final declaredStatuses = <String, String>{};
  for (final line in const LineSplitter().convert(source)) {
    final match = nodeDeclaration.firstMatch(line);
    if (match == null) {
      continue;
    }
    final id = match.group(1)!;
    if (titles.containsKey(id)) {
      fail('Duplicate Mermaid node "$id".');
    }
    titles[id] = match.group(2)!.replaceAll(RegExp(r'<br\s*/?>'), ' ');
    declaredStatuses[id] = match.group(3)!;
  }

  final nodes = <Map<String, dynamic>>[];
  final usedSlots = <String, Set<int>>{};
  final metadata = RegExp(
    r'^@node\s+([A-Za-z][\w-]*)\s+\|\s+(.+)$',
    multiLine: true,
  );
  for (final match in metadata.allMatches(source)) {
    final id = match.group(1)!;
    final fields = parseFields(match.group(2)!);
    final title = titles[id];
    if (title == null) {
      fail('Metadata exists for "$id", but its Mermaid node is missing.');
    }

    final lane = requireField(fields, 'lane', 'Node "$id"');
    if (!laneColumns.containsKey(lane)) {
      fail('Node "$id" has invalid lane "$lane".');
    }
    final role = requireField(fields, 'role', 'Node "$id"');
    if (!validRoles.contains(role)) {
      fail('Node "$id" has invalid role "$role".');
    }
    final status = requireField(fields, 'status', 'Node "$id"');
    if (!validStatuses.contains(status)) {
      fail('Node "$id" has invalid status "$status".');
    }
    if (declaredStatuses[id] != status) {
      fail(
        'Node "$id" declares Mermaid class "${declaredStatuses[id]}" but '
        'metadata uses "$status".',
      );
    }

    final slotText = fields['slot'];
    final slot = slotText == null ? null : int.tryParse(slotText);
    if (slotText != null && slot == null) {
      fail('Node "$id" slot must be a number.');
    }
    final laneSlots = usedSlots.putIfAbsent(lane, () => <int>{});
    final resolvedSlot = slot ?? laneSlots.length;
    if (!laneSlots.add(resolvedSlot)) {
      fail('Lane "$lane" uses slot $resolvedSlot more than once.');
    }

    nodes.add(<String, dynamic>{
      'id': id,
      'title': title,
      'x': laneColumns[lane],
      'y': 92 + (resolvedSlot * 112),
      'role': role,
      'lane': lane,
      'status': status,
      'icon': fields['icon'] ?? title.substring(0, 1),
      'route': requireField(fields, 'route', 'Node "$id"'),
      'description':
          fields['description'] ?? '$title is part of the application flow.',
      'actions': (fields['actions'] ?? '')
          .split(';')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      'note': fields['note'] ?? 'Exercise this flow on a real device.',
      'source': fields['source'] ?? 'See the application feature source.',
    });
  }

  final metadataIds = nodes.map((node) => node['id'] as String).toSet();
  for (final id in titles.keys) {
    if (!metadataIds.contains(id)) {
      fail('Mermaid node "$id" is missing an @node metadata line.');
    }
  }
  return nodes;
}

List<List<String>> readEdges(String source) {
  final edges = <List<String>>[];
  for (final line in const LineSplitter().convert(source)) {
    final match = edgeDeclaration.firstMatch(line);
    if (match != null) {
      edges.add([match.group(1)!, match.group(3)!, match.group(2) ?? '']);
    }
  }
  return edges;
}

List<Map<String, dynamic>> readJourneys(String source) {
  final matches = RegExp(
    r'^@journey\s+\|\s+(.+)$',
    multiLine: true,
  ).allMatches(source);
  return matches.map((match) {
    final fields = parseFields(match.group(1)!);
    final nodeIds = (fields['nodes'] ?? '')
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    return <String, dynamic>{
      'title': fields['title'] ?? 'Journey',
      'short': fields['short'] ?? nodeIds.join(' → '),
      'nodes': nodeIds,
    };
  }).toList();
}

Set<String> readRoutes(String routeSource) {
  return RegExp(
    r"static const \w+\s*=\s*'([^']+)'",
  ).allMatches(routeSource).map((match) => match.group(1)!).toSet();
}

void validate(
  List<Map<String, dynamic>> nodes,
  List<List<String>> edges,
  List<Map<String, dynamic>> journeys,
  Set<String> knownRoutes,
) {
  final ids = nodes.map((node) => node['id'] as String).toSet();
  if (ids.length != nodes.length) {
    fail('Duplicate @node metadata ID found.');
  }

  for (final edge in edges) {
    for (final id in edge.take(2)) {
      if (!ids.contains(id)) {
        fail('Connection references unknown node "$id".');
      }
    }
  }

  for (final journey in journeys) {
    final journeyNodes = (journey['nodes'] as List<dynamic>).cast<String>();
    for (final id in journeyNodes) {
      if (!ids.contains(id)) {
        fail('Journey "${journey['title']}" references unknown node "$id".');
      }
    }
  }

  final routePattern = RegExp(r'/[a-z][a-z0-9-]*');
  for (final node in nodes) {
    final route = node['route'] as String;
    if (route.contains('no route')) {
      continue;
    }
    for (final match in routePattern.allMatches(route)) {
      final value = match.group(0)!;
      if (!knownRoutes.contains(value)) {
        fail('Node "${node['id']}" uses unknown route "$value".');
      }
    }
  }
}

String edgeType(List<String> edge, Map<String, Map<String, dynamic>> byId) {
  final label = edge[2].toLowerCase();
  final targetStatus = byId[edge[1]]!['status'];
  if (targetStatus == 'blocked' ||
      label.contains('not connected') ||
      label.contains('not verified')) {
    return 'blocked';
  }
  if (targetStatus == 'guarded') {
    return 'guard';
  }
  if (label == 'at limit' || label == 'existing buyer') {
    return 'needs';
  }
  const directLabels = {
    'first run',
    'sign in',
    'select',
    'tab',
    'media',
    'thread',
    'upgrade',
    'choose plan',
    'new',
    'manage',
    'messages',
    'team',
  };
  return directLabels.contains(label) ? 'straight' : 'branch';
}

void main() {
  final source = File(sourcePath).readAsStringSync();
  final routeSource = File(routeNamesPath).readAsStringSync();
  final nodes = readNodes(source);
  final rawEdges = readEdges(source);
  final journeys = readJourneys(source);
  final knownRoutes = readRoutes(routeSource);
  validate(nodes, rawEdges, journeys, knownRoutes);

  final byId = {for (final node in nodes) node['id'] as String: node};
  final edges = rawEdges
      .map((edge) => [edge[0], edge[1], edge[2], edgeType(edge, byId)])
      .toList();
  final edgePairs = edges.map((edge) => '${edge[0]}\u0000${edge[1]}').toSet();
  for (final journey in journeys) {
    final ids = (journey['nodes'] as List<dynamic>).cast<String>();
    journey['edges'] = <List<String>>[
      for (var index = 0; index < ids.length - 1; index++)
        [ids[index], ids[index + 1]],
    ];
    for (final edge in journey['edges'] as List<List<String>>) {
      if (!edgePairs.contains('${edge[0]}\u0000${edge[1]}')) {
        fail(
          'Journey "${journey['title']}" skips a defined connection '
          '"${edge[0]} → ${edge[1]}".',
        );
      }
    }
  }

  final data = <String, dynamic>{
    'nodes': nodes,
    'edges': edges,
    'journeys': journeys,
    'statusLabels': {
      'complete': 'Completed UI',
      'integration': 'Needs integration',
      'guarded': 'Guarded route',
      'planned': 'Planned',
      'blocked': 'Blocked',
    },
  };
  final output = StringBuffer()
    ..writeln('// Generated from $sourcePath. Do not edit directly.')
    ..writeln('window.APP_FLOW_DATA = ')
    ..write(const JsonEncoder.withIndent('  ').convert(data))
    ..writeln(';');
  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(output.toString());
  stdout.writeln(
    'Updated $outputPath with ${nodes.length} nodes, ${edges.length} '
    'connections, and ${journeys.length} journeys.',
  );
}
