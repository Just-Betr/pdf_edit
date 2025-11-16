import 'dart:math';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:printing/printing.dart';

import '../data/pdf_document_data.dart';
import '../document/pdf_raster.dart';
import '../signature/signature_renderer.dart';
import '../template/pdf_template.dart';
import '../template/pdf_template_loader.dart';

/// Builder that maps logical bindings to regions inside a PDF template.
///
/// Configure bindings with [text], [checkbox], and [signature], then call
/// [build] to obtain a [PdfDocument] ready to merge runtime data and export
/// bytes with [PdfDocument.generate]. Coordinates use PDF points measured from
/// the top-left corner of each page.
class PdfDocumentBuilder {
  PdfDocumentBuilder({
    required String assetPath,
    double rasterDpi = 144,
    AssetBundle? bundle,
    bool compress = true,
    SignatureRenderer signatureRenderer = const PaintingSignatureRenderer(),
  }) : _assetPath = assetPath,
       _assetBytes = null,
       _documentName = inferPdfNameFromAsset(assetPath),
       _rasterDpi = rasterDpi,
       _bundle = bundle,
       _compress = compress,
       _signatureRenderer = signatureRenderer;

  PdfDocumentBuilder.fromBytes({
    required Uint8List bytes,
    String? name,
    double rasterDpi = 144,
    bool compress = true,
    SignatureRenderer signatureRenderer = const PaintingSignatureRenderer(),
  }) : _assetPath = null,
       _assetBytes = Uint8List.fromList(bytes),
       _documentName = _normaliseDocumentName(name),
       _rasterDpi = rasterDpi,
       _bundle = null,
       _compress = compress,
       _signatureRenderer = signatureRenderer;

  final String? _assetPath;
  final Uint8List? _assetBytes;
  final String _documentName;
  final double _rasterDpi;
  final AssetBundle? _bundle;
  final bool _compress;
  final SignatureRenderer _signatureRenderer;

  final Map<int, _PageBuffer> _pages = <int, _PageBuffer>{};

