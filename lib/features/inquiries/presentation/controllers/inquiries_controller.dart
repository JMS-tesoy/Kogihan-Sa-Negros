import 'package:flutter/foundation.dart';

import '../../domain/entities/inquiry_entity.dart';
import '../../domain/usecases/get_inquiries_usecase.dart';

class InquiriesController extends ChangeNotifier {
  InquiriesController({this.getInquiriesUsecase});

  final GetInquiriesUsecase? getInquiriesUsecase;

  List<InquiryEntity> _inquiries = const <InquiryEntity>[];

  List<InquiryEntity> get inquiries => _inquiries;

  Future<void> load() async {
    _inquiries = await getInquiriesUsecase?.call() ?? const <InquiryEntity>[];
    notifyListeners();
  }
}
