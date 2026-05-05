import 'package:flutter/material.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?action,
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onPressed,
  });

  final String title;
  final String? actionText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (actionText != null)
          TextButton(
            onPressed: onPressed,
            child: Text(actionText!),
          ),
      ],
    );
  }
}
