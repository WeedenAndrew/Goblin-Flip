import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _bundledFontLicenses = <String, String>{
  'Cinzel': 'assets/fonts/cinzel/OFL.txt',
  'Cinzel Decorative': 'assets/fonts/cinzel_decorative/OFL.txt',
  'Almendra': 'assets/fonts/almendra/OFL.txt',
};

/// Exposes the licenses shipped with the local fonts through Flutter's
/// standard license registry.
void registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final entry in _bundledFontLicenses.entries) {
      final license = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks(<String>[entry.key], license);
    }
  });
}
