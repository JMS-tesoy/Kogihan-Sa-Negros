abstract final class CurrencyFormatters {
  static String php(num amount) {
    return 'PHP ${amount.toStringAsFixed(2)}';
  }
}
