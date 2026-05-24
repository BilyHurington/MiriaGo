import 'package:flutter/material.dart';

class VisitRecordPhoto extends StatelessWidget {
  const VisitRecordPhoto({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEEF1F4),
      child: Center(child: Icon(Icons.photo_outlined)),
    );
  }
}
