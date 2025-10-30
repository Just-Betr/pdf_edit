import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:printing/printing.dart';

import '../document/pdf_raster.dart';
import 'pdf_template.dart';

/// Describes a page layout prior to rasterisation.
class PdfPageLayout {
  PdfPageLayout({required this.index, required List<PdfFieldConfig> fields, this.pageFormat})
    : fields = List<PdfFieldConfig>.unmodifiable(fields);

  /// Page index inside the source PDF.
  final int index;

  /// Field definitions to render on the page.
  final List<PdfFieldConfig> fields;

  /// Optional override for the page dimensions when rasterisation is absent.
  final PdfPageFormat? pageFormat;
}

/// Loads a [PdfTemplate] from the supplied configuration without caching.
Future<PdfTemplate> loadPdfTemplate({
  required final String assetPath,
  required final String pdfName,
  required final double rasterDpi,
  required final List<PdfPageLayout> pages,
  AssetBundle? bundle,
}) async {
  final assetBundle = bundle ?? rootBundle;

  final assetData = await assetBundle.load(assetPath);
  final bytes = assetData.buffer.asUint8List();
  return _buildTemplateFromBytes(bytes: bytes, label: assetPath, pdfName: pdfName, rasterDpi: rasterDpi, pages: pages);
}

Future<PdfTemplate> loadPdfTemplateFromBytes({
  required final Uint8List bytes,
  required final String pdfName,
  required final double rasterDpi,
  required final List<PdfPageLayout> pages,
  String? label,
}) async {
  final sourceLabel = label ?? 'memory:$pdfName';
  return _buildTemplateFromBytes(
    bytes: Uint8List.fromList(bytes),
    label: sourceLabel,
    pdfName: pdfName,
    rasterDpi: rasterDpi,
    pages: pages,
  );
}

Future<PdfTemplate> _buildTemplateFromBytes({
  required final Uint8List bytes,
  required final String label,
  required final String pdfName,
  required final double rasterDpi,
  required final List<PdfPageLayout> pages,
}) async {
  List<PdfRasterPage> rasters;
  try {
    final rawRasters = await Printing.raster(bytes, dpi: rasterDpi).toList();
    if (rawRasters.isEmpty) {
      rasters = <PdfRasterPage>[];
    } else {
      rasters = await Future.wait(
        List<Future<PdfRasterPage>>.generate(rawRasters.length, (final index) async {
          final raster = rawRasters[index];
          final imageBytes = await raster.toPng();
          return PdfRasterPage(
            pageIndex: index,
            imageBytes: imageBytes,
            pixelWidth: raster.width.toDouble(),
            pixelHeight: raster.height.toDouble(),
            dpi: rasterDpi,
          );
        }),
      );
    }
  } catch (_) {
    rasters = <PdfRasterPage>[];
  }
  final rasterLookup = <int, PdfRasterPage>{for (final raster in rasters) raster.pageIndex: raster};

  final sortedPages = List<PdfPageLayout>.from(pages)..sort((final a, final b) => a.index.compareTo(b.index));

  final templatePages = <PdfTemplatePage>[];
  for (final pageConfig in sortedPages) {
    final raster = rasterLookup[pageConfig.index];

    final pageFormat =
        pageConfig.pageFormat ??
        (raster != null ? PdfPageFormat(raster.widthPoints, raster.heightPoints) : PdfPageFormat.letter);
    final backgroundImage = raster != null ? MemoryImage(raster.imageBytes) : null;

    final fieldsForPage = pageConfig.fields
        .where((final field) => field.pageIndex == pageConfig.index)
        .toList(growable: false);

    templatePages.add(
      PdfTemplatePage(
        index: pageConfig.index,
        pageFormat: pageFormat,
        fields: fieldsForPage,
        background: backgroundImage,
      ),
    );
  }

  return PdfTemplate(assetPath: label, name: pdfName, rasterDpi: rasterDpi, pages: templatePages);
}
