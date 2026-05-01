import 'package:flutter/material.dart';

import '../../domain/entities/inquiry_entity.dart';

class InquiryCard extends StatelessWidget {
  const InquiryCard({super.key, required this.inquiry});

  final InquiryEntity inquiry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(inquiry.message),
        subtitle: Text(inquiry.status.name),
      ),
    );
  }
}
