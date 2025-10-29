import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

import 'package:pdf_edit/pdf_edit.dart';
import 'package:pdf_edit/src/document/pdf_document_template.dart';
import 'package:pdf_edit/src/template/pdf_template.dart';
import 'package:pdf_edit/src/template/pdf_template_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfDocumentBuilder', () {
    test('build renders the configured fields', () async {
      final loader = _RecordingTemplateLoader();
      final signature = PdfSignatureData(
        strokes: <List<Offset>>[
          <Offset>[const Offset(0, 0), const Offset(10, 5)],
        ],
        canvasSize: const Size(120, 40),
      );

      final builder = PdfDocumentBuilder(assetPath: 'assets/mock.pdf', loader: loader);

      builder
        ..text(page: 0, binding: 'firstName', x: 10.0, y: 20.0, size: const Size(80.0, 20.0))
        ..checkbox(page: 0, binding: 'subscribe', x: 15.0, y: 50.0, size: const Size(12.0, 12.0))
        ..signature(page: 0, binding: 'signature', x: 30.0, y: 100.0, size: const Size(150.0, 40.0));

      final document = builder.build();
      document.data
        ..setText(binding: 'firstName', value: 'Ada')
        ..setCheckbox(binding: 'subscribe', value: false)
        ..setSignatureData(binding: 'signature', signature: signature);

      final bytes = await document.generate();

      expect(bytes, isNotEmpty);
      expect(loader.lastTemplate, isNotNull);
      final page = loader.lastTemplate!.pages.single;
      expect(page.fields, hasLength(3));
      expect(page.fields.first.binding.value, 'firstName');
    });
    test('generate returns rendered bytes', () async {
      final loader = _RecordingTemplateLoader();
      final builder = PdfDocumentBuilder(assetPath: 'assets/mock.pdf', loader: loader);

      builder.text(page: 0, binding: 'firstName', x: 10.0, y: 20.0, size: const Size(80.0, 20.0));

      final document = builder.build();
      document.data.setText(binding: 'firstName', value: 'Ada');

      final Uint8List firstPass = await document.generate();
      final Uint8List secondPass = await document.generate();

      expect(firstPass, isNotEmpty);
      expect(secondPass, isNotEmpty);
      expect(firstPass.length, greaterThanOrEqualTo(4));
      expect(secondPass.length, greaterThanOrEqualTo(4));
      const magicHeader = <int>[0x25, 0x50, 0x44, 0x46]; // %PDF
      expect(firstPass.sublist(0, 4), equals(magicHeader));
      expect(secondPass.sublist(0, 4), equals(magicHeader));
    });
  });

  group('PdfSignatureData', () {
    test('reflects captured signature state', () {
      final strokes = <List<Offset>>[
        <Offset>[const Offset(0, 0), const Offset(10, 5)],
      ];
      final signature = PdfSignatureData(strokes: strokes, canvasSize: const Size(100, 40));

      expect(signature.hasSignature, isTrue);
      expect(signature.isEmpty, isFalse);

      strokes.first.add(const Offset(20, 10));
      expect(signature.strokes.first, hasLength(2), reason: 'Strokes should be defensively copied');
    });

    test('treats insufficient stroke data as empty', () {
      final signature = PdfSignatureData(
        strokes: <List<Offset>>[
          <Offset>[const Offset(0, 0)],
        ],
        canvasSize: const Size(80, 40),
      );

      expect(signature.hasSignature, isFalse);
      expect(signature.isEmpty, isTrue);
    });
  });
}

class _RecordingTemplateLoader extends PdfTemplateLoader {
  PdfDocumentTemplate? lastTemplate;

  @override
  Future<PdfTemplate> load(final PdfDocumentTemplate definition) async {
    lastTemplate = definition;
    final pages = definition.pages
        .map(
          (final page) =>
              PdfTemplatePage(index: page.index, pageFormat: page.pageFormat ?? PdfPageFormat.a4, fields: page.fields),
        )
        .toList(growable: false);
    return PdfTemplate(
      assetPath: definition.assetPath,
      name: definition.pdfName,
      rasterDpi: definition.rasterDpi,
      pages: pages,
    );
  }
}
