import 'package:flutter/material.dart';

import '../../domain/entities/plan_entity.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, this.onSelected});

  final PlanEntity plan;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        title: Text(plan.title),
        subtitle: Text(plan.billingLabel),
        trailing: Text(
          plan.priceLabel,
          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
        ),
        onTap: onSelected,
      ),
    );
  }
}
