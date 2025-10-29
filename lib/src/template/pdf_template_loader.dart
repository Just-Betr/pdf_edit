import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:printing/printing.dart';

import '../document/pdf_document_template.dart';
import '../document/pdf_raster.dart';
import 'pdf_template.dart';

class _PrintingPdfPageRasterizer implements PdfPageRasterizer {
  const _PrintingPdfPageRasterizer();

  @override
  Future<List<PdfRasterPage>> rasterize({required final Uint8List documentBytes, required final double dpi}) async {
    final rasters = await Printing.raster(documentBytes, dpi: dpi).toList();
    if (rasters.isEmpty) {
      return <PdfRasterPage>[];
    }

    final pages = <PdfRasterPage>[];
    for (var index = 0; index < rasters.length; index++) {
      final raster = rasters[index];
      final imageBytes = await raster.toPng();
      pages.add(
        PdfRasterPage(
          pageIndex: index,
          imageBytes: imageBytes,
          pixelWidth: raster.width.toDouble(),
          pixelHeight: raster.height.toDouble(),
          dpi: dpi,
        ),
      );
    }
    return pages;
  }
}

/// Loads [PdfTemplate] instances from disk and caches the rasterised result.
///
/// When no [PdfPageRasterizer] is provided, a printing-backed implementation
/// renders backgrounds automatically.
class PdfTemplateLoader {
  PdfTemplateLoader({final AssetBundle? bundle, PdfPageRasterizer? rasterizer})
    : _bundle = bundle ?? rootBundle,
      _rasterizer = rasterizer ?? const _PrintingPdfPageRasterizer();

  final AssetBundle _bundle;
  final PdfPageRasterizer _rasterizer;
  final Map<String, PdfTemplate> _cache = <String, PdfTemplate>{};

  /// Loads and memoizes a [PdfTemplate] based on the supplied configuration.
  Future<PdfTemplate> load(final PdfDocumentTemplate definition) async {
    final cached = _cache[definition.assetPath];
    if (cached != null) {
      return cached;
    }

    final assetData = await _bundle.load(definition.assetPath);
    final bytes = assetData.buffer.asUint8List();
    final rasters = await _rasterizer.rasterize(documentBytes: bytes, dpi: definition.rasterDpi);
    final rasterLookup = <int, PdfRasterPage>{for (final raster in rasters) raster.pageIndex: raster};

    final sortedPages = List<PdfDocumentTemplatePage>.from(definition.pages)
      ..sort((final a, final b) => a.index.compareTo(b.index));

    final pages = <PdfTemplatePage>[];
    for (final pageConfig in sortedPages) {
      final raster = rasterLookup[pageConfig.index];

      final pageFormat =
          pageConfig.pageFormat ??
          (raster != null ? PdfPageFormat(raster.widthPoints, raster.heightPoints) : PdfPageFormat.letter);
      final backgroundImage = raster != null ? MemoryImage(raster.imageBytes) : null;

      final fieldsForPage = pageConfig.fields
          .where((final field) => field.pageIndex == pageConfig.index)
          .toList(growable: false);

      pages.add(
        PdfTemplatePage(
          index: pageConfig.index,
          pageFormat: pageFormat,
          fields: fieldsForPage,
          background: backgroundImage,
        ),
      );
    }

    final template = PdfTemplate(
      assetPath: definition.assetPath,
      name: definition.pdfName,
      rasterDpi: definition.rasterDpi,
      pages: pages,
    );

    _cache[definition.assetPath] = template;
    return template;
  }

  /// Clears the in-memory cache for the specified asset.
  void evict(final String assetPath) {
    _cache.remove(assetPath);
  }

  /// Clears every cached template.
  void clear() {
    _cache.clear();
  }
}
