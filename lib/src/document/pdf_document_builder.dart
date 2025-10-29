import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

import '../data/pdf_document_data.dart';
import '../signature/signature_renderer.dart';
import '../template/pdf_template.dart';
import '../template/pdf_template_loader.dart';
import 'pdf_document_template.dart';

/// Builder that maps logical bindings to regions inside a PDF template.
///
/// Create an instance, call the coordinate helpers (such as [text],
/// [checkbox], and [signature]) to describe where data should appear, then call
/// [build] to obtain a mutable [PdfDocument]. The resulting document exposes a
/// [PdfDocumentData] payload that can be populated at runtime before exporting
/// bytes with [PdfDocument.generate].
///
/// Coordinates are expressed in PDF points measured from the top-left corner of
/// the page, matching the coordinate space used by the `pdf` widgets package.
/// Rendering relies on the built-in rasteriser backed by the `printing`
/// plugin, so no additional configuration is usually required.
class PdfDocumentBuilder {
  PdfDocumentBuilder({
    required final String assetPath,
    String? pdfName,
    double rasterDpi = 144,
    PdfTemplateLoader? loader,
    bool compress = true,
  }) : _assetPath = assetPath,
       _pdfName = pdfName,
       _rasterDpi = rasterDpi,
       _compress = compress,
       _loader = loader ?? PdfTemplateLoader();

  final String _assetPath;
  final String? _pdfName;
  final double _rasterDpi;
  final bool _compress;
  final PdfTemplateLoader _loader;

  final Map<int, _PageBuffer> _pages = <int, _PageBuffer>{};

  /// Declares a text field on a page.
  ///
  /// The [binding] must be unique across the template. The [x] and [y]
  /// coordinates are measured in PDF points from the top-left corner of the
  /// page. Supply [allowWrap] to permit multi-line text and configure
  /// [maxLines], [shrinkToFit], or [uppercase] when you need to control
  /// formatting.
  void text({
    required final int page,
    required final String binding,
    required final double x,
    required final double y,
    required final Size size,
    double fontSize = 12,
    PdfTextAlignment alignment = PdfTextAlignment.start,
    bool uppercase = false,
    bool allowWrap = false,
    bool shrinkToFit = true,
    int? maxLines,
    bool isRequired = true,
  }) {
    _assertBinding(binding);
    final fieldBinding = PdfFieldBinding.named(binding);
    final field = PdfFieldConfig(
      binding: fieldBinding,
      type: PdfFieldType.text,
      pageIndex: page,
      x: x,
      y: y,
      width: size.width,
      height: size.height,
      fontSize: fontSize,
      positionUnit: PdfMeasurementUnit.points,
      sizeUnit: PdfMeasurementUnit.points,
      textAlignment: alignment,
      maxLines: maxLines,
      allowWrap: allowWrap,
      shrinkToFit: shrinkToFit,
      uppercase: uppercase,
      isRequired: isRequired,
    );
    _page(page).fields.add(field);
  }

  /// Declares a checkbox field whose value is supplied via [PdfDocumentData].
  ///
  /// When rendered, a `true` value produces a literal `X` and `false` produces
  /// an empty string. Use [alignment] and [fontSize] when you need to tweak the
  /// glyph position or size within the declared [size].
  void checkbox({
    required final int page,
    required final String binding,
    required final double x,
    required final double y,
    required final Size size,
    double fontSize = 12,
    PdfTextAlignment alignment = PdfTextAlignment.start,
    bool isRequired = false,
  }) {
    _assertBinding(binding);
    final fieldBinding = PdfFieldBinding.named(binding);
    final field = PdfFieldConfig(
      binding: fieldBinding,
      type: PdfFieldType.text,
      pageIndex: page,
      x: x,
      y: y,
      width: size.width,
      height: size.height,
      fontSize: fontSize,
      positionUnit: PdfMeasurementUnit.points,
      sizeUnit: PdfMeasurementUnit.points,
      textAlignment: alignment,
      allowWrap: false,
      shrinkToFit: true,
      uppercase: false,
      isRequired: isRequired,
    );
    _page(page).fields.add(field);
  }

  /// Declares a signature field that renders captured ink at runtime.
  ///
  /// The field is populated via [PdfDocumentData.setSignature] or
  /// [PdfDocumentData.setSignatureData]. Use [isRequired] to determine whether
  /// an empty signature area should be left blank or display a placeholder.
  void signature({
    required final int page,
    required final String binding,
    required final double x,
    required final double y,
    required final Size size,
    bool isRequired = false,
  }) {
    _assertBinding(binding);
    final fieldBinding = PdfFieldBinding.named(binding);
    final field = PdfFieldConfig(
      binding: fieldBinding,
      type: PdfFieldType.signature,
      pageIndex: page,
      x: x,
      y: y,
      width: size.width,
      height: size.height,
      positionUnit: PdfMeasurementUnit.points,
      sizeUnit: PdfMeasurementUnit.points,
      isRequired: isRequired,
    );
    _page(page).fields.add(field);
  }

