import 'package:flutter/widgets.dart';

import 'audio/game_audio_controller.dart';
import 'bundled_licenses.dart';
import 'goblin_flip_app.dart';

export 'goblin_flip_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledFontLicenses();
  runApp(GoblinFlipApp(gameAudioController: AudioplayersGameAudioController()));
}
