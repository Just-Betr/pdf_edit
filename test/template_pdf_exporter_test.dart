import 'dart:ui' as ui show instantiateImageCodec;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;

import 'package:pdf_edit/pdf_edit.dart';
import 'package:pdf_edit/src/template/pdf_template.dart';
import 'package:pdf_edit/src/template/pdf_template_loader.dart';

const MethodChannel _printingChannel = MethodChannel('net.nfet.printing');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_printingChannel, (MethodCall call) async {
      if (call.method == 'rasterPdf') {
        final int? job = call.arguments['job'] as int?;
        if (job != null) {
          messenger.handlePlatformMessage(
            _printingChannel.name,
            _printingChannel.codec.encodeMethodCall(MethodCall('onPageRasterEnd', <String, dynamic>{'job': job})),
            (_) {},
          );
        }
      }
      return null;
    });
  });

  tearDownAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_printingChannel, null);
  });

  group('Signature renderer', () {
    test('returns empty bytes when no signature data', () async {
      final signature = PdfSignatureData(strokes: const <List<Offset>>[], canvasSize: const Size(200, 80));
      const renderer = PaintingSignatureRenderer();
      final bytes = await renderer(signature: signature);
      expect(bytes, isEmpty);
    });

    test('renders PNG bytes for captured strokes', () async {
      final stroke = <Offset>[const Offset(0, 0), const Offset(50, 10), const Offset(120, 40)];
      final signature = PdfSignatureData(strokes: <List<Offset>>[stroke], canvasSize: const Size(200, 80));
      const renderer = PaintingSignatureRenderer();
      final bytes = await renderer(signature: signature, targetHeight: 40);
      expect(bytes, isNotEmpty);

      // Decode the PNG to confirm it is a valid image payload.
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThan(0));
      expect(frame.image.height, greaterThan(0));
    });
  });

  group('PdfDocument rendering', () {
    test('renders consistently across builds', () async {
      final binding = PdfFieldBinding.named('firstName');
      final layout = PdfPageLayout(
        index: 0,
        pageFormat: PdfPageFormat.a4,
        fields: <PdfFieldConfig>[PdfFieldConfig(binding: binding, type: PdfFieldType.text, pageIndex: 0, x: 0, y: 0)],
      );

      final bundle = _CountingAssetBundle();
      final document = PdfDocument(
        assetPath: 'assets/forms/mock.pdf',
        pages: <PdfPageLayout>[layout],
        bundle: bundle,
        compress: false,
      );

      final data = PdfDocumentData(values: const <String, Object?>{'firstName': 'Ada'});

      final bytesOne = await document.generate(using: data);
      final bytesTwo = await document.generate(using: data);

      expect(bytesOne, isNotEmpty);
      expect(bytesTwo, isNotEmpty);
      expect(bundle.loadCount, 2, reason: 'Template loads on each render.');
    });

    test('formats values using default rules', () async {
      final subscribe = PdfFieldBinding.named('subscribe');
      final startedOn = PdfFieldBinding.named('startedOn');
      final layout = PdfPageLayout(
        index: 0,
        pageFormat: PdfPageFormat.a4,
        fields: <PdfFieldConfig>[
          PdfFieldConfig(binding: subscribe, type: PdfFieldType.text, pageIndex: 0, x: 0, y: 0),
          PdfFieldConfig(binding: startedOn, type: PdfFieldType.text, pageIndex: 0, x: 0, y: 0),
        ],
      );

      final bundle = _CountingAssetBundle();
      final document = PdfDocument(
        assetPath: 'assets/forms/mock.pdf',
        pages: <PdfPageLayout>[layout],
        bundle: bundle,
        compress: false,
      );

      final data = PdfDocumentData()
        ..setCheckbox(binding: 'subscribe', value: true)
        ..setValue(binding: 'startedOn', value: DateTime(2024, 1, 5));
      final bytes = await document.generate(using: data);

      expect(bytes, isNotEmpty);

      expect(bundle.loadCount, 1);
      final payload = String.fromCharCodes(bytes);
      expect(payload, contains('X'));
      expect(payload, contains('01/05/2024'));
    });
  });

  group('PdfDocument metadata', () {
    test('infers name when none supplied', () {
      final document = PdfDocument(assetPath: 'templates/contract_v1.pdf', pages: const <PdfPageLayout>[]);
      expect(document.pdfName, 'contract_v1');
    });

    test('derives name from asset path and retains fields', () {
      final firstName = PdfFieldBinding.named('firstName');
      final document = PdfDocument(
        assetPath: 'assets/forms/example.pdf',
        pages: <PdfPageLayout>[
          PdfPageLayout(
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

      expect(document.assetPath, 'assets/forms/example.pdf');
      expect(document.pdfName, 'example');
      expect(document.pages, hasLength(1));
      expect(document.pages.first.fields.single.binding, firstName);
    });
  });
}

class _CountingAssetBundle extends CachingAssetBundle {
  _CountingAssetBundle([Uint8List? bytes]) : bytes = bytes ?? Uint8List(0);

  final Uint8List bytes;
  int loadCount = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCount += 1;
    return bytes.buffer.asByteData();
  }
}
