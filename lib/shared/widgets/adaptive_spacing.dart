import 'package:flutter/material.dart';

class AdaptiveSpacing extends StatelessWidget {
  const AdaptiveSpacing({super.key, this.small = 12, this.large = 24});

  final double small;
  final double large;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(height: width >= 600 ? large : small);
  }
}
