abstract final class CurrencyFormatters {
  static String php(num amount) {
    if (amount >= 1000000) {
      return '₱${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '₱${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '₱${amount.toStringAsFixed(0)}';
  }

  static String phpFull(num amount) {
    final String formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '₱$formatted';
  }
}
