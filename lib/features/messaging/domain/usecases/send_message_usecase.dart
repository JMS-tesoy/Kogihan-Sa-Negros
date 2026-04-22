import '../entities/message_entity.dart';
import '../repositories/messaging_repository.dart';

class SendMessageUsecase {
  const SendMessageUsecase(this.repository);

  final MessagingRepository repository;

  Future<void> call(MessageEntity message) {
    return repository.sendMessage(message);
  }
}
