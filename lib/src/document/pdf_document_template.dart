import 'package:pdf/pdf.dart';

import '../template/pdf_template.dart';

/// Immutable description of how to render a PDF document backed by a template
/// asset. Instances are produced by [PdfDocumentBuilder] and consumed directly
/// by [PdfDocument] to render bytes.
class PdfDocumentTemplate {
  PdfDocumentTemplate({
    required this.assetPath,
    required List<PdfDocumentTemplatePage> pages,
    final String? pdfName,
    this.rasterDpi = 144,
  }) : pdfName = _resolveName(assetPath: assetPath, override: pdfName),
       pages = List<PdfDocumentTemplatePage>.unmodifiable(pages);

  /// Asset path resolved through the Flutter bundle.
  final String assetPath;

  /// Friendly template name derived from the asset path unless overridden.
  final String pdfName;

  /// DPI used when rasterising background layers.
  final double rasterDpi;

  /// Immutable collection of page definitions.
  final List<PdfDocumentTemplatePage> pages;

  static String _resolveName({
    required final String assetPath,
    final String? override,
  }) {
    final provided = override?.trim();
    if (provided != null && provided.isNotEmpty) {
      return provided;
    }
    return inferPdfNameFromAsset(assetPath);
  }
}

/// Page-level configuration produced by [PdfDocumentBuilder].
class PdfDocumentTemplatePage {
  PdfDocumentTemplatePage({
    required this.index,
    required List<PdfFieldConfig> fields,
    this.pageFormat,
  }) : fields = List<PdfFieldConfig>.unmodifiable(fields);

  /// Page index inside the source PDF.
  final int index;

  /// Field definitions to render on the page.
  final List<PdfFieldConfig> fields;

  /// Optional override for the page dimensions when rasterisation is absent.
  final PdfPageFormat? pageFormat;
}
