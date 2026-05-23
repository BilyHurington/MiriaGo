import 'package:flutter/material.dart';

import '../app_theme.dart';

class CameraReferenceScreen extends StatelessWidget {
  const CameraReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cameraDarkSurface,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onPickReference: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reference picker coming next.'),
                  ),
                );
              },
            ),
            const Expanded(child: _CameraPlaceholder()),
            const _BottomToolbar(),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onPickReference});

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
            icon: const Icon(Icons.image_outlined, size: 20),
            label: const Text('Reference'),
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

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.cameraDarkSurface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.photo_camera_outlined, color: Colors.white70, size: 44),
          SizedBox(height: 12),
          Text(
            'Camera preview will appear here.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomToolbar extends StatelessWidget {
  const _BottomToolbar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.cameraDarkOverlay,
        border: Border(top: BorderSide(color: Color(0xFF27313A))),
      ),
      child: Row(
        children: [
          _ModeChip(
            label: 'Split',
            icon: Icons.splitscreen_outlined,
            selected: true,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _ModeChip(
            label: 'Overlay',
            icon: Icons.layers_outlined,
            selected: false,
            onTap: () {},
          ),
          const Spacer(),
          SizedBox(
            width: 64,
            height: 64,
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.camera_alt_outlined, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
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
    final background = selected ? AppColors.accent : const Color(0xFF222930);
    final foreground = selected ? Colors.white : Colors.white70;

    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(
            color: selected ? AppColors.accent : const Color(0xFF35404A),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}
