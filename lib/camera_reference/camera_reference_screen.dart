import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_theme.dart';

enum ReferenceMode { split, overlay }

class CameraReferenceScreen extends StatefulWidget {
  const CameraReferenceScreen({super.key});

  @override
  State<CameraReferenceScreen> createState() => _CameraReferenceScreenState();
}

class _CameraReferenceScreenState extends State<CameraReferenceScreen>
    with WidgetsBindingObserver {
  final ImagePicker _imagePicker = ImagePicker();

  CameraController? _cameraController;
  XFile? _referenceImage;
  ReferenceMode _mode = ReferenceMode.split;
  double _overlayOpacity = 0.46;
  bool _isInitializingCamera = true;
  bool _isTakingPicture = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializingCamera = true;
      _cameraError = null;
    });

    final status = await Permission.camera.request();
    if (!mounted) {
      return;
    }

    if (!status.isGranted) {
      setState(() {
        _isInitializingCamera = false;
        _cameraError = 'Camera permission is required.';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isInitializingCamera = false;
          _cameraError = 'No camera is available on this device.';
        });
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController?.dispose();
      _cameraController = controller;
      await controller.initialize();

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializingCamera = false;
      });
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializingCamera = false;
        _cameraError = error.description ?? 'Failed to initialize camera.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializingCamera = false;
        _cameraError = 'Failed to initialize camera.';
      });
    }
  }

  Future<void> _pickReferenceImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _referenceImage = picked;
    });
  }

  Future<void> _takePicture() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    setState(() {
      _isTakingPicture = true;
    });

    try {
      final picture = await controller.takePicture();
      final savedPath = await _copyPictureToAppDirectory(picture);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved to $savedPath')));
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.description ?? 'Capture failed.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Capture failed.')));
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  Future<String> _copyPictureToAppDirectory(XFile picture) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final photosDirectory = Directory(
      '${documentsDirectory.path}/reference_photos',
    );
    if (!photosDirectory.existsSync()) {
      photosDirectory.createSync(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final targetPath = '${photosDirectory.path}/capture_$timestamp.jpg';
    await File(picture.path).copy(targetPath);
    return targetPath;
  }

  void _setMode(ReferenceMode mode) {
    setState(() {
      _mode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    final hasReadyCamera = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: AppColors.cameraDarkSurface,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              hasReference: _referenceImage != null,
              onPickReference: _pickReferenceImage,
            ),
            Expanded(
              child: _ReferenceWorkspace(
                mode: _mode,
                controller: hasReadyCamera ? controller : null,
                referenceImage: _referenceImage,
                overlayOpacity: _overlayOpacity,
                isInitializingCamera: _isInitializingCamera,
                cameraError: _cameraError,
                onRetryCamera: _initializeCamera,
              ),
            ),
            _BottomToolbar(
              mode: _mode,
              overlayOpacity: _overlayOpacity,
              isCaptureEnabled: hasReadyCamera && !_isTakingPicture,
              isTakingPicture: _isTakingPicture,
              onModeChanged: _setMode,
              onOpacityChanged: (value) {
                setState(() {
                  _overlayOpacity = value;
                });
              },
              onCapture: _takePicture,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.hasReference, required this.onPickReference});

  final bool hasReference;
  final VoidCallback onPickReference;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.cameraDarkOverlay,
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Reference Camera',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onPickReference,
            icon: Icon(
              hasReference ? Icons.image : Icons.image_outlined,
              size: 20,
            ),
            label: Text(hasReference ? 'Change' : 'Reference'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF35404A)),
              backgroundColor: const Color(0xFF222930),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceWorkspace extends StatelessWidget {
  const _ReferenceWorkspace({
    required this.mode,
    required this.controller,
    required this.referenceImage,
    required this.overlayOpacity,
    required this.isInitializingCamera,
    required this.cameraError,
    required this.onRetryCamera,
  });

  final ReferenceMode mode;
  final CameraController? controller;
  final XFile? referenceImage;
  final double overlayOpacity;
  final bool isInitializingCamera;
  final String? cameraError;
  final VoidCallback onRetryCamera;

  @override
  Widget build(BuildContext context) {
    if (mode == ReferenceMode.overlay) {
      return _OverlayWorkspace(
        controller: controller,
        referenceImage: referenceImage,
        overlayOpacity: overlayOpacity,
        isInitializingCamera: isInitializingCamera,
        cameraError: cameraError,
        onRetryCamera: onRetryCamera,
      );
    }

    return _SplitWorkspace(
      controller: controller,
      referenceImage: referenceImage,
      isInitializingCamera: isInitializingCamera,
      cameraError: cameraError,
      onRetryCamera: onRetryCamera,
    );
  }
}

class _SplitWorkspace extends StatelessWidget {
  const _SplitWorkspace({
    required this.controller,
    required this.referenceImage,
    required this.isInitializingCamera,
    required this.cameraError,
    required this.onRetryCamera,
  });

  final CameraController? controller;
  final XFile? referenceImage;
  final bool isInitializingCamera;
  final String? cameraError;
  final VoidCallback onRetryCamera;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _ReferenceImagePanel(referenceImage: referenceImage)),
        const Divider(height: 1, color: Color(0xFF27313A)),
        Expanded(
          child: _CameraPreviewPanel(
            controller: controller,
            isInitializingCamera: isInitializingCamera,
            cameraError: cameraError,
            onRetryCamera: onRetryCamera,
          ),
        ),
      ],
    );
  }
}

