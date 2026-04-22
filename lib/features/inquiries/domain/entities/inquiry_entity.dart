import '../../../../core/enums/inquiry_status.dart';

class InquiryEntity {
  const InquiryEntity({
    required this.id,
    required this.propertyId,
    required this.message,
    this.status = InquiryStatus.newInquiry,
    this.createdAt,
  });

  final String id;
  final String propertyId;
  final String message;
  final InquiryStatus status;
  final DateTime? createdAt;
}
