import '../entities/message_entity.dart';
import '../repositories/messaging_repository.dart';

class GetMessagesUsecase {
  const GetMessagesUsecase(this.repository);

  final MessagingRepository repository;

  Future<List<MessageEntity>> call(String conversationId) {
    return repository.getMessages(conversationId);
  }
}
