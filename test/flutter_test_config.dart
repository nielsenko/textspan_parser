import 'dart:async';
import 'dart:io';

import 'package:golden_toolkit/golden_toolkit.dart';

Future<void> main(FutureOr<void> Function() testMain) async {
  return GoldenToolkit.runWithConfiguration(
    () async {
      await loadAppFonts();
      await testMain();
    },
    config: GoldenToolkitConfiguration(
      // Flutter is not pixel perfect between platforms, especially regarding font
      // rendering. For now the goldens are macOS only.
      skipGoldenAssertion: () => !Platform.isMacOS,
    ),
  );
}