  /// Overrides the page format used when rendering the specified page.
  ///
  /// Call this when a template page does not match the default letter size or
  /// when you want to enforce a specific [PdfPageFormat].
  void pageFormat(final int page, final PdfPageFormat format) {
    _page(page).pageFormat = format;
  }

  /// Finalises the builder and returns a [PdfDocument] ready to receive data.
  ///
  /// The returned document owns an empty [PdfDocumentData] instance and can be
  /// rendered immediately or after the bindings are populated.
  PdfDocument build() {
    final template = _buildTemplate();
    return PdfDocument(
      template: template,
      loader: _loader,
      compress: _compress,
    );
  }

  _PageBuffer _page(final int index) =>
      _pages.putIfAbsent(index, () => _PageBuffer(index));

  PdfDocumentTemplate _buildTemplate() {
    final pages =
        _pages.values
            .map(
              (final state) =>
                  state.toTemplatePage(defaultFormat: PdfPageFormat.letter),
            )
            .toList(growable: false)
          ..sort((final a, final b) => a.index.compareTo(b.index));
    return PdfDocumentTemplate(
      assetPath: _assetPath,
      pdfName: _pdfName,
      pages: pages,
      rasterDpi: _rasterDpi,
    );
  }

  void _assertBinding(final String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Binding name cannot be empty');
    }
  }
}

/// Represents a configured PDF document along with mutable data bindings.
class PdfDocument {
  /// Creates a document backed by an internal template definition that knows
  /// how to rasterize the asset and render bytes on demand via [generate].
  PdfDocument({
    required final PdfDocumentTemplate template,
    PdfTemplateLoader? loader,
    bool compress = true,
  }) : _template = template,
       _loader = loader ?? PdfTemplateLoader(),
       _compress = compress,
       _staticBytes = null,
       data = PdfDocumentData();

  /// Wraps an existing PDF payload so it can participate in the same workflows
  /// as template-driven documents. The incoming [bytes] are defensively copied
  /// to prevent accidental mutation.
  PdfDocument.fromBytes({required final Uint8List bytes})
    : _template = null,
      _loader = null,
      _compress = true,
      _staticBytes = Uint8List.fromList(bytes),
      data = PdfDocumentData();

  final PdfDocumentTemplate? _template;
  final PdfTemplateLoader? _loader;
  final bool _compress;
  final Uint8List? _staticBytes;
  PdfTemplate? _runtimeTemplate;

  /// Collects the values and signatures that will be merged into the template.
  final PdfDocumentData data;

  /// Provides read-only access to the template metadata backing this document.
  PdfDocumentTemplate get template {
    final template = _template;
    if (template == null) {
      throw StateError('Template is unavailable for byte-backed documents.');
    }
    return template;
  }

  /// Produces PDF bytes using the current [data] or overrides via [using].
  /// Returns a newly created [Uint8List] suitable for saving or sharing.
  ///
  /// When [using] is provided it is rendered instead of the document's
  /// internal [data] store, which is useful when you need to preview multiple
  /// variations without mutating shared state.
  Future<Uint8List> generate({PdfDocumentData? using}) async {
    final staticBytes = _staticBytes;
    if (staticBytes != null) {
      return Uint8List.fromList(staticBytes);
    }

    final templateDefinition = _template;
    final loader = _loader;
    if (templateDefinition == null || loader == null) {
      throw StateError('Template is unavailable for byte-backed documents.');
    }

    final payload = using ?? data;
    final template = await _obtainTemplate(
      loader: loader,
      definition: templateDefinition,
    );
    final signatureImages = await _collectSignatureImages(
      template: template,
      data: payload,
    );

    final doc = Document(compress: _compress);
    for (final page in template.pages) {
      doc.addPage(
        Page(
          pageFormat: page.pageFormat,
          margin: EdgeInsets.zero,
          build: (final context) => _buildPage(
            page: page,
            data: payload,
            signatureImages: signatureImages,
          ),
        ),
      );
    }

    return doc.save();
  }

  Future<PdfTemplate> _obtainTemplate({
    required final PdfTemplateLoader loader,
    required final PdfDocumentTemplate definition,
  }) async {
    final cached = _runtimeTemplate;
    if (cached != null) {
      return cached;
    }
    final template = await loader.load(definition);
    _runtimeTemplate = template;
    return template;
  }

