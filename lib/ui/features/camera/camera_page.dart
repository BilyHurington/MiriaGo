import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/capture/capture_session.dart';
import '../../../application/capture/visit_record_commit.dart';
import '../../../application/plan_session.dart';
import '../../../application/platform_capabilities.dart';
import '../../../application/settings_store.dart';
import '../../../camera_reference/native_camera_controller.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/pilgrimage_plan_controller.dart';
import '../../../records/visit_record_file_ops_stub.dart'
    if (dart.library.io) '../../../records/visit_record_file_ops_io.dart'
    as file_ops;
import '../../app/router.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import 'camera_awesome_body.dart';
import 'camera_controls.dart';
import 'camera_layouts.dart';
import 'camera_stage.dart';
import 'capture_confirm_page.dart';
import 'photo_location_sheet.dart';

typedef CameraImagePicker = Future<XFile?> Function();

/// Reference camera (DESIGN §8.5): always dark and immersive; only the
/// preview and the reference are inside the viewfinder.
class CameraPage extends StatefulWidget {
  const CameraPage({
    required this.pointId,
    @visibleForTesting this.nativeCameraController,
    @visibleForTesting this.pickImage,
    @visibleForTesting this.capabilities,
    super.key,
  });

  final String pointId;

  /// Injected by tests; the page creates and owns one otherwise.
  final NativeCameraController? nativeCameraController;

  /// Injected by tests; defaults to the gallery picker.
  final CameraImagePicker? pickImage;

  /// Overrides the provided [PlatformCapabilities] (tests).
  final PlatformCapabilities? capabilities;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final ImagePicker _imagePicker = ImagePicker();
  CaptureSession? _session;
  NativeCameraController? _native;
  bool _ownsNative = false;
  NativeCameraDeviceControls? _nativeDevice;
  bool _nativeFailed = false;
  String? _nativeError;
  late PlatformCapabilities _capabilities;
  bool _initialized = false;
  (double, bool, double)? _appliedConfiguration;
  ThemeData? _darkTheme;
  AppSettings? _darkThemeSettings;

