import 'dart:convert';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Entry point for `flutter drive` integration tests.
///
/// We print a single machine-readable line (`PERF_RESULT:...`) so shell scripts
/// can archive benchmark metrics without fragile log scraping heuristics.
Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data != null) {
        // Keep this prefix stable; scripts depend on it.
        // ignore: avoid_print
        print('PERF_RESULT:${jsonEncode(data)}');
      }
    },
  );
}
