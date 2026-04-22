import '../models/inquiry_model.dart';

class InquiriesRemoteDatasource {
  Future<void> sendInquiry(InquiryModel inquiry) async {}

  Future<List<InquiryModel>> getInquiries() async {
    return const <InquiryModel>[];
  }
}
