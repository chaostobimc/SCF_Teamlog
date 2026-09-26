import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Rendert einen Widget-Baum (RepaintBoundary) in ein PNG.
Future<Uint8List> captureWidgetPng(
  GlobalKey key, {
  double pixelRatio = 2.5,
}) async {
  final context = key.currentContext;
  if (context == null) {
    throw StateError('Widget nicht sichtbar');
  }
  final boundary = context.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw StateError('PNG-Erzeugung fehlgeschlagen');
  }
  return byteData.buffer.asUint8List();
}
