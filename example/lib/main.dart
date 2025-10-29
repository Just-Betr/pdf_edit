import 'package:flutter/material.dart';

import 'pdf_form_page.dart';

void main() {
  runApp(PdfEditApp());
}

class PdfEditApp extends StatelessWidget {
  const PdfEditApp({super.key});

  @override
  Widget build(final BuildContext context) {
    return MaterialApp(
      title: 'PDF Edit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const PdfFormPage(),
    );
  }
}
