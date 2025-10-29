import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

/// Enumerates the field variants the renderer can lay onto a template.
///
/// `text` fields paint string data, while `signature` fields rasterise ink
/// captured via `PdfSignatureData`.
enum PdfFieldType { text, signature }

/// Measurement units used when positioning or sizing elements on the page.
///
/// Fraction-based values represent a `0.0 -> 1.0` proportion of the page axis.
/// Point-based values map directly to PDF points (`72pt == 1in`).
enum PdfMeasurementUnit { fraction, points }

/// Horizontal alignment applied when drawing text inside a field box.
enum PdfTextAlignment { start, center, end }

/// Immutable key that associates a field with a data binding at runtime.
///
/// Bindings trim surrounding whitespace so that names declared in tooling and
/// code-defined bindings resolve to the same identifier.
class PdfFieldBinding {
  const PdfFieldBinding._(this.value);

  /// Normalised binding identifier.
  final String value;

  /// Creates a binding using [name], returning a trimmed representation.
  factory PdfFieldBinding(final String name) => PdfFieldBinding.named(name);

  /// Constructs a binding from [name], throwing if the trimmed name is empty.
  factory PdfFieldBinding.named(final String name) {
    final normalised = name.trim();
    if (normalised.isEmpty) {
      throw ArgumentError('PdfFieldBinding name cannot be empty');
    }
    return PdfFieldBinding._(normalised);
  }

  @override
  bool operator ==(final Object other) =>
      other is PdfFieldBinding && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'PdfFieldBinding($value)';
}

/// Immutable description of how to render a single field.
class PdfFieldConfig {
  const PdfFieldConfig({
    required this.binding,
    required this.type,
    required this.pageIndex,
    required this.x,
    required this.y,
    this.width,
    this.height,
    this.fontSize,
    this.positionUnit = PdfMeasurementUnit.fraction,
    this.sizeUnit = PdfMeasurementUnit.fraction,
    this.textAlignment = PdfTextAlignment.start,
    this.maxLines = 1,
    this.allowWrap = false,
    this.shrinkToFit = true,
    this.uppercase = false,
    this.isRequired = true,
  });

  /// Binding that links the template field to document data.
  final PdfFieldBinding binding;

  /// Field modality used by the renderer.
  final PdfFieldType type;

  /// Zero-based index of the page containing this field.
  final int pageIndex;

  /// Horizontal offset measured using [positionUnit].
  final double x;

  /// Vertical offset measured using [positionUnit].
  final double y;

  /// Explicit field width when provided.
  final double? width;

  /// Explicit field height when provided.
  final double? height;

  /// Font size override for text fields.
  final double? fontSize;

  /// Unit applied to [x] and [y].
  final PdfMeasurementUnit positionUnit;

  /// Unit applied to [width] and [height].
  final PdfMeasurementUnit sizeUnit;

  /// Text alignment used while rendering text content.
  final PdfTextAlignment textAlignment;

  /// Maximum number of lines available to the field.
  final int? maxLines;

  /// Permits multi-line wrapping when the content exceeds the bounds.
  final bool allowWrap;

  /// Shrinks the text to fit within the bounding box when necessary.
  final bool shrinkToFit;

  /// Uppercases the text prior to rendering.
  final bool uppercase;

  /// Indicates whether the binding must be provided by the caller.
  final bool isRequired;
}

/// Runtime template produced after the asset has been parsed and rasterised.
class PdfTemplate {
  PdfTemplate({
    required this.assetPath,
    required this.name,
    required this.rasterDpi,
    required List<PdfTemplatePage> pages,
  }) : pages = List<PdfTemplatePage>.unmodifiable(pages);

  /// Source asset path.
  final String assetPath;

  /// Friendly template name.
  final String name;

  /// Rasterisation DPI for background imagery.
  final double rasterDpi;

  /// Immutable collection of template pages.
  final List<PdfTemplatePage> pages;
}

/// Runtime projection of a single page including optional background artwork.
class PdfTemplatePage {
  PdfTemplatePage({
    required this.index,
    required this.pageFormat,
    required List<PdfFieldConfig> fields,
    this.background,
  }) : fields = List<PdfFieldConfig>.unmodifiable(fields);

  /// Page index in the rendered document.
  final int index;

  /// Dimensions applied during PDF layout.
  final PdfPageFormat pageFormat;

  /// Field definitions present on the page.
  final List<PdfFieldConfig> fields;

  /// Optional background image to match the source artwork.
  final MemoryImage? background;
}

/// Infers a friendly template name from a bundle asset path.
String inferPdfNameFromAsset(final String assetPath) {
  final normalised = assetPath.replaceAll('\\', '/');
  final segments = normalised
      .split('/')
      .where((final segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (segments.isEmpty) {
    return assetPath;
  }
  final filename = segments.last;
  final dotIndex = filename.lastIndexOf('.');
  if (dotIndex <= 0) {
    return filename;
  }
  return filename.substring(0, dotIndex);
}
