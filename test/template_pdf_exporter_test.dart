import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;

import 'package:pdf_edit/pdf_edit.dart';
import 'package:pdf_edit/src/document/pdf_document_template.dart';
import 'package:pdf_edit/src/template/pdf_template.dart';
import 'package:pdf_edit/src/template/pdf_template_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Signature renderer', () {
    test('returns empty bytes when no signature data', () async {
      final signature = PdfSignatureData(
        strokes: const <List<Offset>>[],
        canvasSize: const Size(200, 80),
      );
      final bytes = await renderSignatureAsPng(signature: signature);
      expect(bytes, isEmpty);
    });

    test('renders PNG bytes for captured strokes', () async {
      final stroke = <Offset>[
        const Offset(0, 0),
        const Offset(50, 10),
        const Offset(120, 40),
      ];
      final signature = PdfSignatureData(
        strokes: <List<Offset>>[stroke],
        canvasSize: const Size(200, 80),
      );
      final bytes = await renderSignatureAsPng(
        signature: signature,
        targetHeight: 40,
      );
      expect(bytes, isNotEmpty);

      // Decode the PNG to confirm it is a valid image payload.
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThan(0));
      expect(frame.image.height, greaterThan(0));
    });
  });

  group('PdfDocument rendering', () {
    test('reuses cached template across builds', () async {
      final binding = PdfFieldBinding.named('firstName');
      final definition = PdfDocumentTemplate(
        assetPath: 'assets/forms/mock.pdf',
        pages: <PdfDocumentTemplatePage>[
          PdfDocumentTemplatePage(
            index: 0,
            pageFormat: PdfPageFormat.a4,
            fields: <PdfFieldConfig>[
              PdfFieldConfig(
                binding: binding,
                type: PdfFieldType.text,
                pageIndex: 0,
                x: 0,
                y: 0,
              ),
            ],
          ),
        ],
      );

      final template = PdfTemplate(
        assetPath: definition.assetPath,
        name: 'mock',
        rasterDpi: 144,
        pages: <PdfTemplatePage>[
          PdfTemplatePage(
            index: 0,
            pageFormat: PdfPageFormat.a4,
            fields: <PdfFieldConfig>[
              PdfFieldConfig(
                binding: binding,
                type: PdfFieldType.text,
                pageIndex: 0,
                x: 0,
                y: 0,
              ),
            ],
          ),
        ],
      );

      final loader = _StubTemplateLoader(template);
      final document = PdfDocument(
        template: definition,
        loader: loader,
        compress: false,
      );

      final data = PdfDocumentData(
        values: const <String, Object?>{'firstName': 'Ada'},
      );

      final bytesOne = await document.generate(using: data);
      final bytesTwo = await document.generate(using: data);

      expect(bytesOne, isNotEmpty);
      expect(bytesTwo, isNotEmpty);
      expect(
        loader.loadCalls,
        1,
        reason: 'Template should be cached across builds.',
      );
    });

    test('formats values using default rules', () async {
      final subscribe = PdfFieldBinding.named('subscribe');
      final startedOn = PdfFieldBinding.named('startedOn');
      final definition = PdfDocumentTemplate(
        assetPath: 'assets/forms/mock.pdf',
        pages: <PdfDocumentTemplatePage>[
          PdfDocumentTemplatePage(
            index: 0,
            pageFormat: PdfPageFormat.a4,
            fields: <PdfFieldConfig>[
              PdfFieldConfig(
                binding: subscribe,
                type: PdfFieldType.text,
                pageIndex: 0,
                x: 0,
                y: 0,
              ),
              PdfFieldConfig(
                binding: startedOn,
                type: PdfFieldType.text,
                pageIndex: 0,
                x: 0,
                y: 0,
              ),
            ],
          ),
        ],
      );

      final template = PdfTemplate(
        assetPath: definition.assetPath,
        name: 'mock',
        rasterDpi: 144,
        pages: <PdfTemplatePage>[
          PdfTemplatePage(
            index: 0,
            pageFormat: PdfPageFormat.a4,
            fields: <PdfFieldConfig>[
              PdfFieldConfig(
                binding: subscribe,
                type: PdfFieldType.text,
                pageIndex: 0,
                x: 0,
                y: 0,
              ),
              PdfFieldConfig(
                binding: startedOn,
                type: PdfFieldType.text,
                pageIndex: 0,
                x: 0,
                y: 0,
              ),
            ],
          ),
        ],
      );

      final loader = _StubTemplateLoader(template);
      final document = PdfDocument(
        template: definition,
        loader: loader,
        compress: false,
      );

      final data = PdfDocumentData()
        ..setCheckbox(binding: 'subscribe', value: true)
        ..setValue(binding: 'startedOn', value: DateTime(2024, 1, 5));
      final bytes = await document.generate(using: data);

      expect(bytes, isNotEmpty);

      expect(loader.loadCalls, 1);
      final payload = String.fromCharCodes(bytes);
      expect(payload, contains('X'));
      expect(payload, contains('01/05/2024'));
    });
  });

  group('PdfDocumentTemplate', () {
    test('infers name when none supplied', () {
      final template = PdfDocumentTemplate(
        assetPath: 'templates/contract_v1.pdf',
        pages: const <PdfDocumentTemplatePage>[],
      );
      expect(template.pdfName, 'contract_v1');
    });

    test('retains assigned name and fields', () {
      final firstName = PdfFieldBinding.named('firstName');
      final template = PdfDocumentTemplate(
        assetPath: 'assets/forms/example.pdf',
        pdfName: 'Example',
        pages: <PdfDocumentTemplatePage>[
          PdfDocumentTemplatePage(
            index: 0,
            fields: <PdfFieldConfig>[
              PdfFieldConfig(
                binding: firstName,
                type: PdfFieldType.text,
                pageIndex: 0,
                x: 10,
                y: 20,
                width: 80,
                height: 20,
                positionUnit: PdfMeasurementUnit.points,
                sizeUnit: PdfMeasurementUnit.points,
              ),
            ],
          ),
        ],
      );

      expect(template.assetPath, 'assets/forms/example.pdf');
      expect(template.pdfName, 'Example');
      expect(template.pages, hasLength(1));
      expect(template.pages.first.fields.single.binding, firstName);
    });
  });
}

class _StubTemplateLoader extends PdfTemplateLoader {
  _StubTemplateLoader(this.template) : super();

  final PdfTemplate template;
  int loadCalls = 0;

  @override
  Future<PdfTemplate> load(final PdfDocumentTemplate config) async {
    loadCalls += 1;
    return template;
  }
}