  PlanSession? _planSession;
  SettingsStore? _settingsStore;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _capabilities =
        widget.capabilities ??
        context.read<PlatformCapabilities?>() ??
        PlatformCapabilities.current();
    if (_capabilities.isMobile) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
    }
    _planSession = context.read<PlanSession?>()?..addListener(_planChanged);
    _settingsStore = context.read<SettingsStore?>()
      ?..addListener(_settingsChanged);
    _planChanged(initial: true);
  }

  PilgrimagePlanController? get _planController {
    final session = _planSession;
    return session != null && session.isReady ? session.controller : null;
  }

  void _planChanged({bool initial = false}) {
    if (!mounted) return;
    final point = _planController?.pointById(widget.pointId);
    final existing = _session;
    if (existing != null) {
      if (point != null) existing.updatePoint(point);
      return;
    }
    if (point == null) {
      if (!initial) setState(() {});
      return;
    }
    _createSession(point);
  }

  void _settingsChanged() {
    final store = _settingsStore;
    if (store != null) _session?.updateSettings(store.settings);
  }

  void _createSession(PilgrimagePoint point) {
    final store = _settingsStore;
    final session = CaptureSession(
      point: point,
      settings: store?.settings ?? const AppSettings(),
      capabilities: _capabilities,
      loadPersistedSettings: store?.repository.loadAppSettings,
      savePhotoLocationStrategy: store == null
          ? null
          : (strategy) => store.patch(
              (current) => current.copyWith(photoLocationStrategy: strategy),
            ),
    );
    session
      ..openConfirmation = _openConfirmation
      ..promptPhotoLocationStrategy = _promptStrategy
      ..onMessage = _showMessage;
    _session = session;
    if (_capabilities.isMobile && _capabilities.hasLiveCamera) {
      _ownsNative = widget.nativeCameraController == null;
      final native = widget.nativeCameraController ?? NativeCameraController();
      native.addListener(_nativeChanged);
      _native = native;
      _nativeDevice = NativeCameraDeviceControls(native);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      session
        ..addListener(_changed)
        ..start();
      // The shutter asks again when this early prompt fails.
      if (_capabilities.hasLiveCamera) session.askPhotoLocationStrategyEarly();
    });
  }

  @override
  void dispose() {
    if (_capabilities.isMobile) {
      // Back to the app default (all orientations, DESIGN §10 Δ13).
      unawaited(SystemChrome.setPreferredOrientations(const []));
    }
    _planSession?.removeListener(_planChanged);
    _settingsStore?.removeListener(_settingsChanged);
    _session
      ?..removeListener(_changed)
      ..dispose();
    _native?.removeListener(_nativeChanged);
    if (_ownsNative) _native?.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _nativeChanged() {
    final native = _native;
    if (native == null || !mounted) return;
    if (native.error != null && !_nativeFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _nativeFailed = true;
          _nativeError = native.error;
        });
      });
    }
  }

  void _showMessage(CaptureMessage message) {
    if (!mounted) return;
    context.showToast(
      message.text,
      kind: switch (message.kind) {
        CaptureMessageKind.running => ToastKind.running,
        CaptureMessageKind.warning => ToastKind.warning,
        CaptureMessageKind.error => ToastKind.error,
      },
    );
  }

  Future<PhotoLocationStrategy?> _promptStrategy() async {
    if (!mounted) return null;
    return showPhotoLocationChoiceSheet(context);
  }

  // ---------------------------------------------------------------------
  // Orientation (old rules: pickers and the confirmation are portrait).

  bool get _isLandscape =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  Future<void> _setPortrait() async {
    if (!_capabilities.isMobile) return;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _restoreCameraOrientation({required bool landscape}) async {
    if (!_capabilities.isMobile) return;
    await SystemChrome.setPreferredOrientations(
      landscape
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
  }

  void _preferPortraitUi() => unawaited(_setPortrait());

  void _preferLandscapeUi() {
    if (!_capabilities.isMobile) return;
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
  }

  Future<XFile?> _pickImageInPortrait({bool restoreOrientation = true}) async {
    final restoreLandscape = _isLandscape;
    await _setPortrait();
    try {
      final picker = widget.pickImage;
      if (picker != null) return await picker();
      return await _imagePicker.pickImage(source: ImageSource.gallery);
    } finally {
      if (mounted && restoreOrientation) {
        await _restoreCameraOrientation(landscape: restoreLandscape);
      }
    }
  }

  // ---------------------------------------------------------------------
  // Actions.

  /// Closes the camera. Opened by a deep link or after a browser reload
  /// there is no page underneath, so it goes to 巡礼 instead.
  void _back() {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      unawaited(Navigator.of(context).maybePop());
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.go);
    }
  }

  Future<void> _pickReference() async {
    final session = _session;
    if (session == null) return;
    final picked = await _pickImageInPortrait();
    if (picked == null || !mounted) return;
    final error = await session.usePickedReference(picked);
    if (error != null && mounted) {
      context.showToast(error, kind: ToastKind.error);
    }
  }

  Future<void> _pickGallery() async {
    final session = _session;
    if (session == null) return;
    final restoreLandscape = _isLandscape;
    final picked = await _pickImageInPortrait(restoreOrientation: false);
    if (picked == null || !mounted) {
      await _restoreCameraOrientation(landscape: restoreLandscape);
      return;
    }
    final imported = await session.importGalleryPhoto(
      picked.path,
      native: _native,
      restoreLandscape: restoreLandscape,
    );
    if (!imported && mounted) {
      await _restoreCameraOrientation(landscape: restoreLandscape);
    }
  }

  void _captureNative() {
    final session = _session;
    final native = _native;
    if (session == null || native == null) return;
    unawaited(session.captureWithNativeCamera(native));
  }

  Future<VisitRecordConfirmationResult?> _openConfirmation(
    CaptureConfirmationRequest request,
  ) async {
    if (!mounted) {
      file_ops.deleteVisitRecordLocalFile(request.photoPath);
      return null;
    }
    final restoreLandscape = request.restoreLandscape ?? _isLandscape;
    unawaited(_setPortrait());
    final result = await openCaptureConfirmation(
      context,
      request: request,
      controller: _planController,
    );
    if (!mounted) return result;
    if (result == VisitRecordConfirmationResult.completed) {
      // 保存并标记完成 closes the camera too.
      _back();
      return result;
    }
    await _restoreCameraOrientation(landscape: restoreLandscape);
    return result;
  }

  CameraActions get _actions => CameraActions(
    onBack: _back,
    onPickReference: () => unawaited(_pickReference()),
    onPickGallery: () => unawaited(_pickGallery()),
    onCapture: _captureNative,
    onPreferPortraitUi: _preferPortraitUi,
    onPreferLandscapeUi: _preferLandscapeUi,
  );

  ThemeData _themeFor(AppSettings settings) {
    if (_darkTheme == null || !identical(settings, _darkThemeSettings)) {
      _darkThemeSettings = settings;
      _darkTheme = buildMiriaTheme(
        resolveMiriaColors(
          brightness: Brightness.dark,
          palette: settings.themePalette,
          customAccentValue: settings.customThemeColorValue,
        ),
      );
    }
    return _darkTheme!;
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final settings =
        session?.settings ?? _settingsStore?.settings ?? const AppSettings();
    final theme = _themeFor(settings);
    return Theme(
      data: theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.colors.darkroom,
            body: session != null
                ? _buildBody(context, session)
                : _planController == null
                ? const Center(child: ProgressRing())
                : _MissingPoint(onBack: _back),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CaptureSession session) {
    final landscape = _isLandscape;
    if (!_capabilities.hasLiveCamera) {
      return CameraNoLiveBody(
        session: session,
        landscape: landscape,
        message: _capabilities.isPlainWeb ? 'Web 预览不启动实时相机' : '当前平台不支持实时相机',
        onBack: _back,
        onPickReference: () => unawaited(_pickReference()),
        onPickGallery: () => unawaited(_pickGallery()),
      );
    }
    final native = _native;
    final device = _nativeDevice;
    if (native != null && device != null && !_nativeFailed) {
      return _buildNative(context, session, native, device, landscape);
    }
    if (_capabilities.isIOS) {
      return CameraUnavailableMessage(
        message: _nativeError ?? '原生相机初始化失败',
        onBack: _back,
      );
    }
    return CameraAwesomeBody(
      session: session,
      actions: _actions,
      landscape: landscape,
      nativeController: native,
    );
  }

  Widget _buildNative(
    BuildContext context,
    CaptureSession session,
    NativeCameraController native,
    NativeCameraDeviceControls device,
    bool landscape,
  ) {
    final orientation = landscape
        ? Orientation.landscape
        : Orientation.portrait;
    final ratio = session.captureAspectRatio(orientation);
    final crop = session.cropNativeCapture;
    final initialZoom = session.settings.cameraMinZoom;
    final configuration = (ratio, crop, initialZoom);
    if (configuration != _appliedConfiguration) {
      _appliedConfiguration = configuration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          native
              .configureCapture(
                captureAspectRatio: ratio,
                cropCaptureToAspectRatio: crop,
                preferredInitialZoomRatio: initialZoom,
              )
              .catchError((Object error) {
                // Retried before the next capture; takePicture reports it.
                debugPrint('Native camera configuration failed: $error');
              }),
        );
      });
    }
    final stage = CameraStage(
      mode: session.mode,
      reference: session.reference,
      overlayOpacity: session.overlayOpacity,
      captureAspectRatio: ratio,
      referenceScale: session.settings.referenceImageScale,
      padding: landscape ? 2 : 8,
      gap: landscape ? 2 : 8,
      // Same key in every layout: the platform view is reparented.
      preview: NativeCameraPreview(key: native.previewKey, controller: native),
    );
    return landscape
        ? CameraLandscapeLayout(
            session: session,
            device: device,
            stage: stage,
            actions: _actions,
          )
        : CameraPortraitLayout(
            session: session,
            device: device,
            stage: stage,
            actions: _actions,
          );
  }
}

