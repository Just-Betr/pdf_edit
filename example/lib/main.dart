import 'package:flutter/material.dart';
import 'package:pdf_edit/pdf_edit.dart';

import 'pdf_form_page.dart';

void main() {
  final builder = PdfDocumentBuilder(assetPath: 'assets/example.pdf')
    ..text(page: 0, binding: 'firstName', x: 120.0, y: 200.0, size: const Size(140.0, 20.0))
    ..text(page: 0, binding: 'lastName', x: 120.0, y: 230.0, size: const Size(140.0, 20.0))
    ..checkbox(page: 0, binding: 'subscribe', x: 360.0, y: 230.0, size: const Size(16.0, 16.0))
    ..signature(page: 0, binding: 'signature', x: 100.0, y: 400.0, size: const Size(240.0, 60.0));

  final document = builder.build();

  runExampleApp(document);
}

void runExampleApp(final PdfDocument document) {
  runApp(PdfEditApp(document: document));
}

class PdfEditApp extends StatelessWidget {
  const PdfEditApp({super.key, required this.document});

  final PdfDocument document;

  @override
  Widget build(final BuildContext context) {
    return MaterialApp(
      title: 'PDF Edit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: PdfFormPage(document: document),
    );
  }
}
