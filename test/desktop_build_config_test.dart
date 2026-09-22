import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String normalizeWorkflow(String source) => source.replaceAll('\r\n', '\n');

void main() {
  test('workflow assertions accept Windows checkout line endings', () {
    final source = File('.github/workflows/desktop.yml').readAsStringSync();
    final lf = normalizeWorkflow(source);
    expect(normalizeWorkflow(lf.replaceAll('\n', '\r\n')), lf);
  });
  test('desktop startup resources are bundled locally', () {
    final index = File('web/index.html').readAsStringSync();
    expect(index, contains('vendor/maplibre-gl/maplibre-gl.js'));
    expect(index, contains('vendor/maplibre-gl/maplibre-gl.css'));
    expect(index, isNot(contains('src="https://')));
    expect(index, isNot(contains('href="https://')));
    expect(
      File('web/vendor/maplibre-gl/maplibre-gl.js').lengthSync(),
      greaterThan(0),
    );
    expect(
      File('web/vendor/maplibre-gl/maplibre-gl.css').lengthSync(),
      greaterThan(0),
    );
  });

  test('Tauri desktop builds use local Flutter web resources', () {
    final config =
        jsonDecode(File('src-tauri/tauri.conf.json').readAsStringSync())
            as Map<String, dynamic>;
    final build = config['build'] as Map<String, dynamic>;
    expect(build['beforeBuildCommand'], 'npm run build:web:desktop');

    final package =
        jsonDecode(File('package.json').readAsStringSync())
            as Map<String, dynamic>;
    final scripts = package['scripts'] as Map<String, dynamic>;
    expect(scripts['build:web:desktop'], contains('--no-web-resources-cdn'));
    expect(
      scripts['desktop:build:linux'],
      contains('--bundles deb,rpm,appimage'),
    );
  });

  test('desktop release workflow builds Linux artifacts', () {
    final workflow = normalizeWorkflow(
      File('.github/workflows/desktop.yml').readAsStringSync(),
    );
    expect(workflow, contains('ubuntu-22.04'));
    expect(workflow, contains('miriago-desktop-linux'));
    expect(workflow, contains('libwebkit2gtk-4.1-dev'));
    expect(workflow, contains('npm run desktop:build:linux'));
    expect(workflow, contains('bash tool/package_linux.sh'));
    expect(workflow, contains('*.AppImage'));
    expect(workflow, contains('*.deb'));
    expect(workflow, contains('*.rpm'));
    expect(workflow, contains('if-no-files-found: error'));
    expect(RegExp(r'\bnsis\b').hasMatch(workflow), isFalse);
    expect(workflow, isNot(contains('setup.exe')));
    expect(
      workflow,
      contains(
        "if: runner.os == 'Windows'\n        run: npm run desktop:build:portable",
      ),
    );
    expect(
      workflow,
      contains("if: runner.os == 'macOS'\n        run: npm run desktop:build"),
    );
    expect(
      workflow,
      contains(
        "if: runner.os == 'Linux'\n        run: npm run desktop:build:linux",
      ),
    );
    final package =
        jsonDecode(File('package.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(
      (package['scripts'] as Map)['desktop:build:portable'],
      'tauri build --no-bundle',
    );
  });

  test('desktop bootstrap skips service workers inside Tauri', () {
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(bootstrap, contains("typeof window.__TAURI__ !== 'undefined'"));
    expect(bootstrap, contains('? {}'));
  });

  test('desktop startup remains visible before Flutter initializes', () {
    final index = File('web/index.html').readAsStringSync();
    final monitor = File('web/desktop_startup_monitor.js').readAsStringSync();
    final cleanup = File('web/desktop_cache_cleanup.js').readAsStringSync();

    expect(index, contains('miriago-startup-status'));
    expect(monitor, contains("window.addEventListener('error'"));
    expect(monitor, contains("window.addEventListener('unhandledrejection'"));
    expect(cleanup, contains('navigator.serviceWorker.controller'));
    expect(cleanup, contains('window.location.reload()'));
  });
}