class _OverlayWorkspace extends StatelessWidget {
  const _OverlayWorkspace({
    required this.controller,
    required this.referenceImage,
    required this.overlayOpacity,
    required this.isInitializingCamera,
    required this.cameraError,
    required this.onRetryCamera,
  });

  final CameraController? controller;
  final XFile? referenceImage;
  final double overlayOpacity;
  final bool isInitializingCamera;
  final String? cameraError;
  final VoidCallback onRetryCamera;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _CameraPreviewPanel(
          controller: controller,
          isInitializingCamera: isInitializingCamera,
          cameraError: cameraError,
          onRetryCamera: onRetryCamera,
        ),
        if (referenceImage != null)
          IgnorePointer(
            child: Opacity(
              opacity: overlayOpacity,
              child: _ImageFileView(
                path: referenceImage!.path,
                fit: BoxFit.contain,
              ),
            ),
          )
        else
          const _OverlayEmptyReference(),
      ],
    );
  }
}

class _ReferenceImagePanel extends StatelessWidget {
  const _ReferenceImagePanel({required this.referenceImage});

  final XFile? referenceImage;

  @override
  Widget build(BuildContext context) {
    if (referenceImage == null) {
      return const _EmptyPanel(
        icon: Icons.image_outlined,
        title: 'No reference selected',
        body: 'Choose an image to compare with the camera view.',
      );
    }

    return _ImageFileView(path: referenceImage!.path, fit: BoxFit.contain);
  }
}

class _ImageFileView extends StatelessWidget {
  const _ImageFileView({required this.path, required this.fit});

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cameraDarkSurface,
      alignment: Alignment.center,
      child: Image.file(
        File(path),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const _EmptyPanel(
            icon: Icons.broken_image_outlined,
            title: 'Reference unavailable',
            body: 'The selected image could not be displayed.',
          );
        },
      ),
    );
  }
}

class _CameraPreviewPanel extends StatelessWidget {
  const _CameraPreviewPanel({
    required this.controller,
    required this.isInitializingCamera,
    required this.cameraError,
    required this.onRetryCamera,
  });

  final CameraController? controller;
  final bool isInitializingCamera;
  final String? cameraError;
  final VoidCallback onRetryCamera;

  @override
  Widget build(BuildContext context) {
    if (cameraError != null) {
      return _CameraErrorPanel(message: cameraError!, onRetry: onRetryCamera);
    }

    if (isInitializingCamera || controller == null) {
      return const _LoadingPanel();
    }

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: CameraPreview(controller!),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const _EmptyPanel(
      icon: Icons.photo_camera_outlined,
      title: 'Starting camera',
      body: 'Preparing the live preview.',
      showProgress: true,
    );
  }
}

class _CameraErrorPanel extends StatelessWidget {
  const _CameraErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.cameraDarkSurface,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: Colors.white70,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF35404A)),
              backgroundColor: const Color(0xFF222930),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.body,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.cameraDarkSurface,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 34),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              letterSpacing: 0,
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: 10),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverlayEmptyReference extends StatelessWidget {
  const _OverlayEmptyReference();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xCC171C21),
            borderRadius: BorderRadius.all(Radius.circular(8)),
            border: Border.fromBorderSide(BorderSide(color: Color(0xFF35404A))),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              'Choose a reference image for overlay mode.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomToolbar extends StatelessWidget {
  const _BottomToolbar({
    required this.mode,
    required this.overlayOpacity,
    required this.isCaptureEnabled,
    required this.isTakingPicture,
    required this.onModeChanged,
    required this.onOpacityChanged,
    required this.onCapture,
  });

  final ReferenceMode mode;
  final double overlayOpacity;
  final bool isCaptureEnabled;
  final bool isTakingPicture;
  final ValueChanged<ReferenceMode> onModeChanged;
  final ValueChanged<double> onOpacityChanged;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.cameraDarkOverlay,
        border: Border(top: BorderSide(color: Color(0xFF27313A))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mode == ReferenceMode.overlay)
            _OpacityControl(value: overlayOpacity, onChanged: onOpacityChanged),
          Row(
            children: [
              Expanded(
                child: _ModeSegmentedControl(
                  mode: mode,
                  onModeChanged: onModeChanged,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 64,
                height: 64,
                child: FilledButton(
                  onPressed: isCaptureEnabled ? onCapture : null,
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: isTakingPicture
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Icon(Icons.camera_alt_outlined, size: 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpacityControl extends StatelessWidget {
  const _OpacityControl({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.opacity, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Slider(
              min: 0.15,
              max: 0.85,
              value: value,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSegmentedControl extends StatelessWidget {
  const _ModeSegmentedControl({
    required this.mode,
    required this.onModeChanged,
  });

  final ReferenceMode mode;
  final ValueChanged<ReferenceMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF222930),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF35404A)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: 'Split',
              icon: Icons.splitscreen_outlined,
              selected: mode == ReferenceMode.split,
              onTap: () => onModeChanged(ReferenceMode.split),
            ),
          ),
          const VerticalDivider(width: 1, color: Color(0xFF35404A)),
          Expanded(
            child: _ModeButton(
              label: 'Overlay',
              icon: Icons.layers_outlined,
              selected: mode == ReferenceMode.overlay,
              onTap: () => onModeChanged(ReferenceMode.overlay),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected ? AppColors.accent : Colors.transparent;
    final foreground = selected ? Colors.white : Colors.white70;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