/// Web / Tauri: no live camera. Reference and 「从相册导入」 only.
class CameraNoLiveBody extends StatelessWidget {
  const CameraNoLiveBody({
    required this.session,
    required this.landscape,
    required this.message,
    required this.onBack,
    required this.onPickReference,
    required this.onPickGallery,
    super.key,
  });

  final CaptureSession session;
  final bool landscape;
  final String message;
  final VoidCallback onBack;
  final VoidCallback onPickReference;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reference = session.reference;
    final stage = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.x3),
      child: AspectStageFrame(
        aspectRatio: session.captureAspectRatio(
          landscape ? Orientation.landscape : Orientation.portrait,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (reference.hasImage)
              CameraReferenceImage(
                source: reference,
                scale: session.settings.referenceImageScale,
              ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(Space.x2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.darkroomSurface.withValues(alpha: 0.86),
                    borderRadius: Radii.pillAll,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.x3,
                      vertical: Space.x1,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Symbols.no_photography_rounded,
                          size: 16,
                          color: c.onDarkroom,
                        ),
                        const SizedBox(width: Space.x2),
                        Flexible(
                          child: Text(
                            message,
                            key: const ValueKey('camera-no-live-message'),
                            style: context.text.labelMedium?.copyWith(
                              color: c.onDarkroom,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final import = MiriaButton(
      key: const ValueKey('camera-gallery-import'),
      label: '从相册导入',
      icon: Symbols.photo_library_rounded,
      size: MiriaButtonSize.lg,
      onPressed: onPickGallery,
    );
    return SafeArea(
      child: Column(
        children: [
          CameraTopBar(
            title: session.point.name,
            onBack: onBack,
            trailing: [
              DarkroomButton(
                key: const ValueKey('camera-reference-button'),
                icon: Symbols.image_rounded,
                tooltip: '参考图',
                onPressed: onPickReference,
              ),
            ],
          ),
          Expanded(child: stage),
          Padding(
            padding: const EdgeInsets.all(Space.x4),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: SizedBox(width: double.infinity, child: import),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// iOS: the native camera failed to start.
class CameraUnavailableMessage extends StatelessWidget {
  const CameraUnavailableMessage({
    required this.message,
    required this.onBack,
    super.key,
  });

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.error_rounded, size: 36, color: c.railMuted),
              const SizedBox(height: Space.x3),
              Text(
                'iOS 原生相机未启动',
                style: context.text.titleMedium?.copyWith(color: c.onDarkroom),
              ),
              const SizedBox(height: Space.x2),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(color: c.railMuted),
              ),
              const SizedBox(height: Space.x5),
              MiriaButton(
                label: '返回',
                icon: Symbols.arrow_back_rounded,
                onPressed: onBack,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingPoint extends StatelessWidget {
  const _MissingPoint({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(Space.x3),
              child: DarkroomButton(
                icon: Symbols.arrow_back_rounded,
                tooltip: '返回',
                onPressed: onBack,
              ),
            ),
          ),
          const Expanded(
            child: EmptyState(
              icon: Symbols.location_off_rounded,
              title: '找不到这个点位',
              message: '它可能已被删除或不在当前计划中。',
            ),
          ),
        ],
      ),
    );
  }
}
