import 'package:flutter/material.dart';

class VisitRecordPhoto extends StatelessWidget {
  const VisitRecordPhoto({required this.path, this.fit = BoxFit.cover, super.key});

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEEF1F4),
      child: Center(child: Icon(Icons.photo_outlined)),
    );
  }
}
