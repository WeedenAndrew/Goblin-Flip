abstract final class ReceiptSecurity {
  static const maxIdentifierLength = 256;

  static final RegExp _safeIdentifier = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,255}$',
  );

  static bool isSafeIdentifier(String value) {
    return value.length <= maxIdentifierLength &&
        _safeIdentifier.hasMatch(value);
  }
}
