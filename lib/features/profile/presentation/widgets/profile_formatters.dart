String formatSubscriptionDate(DateTime? value) {
  if (value == null) return 'No renewal date yet';

  const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final DateTime localValue = value.toLocal();
  return '${months[localValue.month - 1]} ${localValue.day}, ${localValue.year}';
}

String profileTextValue(Object? value) {
  return value == null ? '' : value.toString().trim();
}
