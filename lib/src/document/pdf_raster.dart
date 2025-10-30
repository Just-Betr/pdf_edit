import 'dart:typed_data';

import 'package:pdf/pdf.dart';

/// Renders PDF pages to raster images that can be used as template backgrounds.
typedef PdfRasterizeCallback =
    Future<List<PdfRasterPage>> Function({required Uint8List documentBytes, required double dpi});

/// Represents a rasterised PDF page produced by a [PdfRasterizeCallback].
class PdfRasterPage {
  const PdfRasterPage({
    required this.pageIndex,
    required this.imageBytes,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.dpi,
  }) : assert(dpi > 0, 'dpi must be positive');

  final int pageIndex;
  final Uint8List imageBytes;
  final double pixelWidth;
  final double pixelHeight;
  final double dpi;

  double get widthPoints => pixelWidth / dpi * PdfPageFormat.inch;
  double get heightPoints => pixelHeight / dpi * PdfPageFormat.inch;
}
