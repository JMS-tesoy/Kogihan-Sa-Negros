String passwordSignInErrorMessage(String message) {
  final String normalizedMessage = message.toLowerCase();
  if (normalizedMessage.contains('email rate limit exceeded')) {
    return 'Too many signup attempts for now. The account may already exist, so try Login first. If it fails, wait a bit before signing up again.';
  }

  return message;
}