  /// Declares a text field on a page.
  void text({
    required int page,
    required String binding,
    required double x,
    required double y,
    required Size size,
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

  /// Declares a checkbox field whose value toggles text rendering.
  void checkbox({
    required int page,
    required String binding,
    required double x,
    required double y,
    required Size size,
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

  /// Declares a signature field rendered from captured ink data.
  void signature({
    required int page,
    required String binding,
    required double x,
    required double y,
    required Size size,
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

  /// Overrides the layout for the specified page.
  void pageFormat(int page, PdfPageFormat format) {
    _page(page).pageFormat = format;
  }

  /// Finalises the builder and returns a mutable [PdfDocument].
  PdfDocument build() {
    final pages = _buildPages();
    if (_assetBytes != null) {
      return PdfDocument._fromTemplateBytes(
        templateBytes: _assetBytes,
        name: _documentName,
        rasterDpi: _rasterDpi,
        pages: pages,
        compress: _compress,
        signatureRenderer: _signatureRenderer,
      );
    }

    final assetPath = _assetPath;
    if (assetPath == null) {
      throw StateError('Asset path is unavailable for this builder.');
    }

    return PdfDocument(
      assetPath: assetPath,
      rasterDpi: _rasterDpi,
      pages: pages,
      bundle: _bundle,
      compress: _compress,
      signatureRenderer: _signatureRenderer,
    );
  }

  _PageBuffer _page(int index) => _pages.putIfAbsent(index, () => _PageBuffer(index));

  List<PdfPageLayout> _buildPages() {
    return _pages.values.map((state) => state.toLayout(defaultFormat: PdfPageFormat.letter)).toList(growable: false)
      ..sort((a, b) => a.index.compareTo(b.index));
  }

  void _assertBinding(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Binding name cannot be empty');
    }
  }

  static String _normaliseDocumentName(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'document';
    }
    return trimmed;
  }
}

/// Represents a configured PDF document along with mutable bindings.
class PdfDocument {
  PdfDocument({
    required String assetPath,
    required List<PdfPageLayout> pages,
    double rasterDpi = 144,
    AssetBundle? bundle,
    bool compress = true,
    SignatureRenderer signatureRenderer = const PaintingSignatureRenderer(),
  }) : _assetPath = assetPath,
       _assetBytes = null,
       _pdfName = inferPdfNameFromAsset(assetPath),
       _rasterDpi = rasterDpi,
       _pages = List<PdfPageLayout>.unmodifiable(pages),
       _bundle = bundle,
       _compress = compress,
       _signatureRenderer = signatureRenderer,
       _staticBytes = null,
       data = PdfDocumentData();

  PdfDocument.fromBytes({
    required Uint8List bytes,
    SignatureRenderer signatureRenderer = const PaintingSignatureRenderer(),
  }) : _assetPath = null,
       _assetBytes = null,
       _pdfName = null,
       _rasterDpi = null,
       _pages = const <PdfPageLayout>[],
       _bundle = null,
       _compress = true,
       _signatureRenderer = signatureRenderer,
       _staticBytes = Uint8List.fromList(bytes),
       data = PdfDocumentData();

  PdfDocument._fromTemplateBytes({
    required Uint8List templateBytes,
    required List<PdfPageLayout> pages,
    required String name,
    double rasterDpi = 144,
    bool compress = true,
    SignatureRenderer signatureRenderer = const PaintingSignatureRenderer(),
  }) : _assetPath = null,
       _assetBytes = Uint8List.fromList(templateBytes),
       _pdfName = name,
       _rasterDpi = rasterDpi,
       _pages = List<PdfPageLayout>.unmodifiable(pages),
       _bundle = null,
       _compress = compress,
       _signatureRenderer = signatureRenderer,
       _staticBytes = null,
       data = PdfDocumentData();

  final String? _assetPath;
  final Uint8List? _assetBytes;
  final String? _pdfName;
  final double? _rasterDpi;
  final List<PdfPageLayout> _pages;
  final AssetBundle? _bundle;
  final bool _compress;
  final SignatureRenderer _signatureRenderer;
  final Uint8List? _staticBytes;

  final PdfDocumentData data;

  String get assetPath {
    final path = _assetPath;
    if (path == null) {
      throw StateError('Asset path is unavailable for byte-backed documents.');
    }
    return path;
  }

  String get pdfName {
    final name = _pdfName;
    if (name == null) {
      throw StateError('Template name is unavailable for byte-backed documents.');
    }
    return name;
  }

  double get rasterDpi {
    final dpi = _rasterDpi;
    if (dpi == null) {
      throw StateError('Raster DPI is unavailable for byte-backed documents.');
    }
    return dpi;
  }

  List<PdfPageLayout> get pages => _pages;

  Future<Uint8List> generate({PdfDocumentData? using}) async {
    final staticBytes = _staticBytes;
    if (staticBytes != null) {
      return Uint8List.fromList(staticBytes);
    }

    final pdfName = _pdfName;
    final rasterDpi = _rasterDpi;
    if (pdfName == null || rasterDpi == null) {
      throw StateError('Template metadata is unavailable for byte-backed documents.');
    }

    final payload = using ?? data;
    final templateBytes = _assetBytes;
    final templateLabel = _assetPath ?? 'memory:$pdfName';
    final template = await _loadTemplate(
      pdfName: pdfName,
      rasterDpi: rasterDpi,
      templateBytes: templateBytes,
      templateLabel: templateLabel,
    );
    final signatureImages = await _collectSignatureImages(template: template, data: payload);

    final doc = Document(compress: _compress);
    for (final page in template.pages) {
      doc.addPage(
        Page(
          pageFormat: page.pageFormat,
          margin: EdgeInsets.zero,
          build: (context) => _buildPage(page: page, data: payload, signatureImages: signatureImages),
        ),
      );
    }

    return doc.save();
  }

  /// Resolves the source PDF and prepares it for rendering.
  Future<PdfTemplate> _loadTemplate({
    required String pdfName,
    required double rasterDpi,
    required Uint8List? templateBytes,
    required String templateLabel,
  }) async {
    final bytes = await _resolveTemplateBytes(templateBytes: templateBytes);
    final rasters = await _rasterizeTemplate(bytes: bytes, dpi: rasterDpi);
    return _assembleTemplate(pdfName: pdfName, rasterDpi: rasterDpi, templateLabel: templateLabel, rasters: rasters);
  }

  /// Reads template bytes from memory or the asset bundle.
  Future<Uint8List> _resolveTemplateBytes({required Uint8List? templateBytes}) async {
    if (templateBytes != null) {
      return Uint8List.fromList(templateBytes);
    }

    final path = _assetPath;
    if (path == null) {
      throw StateError('Either template bytes or an asset path must be provided.');
    }

    final bundle = _bundle ?? rootBundle;
    final data = await bundle.load(path);
    return data.buffer.asUint8List();
  }

  /// Rasterises the template using the printing plugin backgrounds.
  Future<List<PdfRasterPage>> _rasterizeTemplate({required Uint8List bytes, required double dpi}) async {
    try {
      final rasters = await Printing.raster(bytes, dpi: dpi).toList();
      if (rasters.isEmpty) {
        return <PdfRasterPage>[];
      }

      return Future.wait(
        List<Future<PdfRasterPage>>.generate(rasters.length, (index) async {
          final raster = rasters[index];
          final imageBytes = await raster.toPng();
          return PdfRasterPage(
            pageIndex: index,
            imageBytes: imageBytes,
            pixelWidth: raster.width.toDouble(),
            pixelHeight: raster.height.toDouble(),
            dpi: dpi,
          );
        }),
      );
    } catch (_) {
      return <PdfRasterPage>[];
    }
  }

  /// Combines page layouts with raster images to produce the runtime template.
  PdfTemplate _assembleTemplate({
    required String pdfName,
    required double rasterDpi,
    required String templateLabel,
    required List<PdfRasterPage> rasters,
  }) {
    final rasterLookup = <int, PdfRasterPage>{for (final raster in rasters) raster.pageIndex: raster};
    final sortedPages = List<PdfPageLayout>.from(_pages)..sort((a, b) => a.index.compareTo(b.index));

    final templatePages = <PdfTemplatePage>[];
    for (final layout in sortedPages) {
      final raster = rasterLookup[layout.index];
      final pageFormat =
          layout.pageFormat ??
          (raster != null ? PdfPageFormat(raster.widthPoints, raster.heightPoints) : PdfPageFormat.letter);
      final backgroundImage = raster != null ? MemoryImage(raster.imageBytes) : null;
      final fieldsForPage = layout.fields.where((field) => field.pageIndex == layout.index).toList(growable: false);

      templatePages.add(
        PdfTemplatePage(
          index: layout.index,
          pageFormat: pageFormat,
          fields: fieldsForPage,
          background: backgroundImage,
        ),
      );
    }

    return PdfTemplate(assetPath: templateLabel, name: pdfName, rasterDpi: rasterDpi, pages: templatePages);
  }

  Future<Map<_SignatureCacheKey, MemoryImage?>> _collectSignatureImages({
    required PdfTemplate template,
    required PdfDocumentData data,
  }) async {
    final result = <_SignatureCacheKey, MemoryImage?>{};

    for (final page in template.pages) {
      for (final field in page.fields.where((field) => field.type == PdfFieldType.signature)) {
        final bindingName = field.binding.value;
        final targetHeight =
            _resolveSize(value: field.height, axisExtent: page.pageFormat.height, unit: field.sizeUnit) ??
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

        final bytes = await _signatureRenderer(signature: signatureData, targetHeight: targetHeight);
        result[cacheKey] = bytes.isEmpty ? null : MemoryImage(bytes);
      }
    }

    return result;
  }

  Widget _buildPage({
    required PdfTemplatePage page,
    required PdfDocumentData data,
    required Map<_SignatureCacheKey, MemoryImage?> signatureImages,
  }) {
    final children = <Widget>[];
    if (page.background != null) {
      children.add(Positioned.fill(child: Image(page.background!, fit: BoxFit.cover)));
    }

    for (final field in page.fields) {
      children.add(_buildField(page: page, field: field, data: data, signatureImages: signatureImages));
    }

    return Stack(children: children);
  }

  Widget _buildField({
    required PdfTemplatePage page,
    required PdfFieldConfig field,
    required PdfDocumentData data,
    required Map<_SignatureCacheKey, MemoryImage?> signatureImages,
  }) {
    final pageWidth = page.pageFormat.width;
    final pageHeight = page.pageFormat.height;
    final left = _resolveCoordinate(value: field.x, axisExtent: pageWidth, unit: field.positionUnit);
    final top = _resolveCoordinate(value: field.y, axisExtent: pageHeight, unit: field.positionUnit);
    final width = _resolveSize(value: field.width, axisExtent: pageWidth, unit: field.sizeUnit);
    final height = _resolveSize(value: field.height, axisExtent: pageHeight, unit: field.sizeUnit);

    switch (field.type) {
      case PdfFieldType.text:
        final rawValue = data.value(field.binding.value);
        final resolvedText = _resolveTextValue(rawValue, uppercase: field.uppercase);
        if (!field.isRequired && resolvedText.trim().isEmpty) {
          return Positioned(
            left: left,
            top: top,
            child: SizedBox(width: width, height: height),
          );
        }

        final maxLines = field.allowWrap ? field.maxLines : (field.maxLines ?? 1);
        final textWidget = Text(
          resolvedText,
          style: TextStyle(fontSize: field.fontSize ?? 12, fontWeight: FontWeight.normal, color: PdfColors.black),
          textAlign: _mapTextAlign(alignment: field.textAlignment),
          maxLines: maxLines,
          overflow: TextOverflow.clip,
        );

        final wrapped = _wrapTextWidget(textWidget: textWidget, width: width, height: height, field: field);

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
          decoration: const BoxDecoration(color: PdfColor.fromInt(0xFFF2F4F7)),
          child: Text(
            'Signature not captured',
            style: TextStyle(fontSize: field.fontSize ?? 12, color: PdfColors.grey600),
          ),
        );

        final padding = boxHeight <= 0 ? 0.0 : min(6.0, max(0.0, boxHeight * 0.1));
        final availableWidth = (boxWidth - padding * 2).clamp(0.0, double.infinity).toDouble();
        final availableHeight = (boxHeight - padding * 2).clamp(0.0, double.infinity).toDouble();

        final signatureWidget = hasSignature && availableWidth > 0 && availableHeight > 0
            ? Container(
                padding: padding > 0 ? EdgeInsets.all(padding) : EdgeInsets.zero,
                alignment: Alignment.center,
                child: Image(signatureImage, width: availableWidth, height: availableHeight, fit: BoxFit.contain),
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

  String _resolveTextValue(Object? value, {required bool uppercase}) {
    final text = _stringifyValue(value);
    return uppercase ? text.toUpperCase() : text;
  }

  String _stringifyValue(Object? value) {
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

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final year = value.year.toString().padLeft(4, '0');
    return '$month/$day/$year';
  }

  double _resolveCoordinate({required double value, required double axisExtent, required PdfMeasurementUnit unit}) {
    switch (unit) {
      case PdfMeasurementUnit.fraction:
        return value * axisExtent;
      case PdfMeasurementUnit.points:
        return value;
    }
  }

  double? _resolveSize({required double? value, required double axisExtent, required PdfMeasurementUnit unit}) {
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

  Alignment _mapAlignment({required PdfTextAlignment alignment}) {
    switch (alignment) {
      case PdfTextAlignment.start:
        return Alignment.topLeft;
      case PdfTextAlignment.center:
        return Alignment.topCenter;
      case PdfTextAlignment.end:
        return Alignment.topRight;
    }
  }

  TextAlign _mapTextAlign({required PdfTextAlignment alignment}) {
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
    required Widget textWidget,
    required double? width,
    required double? height,
    required PdfFieldConfig field,
  }) {
    if (width == null && height == null) {
      return textWidget;
    }

    final alignment = _mapAlignment(alignment: field.textAlignment);

    if (field.allowWrap && !field.shrinkToFit) {
      return Container(width: width, height: height, alignment: alignment, child: textWidget);
    }

    final child = field.shrinkToFit
        ? FittedBox(alignment: alignment, fit: BoxFit.scaleDown, child: textWidget)
        : textWidget;

    return Container(width: width, height: height, alignment: alignment, child: child);
  }
}

class _PageBuffer {
  _PageBuffer(this.index);

  final int index;
  PdfPageFormat? pageFormat;
  final List<PdfFieldConfig> fields = <PdfFieldConfig>[];

  PdfPageLayout toLayout({required PdfPageFormat defaultFormat}) {
    return PdfPageLayout(
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
  bool operator ==(Object other) {
    if (other is! _SignatureCacheKey) {
      return false;
    }
    return other.binding == binding && (other.height - height).abs() <= 1e-6;
  }

  @override
  int get hashCode => Object.hash(binding, height.toStringAsFixed(6));
}
