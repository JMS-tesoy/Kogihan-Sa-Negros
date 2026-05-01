import 'package:flutter/material.dart';

class AgentStatsHeader extends StatelessWidget {
  const AgentStatsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const <Widget>[
        Expanded(
          child: _StatTile(label: 'Listings', value: '0'),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StatTile(label: 'Inquiries', value: '0'),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label),
          ],
        ),
      ),
    );
  }
}
