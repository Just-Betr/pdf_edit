import 'dart:typed_data';
import 'dart:ui';

import 'pdf_signature_data.dart';

/// Renders the provided signature strokes into a PNG payload suitable for PDF embedding.
Future<Uint8List> renderSignatureAsPng({required final PdfSignatureData signature, final double? targetHeight}) async {
  final strokes = signature.strokes;
  final canvasSize = signature.canvasSize;

  if (strokes.isEmpty || canvasSize.width <= 0 || canvasSize.height <= 0) {
    return Uint8List(0);
  }

  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;

  for (final stroke in strokes) {
    for (final point in stroke) {
      final dx = point.dx;
      final dy = point.dy;
      if (dx < minX) minX = dx;
      if (dy < minY) minY = dy;
      if (dx > maxX) maxX = dx;
      if (dy > maxY) maxY = dy;
    }
  }

  if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
    return Uint8List(0);
  }

  const margin = 12.0;
  final contentWidth = (maxX - minX).clamp(1.0, double.infinity);
  final contentHeight = (maxY - minY).clamp(1.0, double.infinity);
  final outputWidth = (contentWidth + margin * 2).ceil();
  final outputHeight = (contentHeight + margin * 2).ceil();
  final desiredStroke = 2.4;
  final scaleFactor = targetHeight != null && targetHeight > 0 ? outputHeight / targetHeight : 1.0;
  final strokeWidth = (desiredStroke * scaleFactor).clamp(2.0, 12.0);

  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()
    ..color = const Color(0xFF1F2937)
    ..strokeWidth = strokeWidth
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  canvas.drawColor(const Color(0x00000000), BlendMode.src);
  canvas.translate(-minX + margin, -minY + margin);

  for (final stroke in strokes) {
    if (stroke.length < 2) {
      continue;
    }
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (var i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(outputWidth, outputHeight);
  final byteData = await image.toByteData(format: ImageByteFormat.png);
  if (byteData == null) {
    return Uint8List(0);
  }
  return byteData.buffer.asUint8List();
}
