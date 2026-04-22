class ConversationEntity {
  const ConversationEntity({
    required this.id,
    required this.title,
    this.lastMessage = '',
  });

  final String id;
  final String title;
  final String lastMessage;
}
