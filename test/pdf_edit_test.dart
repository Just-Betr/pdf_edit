import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_edit/pdf_edit.dart';

const MethodChannel _printingChannel = MethodChannel('net.nfet.printing');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    _printingChannel.setMockMethodCallHandler((MethodCall call) async {
      if (call.method == 'rasterPdf') {
        final int? job = call.arguments['job'] as int?;
        if (job != null) {
          // Complete the raster stream immediately with no pages.
          ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
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
    _printingChannel.setMockMethodCallHandler(null);
  });

  group('PdfDocumentBuilder', () {
    test('build renders the configured fields', () async {
      final bundle = _TestAssetBundle.empty();
      final signature = PdfSignatureData(
        strokes: <List<Offset>>[
          <Offset>[const Offset(0, 0), const Offset(10, 5)],
        ],
        canvasSize: const Size(120, 40),
      );

      final builder = PdfDocumentBuilder(assetPath: 'assets/mock.pdf', bundle: bundle);

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
      final layouts = document.pages;
      expect(layouts, hasLength(1));
      final page = layouts.single;
      expect(page.fields, hasLength(3));
      expect(page.fields.first.binding.value, 'firstName');
    });
    test('generate returns rendered bytes', () async {
      final bundle = _TestAssetBundle.empty();
      final builder = PdfDocumentBuilder(assetPath: 'assets/mock.pdf', bundle: bundle);

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

    test('fromBytes builder renders using provided template bytes', () async {
      final templateDoc = pw.Document()
        ..addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (final context) => pw.Container()));
      final templateBytes = await templateDoc.save();

      final builder = PdfDocumentBuilder.fromBytes(bytes: templateBytes, name: 'downloaded_form');

      builder.text(page: 0, binding: 'fullName', x: 12.0, y: 24.0, size: const Size(120.0, 18.0));

      final document = builder.build();
      document.data.setText(binding: 'fullName', value: 'Ada Lovelace');

      final rendered = await document.generate();

      expect(rendered, isNotEmpty);
      expect(document.pdfName, 'downloaded_form');
      expect(() => document.assetPath, throwsStateError);
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

class _TestAssetBundle extends CachingAssetBundle {
  _TestAssetBundle(this.bytes);

  _TestAssetBundle.empty() : this(Uint8List(0));

  final Uint8List bytes;

  @override
  Future<ByteData> load(String key) async {
    return bytes.buffer.asByteData();
  }
}
