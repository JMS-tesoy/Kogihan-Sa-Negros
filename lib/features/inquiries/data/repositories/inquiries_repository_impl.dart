import '../../domain/entities/inquiry_entity.dart';
import '../../domain/repositories/inquiries_repository.dart';
import '../datasources/inquiries_remote_datasource.dart';
import '../models/inquiry_model.dart';

class InquiriesRepositoryImpl implements InquiriesRepository {
  InquiriesRepositoryImpl({InquiriesRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? InquiriesRemoteDatasource();

  final InquiriesRemoteDatasource _remoteDatasource;

  @override
  Future<List<InquiryEntity>> getInquiries() {
    return _remoteDatasource.getInquiries();
  }

  @override
  Future<void> sendInquiry(InquiryEntity inquiry) {
    final model = InquiryModel(
      id: inquiry.id,
      propertyId: inquiry.propertyId,
      message: inquiry.message,
      status: inquiry.status,
      createdAt: inquiry.createdAt,
    );
    return _remoteDatasource.sendInquiry(model);
  }
}
