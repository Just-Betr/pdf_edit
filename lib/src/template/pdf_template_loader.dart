import 'package:pdf/pdf.dart';

import 'pdf_template.dart';

/// Describes how a template page should be laid out before rasterisation.
class PdfPageLayout {
  PdfPageLayout({required this.index, required List<PdfFieldConfig> fields, this.pageFormat})
    : fields = List<PdfFieldConfig>.unmodifiable(fields);

  /// Page index represented by this layout.
  final int index;

  /// Collection of fields to render on the page.
  final List<PdfFieldConfig> fields;

  /// Optional explicit page size; falls back to rasterised dimensions.
  final PdfPageFormat? pageFormat;
}