  Future<Map<_SignatureCacheKey, MemoryImage?>> _collectSignatureImages({
    required final PdfTemplate template,
    required final PdfDocumentData data,
  }) async {
    final result = <_SignatureCacheKey, MemoryImage?>{};

    for (final page in template.pages) {
      for (final field in page.fields.where(
        (final field) => field.type == PdfFieldType.signature,
      )) {
        final bindingName = field.binding.value;
        final targetHeight =
            _resolveSize(
              value: field.height,
              axisExtent: page.pageFormat.height,
              unit: field.sizeUnit,
            ) ??
            page.pageFormat.height * 0.15;
        final cacheKey = _SignatureCacheKey(bindingName, targetHeight);
        if (result.containsKey(cacheKey)) {
          continue;
        }

        final signatureData = data.signature(bindingName);
        if (signatureData == null || signatureData.isEmpty) {
          result[cacheKey] = null;
          continue;
        }

        final bytes = await renderSignatureAsPng(
          signature: signatureData,
          targetHeight: targetHeight,
        );
        result[cacheKey] = bytes.isEmpty ? null : MemoryImage(bytes);
      }
    }

    return result;
  }

  Widget _buildPage({
    required final PdfTemplatePage page,
    required final PdfDocumentData data,
    required final Map<_SignatureCacheKey, MemoryImage?> signatureImages,
  }) {
    final children = <Widget>[];
    if (page.background != null) {
      children.add(
        Positioned.fill(child: Image(page.background!, fit: BoxFit.cover)),
      );
    }

    for (final field in page.fields) {
      children.add(
        _buildField(
          page: page,
          field: field,
          data: data,
          signatureImages: signatureImages,
        ),
      );
    }

    return Stack(children: children);
  }

  Widget _buildField({
    required final PdfTemplatePage page,
    required final PdfFieldConfig field,
    required final PdfDocumentData data,
    required final Map<_SignatureCacheKey, MemoryImage?> signatureImages,
  }) {
    final pageWidth = page.pageFormat.width;
    final pageHeight = page.pageFormat.height;
    final left = _resolveCoordinate(
      value: field.x,
      axisExtent: pageWidth,
      unit: field.positionUnit,
    );
    final top = _resolveCoordinate(
      value: field.y,
      axisExtent: pageHeight,
      unit: field.positionUnit,
    );
    final width = _resolveSize(
      value: field.width,
      axisExtent: pageWidth,
      unit: field.sizeUnit,
    );
    final height = _resolveSize(
      value: field.height,
      axisExtent: pageHeight,
      unit: field.sizeUnit,
    );

    switch (field.type) {
      case PdfFieldType.text:
        final rawValue = data.value(field.binding.value);
        final resolvedText = _resolveTextValue(
          rawValue,
          uppercase: field.uppercase,
        );
        if (!field.isRequired && resolvedText.trim().isEmpty) {
          return Positioned(
            left: left,
            top: top,
            child: SizedBox(width: width, height: height),
          );
        }

        final maxLines = field.allowWrap
            ? field.maxLines
            : (field.maxLines ?? 1);
        final textWidget = Text(
          resolvedText,
          style: TextStyle(
            fontSize: field.fontSize ?? 12,
            fontWeight: FontWeight.normal,
            color: PdfColors.black,
          ),
          textAlign: _mapTextAlign(alignment: field.textAlignment),
          maxLines: maxLines,
          overflow: TextOverflow.clip,
        );

        final wrapped = _wrapTextWidget(
          textWidget: textWidget,
          width: width,
          height: height,
          field: field,
        );

        return Positioned(left: left, top: top, child: wrapped);

      case PdfFieldType.signature:
        final targetHeight = height ?? pageHeight * 0.15;
        final cacheKey = _SignatureCacheKey(field.binding.value, targetHeight);
        final signatureImage = signatureImages[cacheKey];
        final hasSignature = signatureImage != null;
        final boxWidth = width ?? pageWidth * 0.45;
        final boxHeight = height ?? pageHeight * 0.15;
        final border = Border.all(color: PdfColors.grey500, width: 1);

        if (!hasSignature && !field.isRequired) {
          return Positioned(
            left: left,
            top: top,
            child: SizedBox(width: boxWidth, height: boxHeight),
          );
        }

        final placeholder = Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: PdfColor.fromInt(0xFFF2F4F7)),
          child: Text(
            'Signature not captured',
            style: TextStyle(
              fontSize: (field.fontSize ?? 12),
              color: PdfColors.grey600,
            ),
          ),
        );

