import '../entities/inquiry_entity.dart';
import '../repositories/inquiries_repository.dart';

class SendInquiryUsecase {
  const SendInquiryUsecase(this.repository);

  final InquiriesRepository repository;

  Future<void> call(InquiryEntity inquiry) {
    return repository.sendInquiry(inquiry);
  }
}
