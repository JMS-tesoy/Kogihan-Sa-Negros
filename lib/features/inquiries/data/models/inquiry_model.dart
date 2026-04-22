import '../../domain/entities/inquiry_entity.dart';

class InquiryModel extends InquiryEntity {
  const InquiryModel({
    required super.id,
    required super.propertyId,
    required super.message,
    super.status,
    super.createdAt,
  });
}