        final padding = boxHeight <= 0
            ? 0.0
            : min(6.0, max(0.0, boxHeight * 0.1));
        final availableWidth = (boxWidth - padding * 2)
            .clamp(0.0, double.infinity)
            .toDouble();
        final availableHeight = (boxHeight - padding * 2)
            .clamp(0.0, double.infinity)
            .toDouble();

        final signatureWidget =
            hasSignature && availableWidth > 0 && availableHeight > 0
            ? Container(
                padding: padding > 0
                    ? EdgeInsets.all(padding)
                    : EdgeInsets.zero,
                alignment: Alignment.center,
                child: Image(
                  signatureImage,
                  width: availableWidth,
                  height: availableHeight,
                  fit: BoxFit.contain,
                ),
              )
            : placeholder;

        return Positioned(
          left: left,
          top: top,
          child: Container(
            width: boxWidth,
            height: boxHeight,
            decoration: hasSignature ? null : BoxDecoration(border: border),
            child: signatureWidget,
          ),
        );
    }
  }

  String _resolveTextValue(
    final Object? value, {
    required final bool uppercase,
  }) {
    final text = _stringifyValue(value);
    return uppercase ? text.toUpperCase() : text;
  }

  String _stringifyValue(final Object? value) {
    if (value == null) {
      return '';
    }
    if (value is bool) {
      return value ? 'X' : '';
    }
    if (value is DateTime) {
      return _formatDate(value);
    }
    return value.toString();
  }

  String _formatDate(final DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final year = value.year.toString().padLeft(4, '0');
    return '$month/$day/$year';
  }

  double _resolveCoordinate({
    required final double value,
    required final double axisExtent,
    required final PdfMeasurementUnit unit,
  }) {
    switch (unit) {
      case PdfMeasurementUnit.fraction:
        return value * axisExtent;
      case PdfMeasurementUnit.points:
        return value;
    }
  }

  double? _resolveSize({
    required final double? value,
    required final double axisExtent,
    required final PdfMeasurementUnit unit,
  }) {
    if (value == null) {
      return null;
    }
    switch (unit) {
      case PdfMeasurementUnit.fraction:
        return value * axisExtent;
      case PdfMeasurementUnit.points:
        return value;
    }
  }

  Alignment _mapAlignment({required final PdfTextAlignment alignment}) {
    switch (alignment) {
      case PdfTextAlignment.start:
        return Alignment.topLeft;
      case PdfTextAlignment.center:
        return Alignment.topCenter;
      case PdfTextAlignment.end:
        return Alignment.topRight;
    }
  }

  TextAlign _mapTextAlign({required final PdfTextAlignment alignment}) {
    switch (alignment) {
      case PdfTextAlignment.start:
        return TextAlign.left;
      case PdfTextAlignment.center:
        return TextAlign.center;
      case PdfTextAlignment.end:
        return TextAlign.right;
    }
  }

  Widget _wrapTextWidget({
    required final Widget textWidget,
    required final double? width,
    required final double? height,
    required final PdfFieldConfig field,
  }) {
    if (width == null && height == null) {
      return textWidget;
    }

    final alignment = _mapAlignment(alignment: field.textAlignment);

    if (field.allowWrap && !field.shrinkToFit) {
      return Container(
        width: width,
        height: height,
        alignment: alignment,
        child: textWidget,
      );
    }

    final child = field.shrinkToFit
        ? FittedBox(
            alignment: alignment,
            fit: BoxFit.scaleDown,
            child: textWidget,
          )
        : textWidget;

    return Container(
      width: width,
      height: height,
      alignment: alignment,
      child: child,
    );
  }
}

class _PageBuffer {
  _PageBuffer(this.index);

  final int index;
  PdfPageFormat? pageFormat;
  final List<PdfFieldConfig> fields = <PdfFieldConfig>[];

  PdfDocumentTemplatePage toTemplatePage({
    required final PdfPageFormat defaultFormat,
  }) {
    return PdfDocumentTemplatePage(
      index: index,
      fields: List<PdfFieldConfig>.unmodifiable(fields),
      pageFormat: pageFormat ?? defaultFormat,
    );
  }
}

class _SignatureCacheKey {
  const _SignatureCacheKey(this.binding, this.height);

  final String binding;
  final double height;

  @override
  bool operator ==(final Object other) {
    if (other is! _SignatureCacheKey) {
      return false;
    }
    return other.binding == binding && (other.height - height).abs() <= 1e-6;
  }

  @override
  int get hashCode => Object.hash(binding, height.toStringAsFixed(6));
}
