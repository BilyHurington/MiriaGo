import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../app/toast.dart';
import '../components/components.dart';
import 'component_gallery.dart';

/// Standalone entry for the component gallery (no repository / router):
///
/// ```
/// flutter run -t lib/ui/dev/gallery_preview_main.dart
/// flutter build web -t lib/ui/dev/gallery_preview_main.dart -o <dir>
/// ```
void main() => runApp(const GalleryPreviewApp());

/// Minimal app hosting [ComponentGalleryPage] with a toast host.
class GalleryPreviewApp extends StatefulWidget {
  const GalleryPreviewApp({super.key});

  @override
  State<GalleryPreviewApp> createState() => _GalleryPreviewAppState();
}

class _GalleryPreviewAppState extends State<GalleryPreviewApp> {
  final _toasts = ToastController();

  @override
  void dispose() {
    _toasts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _toasts,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Miria components',
        theme: buildMiriaTheme(MiriaColors.light),
        darkTheme: buildMiriaTheme(MiriaColors.dark),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => ToastHost(child: child!),
        home: const ComponentGalleryPage(),
      ),
    );
  }
}
