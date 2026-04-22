import '../repositories/messaging_repository.dart';

class MarkMessageReadUsecase {
  const MarkMessageReadUsecase(this.repository);

  final MessagingRepository repository;

  Future<void> call(String messageId) {
    return repository.markMessageRead(messageId);
  }
}
