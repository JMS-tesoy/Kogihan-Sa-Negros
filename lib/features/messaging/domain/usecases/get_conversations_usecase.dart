import '../entities/conversation_entity.dart';
import '../repositories/messaging_repository.dart';

class GetConversationsUsecase {
  const GetConversationsUsecase(this.repository);

  final MessagingRepository repository;

  Future<List<ConversationEntity>> call() {
    return repository.getConversations();
  }
}
