import 'package:flutter/material.dart';

import '../../domain/entities/plan_entity.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    this.onSelected,
  });

  final PlanEntity plan;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(plan.name),
        subtitle: Text(plan.description),
        trailing: Text(plan.price.toStringAsFixed(2)),
        onTap: onSelected,
      ),
    );
  }
}
