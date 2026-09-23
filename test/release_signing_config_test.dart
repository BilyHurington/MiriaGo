@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'release uses explicit credentials and both release gates depend on validation',
    () {
      final script = File('android/app/build.gradle.kts').readAsStringSync();
      expect(
        script,
        contains('signingConfig = signingConfigs.getByName("release")'),
      );
      expect(script, isNot(contains('signingConfigs.getByName("debug")')));
      expect(script, contains('it.name == "preReleaseBuild"'));
      expect(script, contains('it.name == "validateSigningRelease"'));
      expect(script, contains('dependsOn(verifyReleaseSigning)'));
      expect(script, contains('orElse("key.properties")'));
      expect(script, contains('releaseKeystoreFile.canRead()'));
      expect(script, contains('missingSigningProperties.isNotEmpty()'));
      expect(script, isNot(contains('preDebugBuild')));
    },
  );

  test(
    'release CI requires all signing inputs without printing their values',
    () {
      final workflow = File('.github/workflows/release.yml').readAsStringSync();
      expect(
        workflow,
        contains(
          'for name in ANDROID_KEYSTORE_BASE64 ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD; do',
        ),
      );
      expect(workflow, contains(r'if [ -z "${!name}" ]; then'));
      expect(workflow, contains('exit 1'));
      expect(workflow, contains('umask 077'));
      expect(workflow, isNot(contains(r'echo "$ANDROID_KEYSTORE_BASE64"')));
      expect(workflow, isNot(contains('set -x')));
    },
  );
}
