import '../entities/inquiry_entity.dart';

abstract interface class InquiriesRepository {
  Future<void> sendInquiry(InquiryEntity inquiry);

  Future<List<InquiryEntity>> getInquiries();
}
