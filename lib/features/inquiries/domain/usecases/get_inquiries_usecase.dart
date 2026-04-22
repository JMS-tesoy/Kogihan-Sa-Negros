import '../entities/inquiry_entity.dart';
import '../repositories/inquiries_repository.dart';

class GetInquiriesUsecase {
  const GetInquiriesUsecase(this.repository);

  final InquiriesRepository repository;

  Future<List<InquiryEntity>> call() {
    return repository.getInquiries();
  }
}
