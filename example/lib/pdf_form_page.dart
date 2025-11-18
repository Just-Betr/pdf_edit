import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_edit/pdf_edit.dart';

class PdfFormPage extends StatefulWidget {
  const PdfFormPage({super.key, required this.document});

  final PdfDocument document;

  @override
  State<PdfFormPage> createState() => _PdfFormPageState();
}

class _PdfFormPageState extends State<PdfFormPage> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final SignaturePadController _signatureController;
  bool _someFlag = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _signatureController = SignaturePadController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signatureWidth = MediaQuery.sizeOf(context).width - 40;
    final double canvasWidth = signatureWidth < 0 ? 0 : signatureWidth;

    return Scaffold(
      appBar: AppBar(title: const Text('PDF Form Insertion POC'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Text('Information', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _firstNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'First Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lastNameController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                    ),
                    CheckboxListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Some thing important?'),
                      value: _someFlag,
                      onChanged: (value) => setState(() => _someFlag = value ?? false),
                    ),
                    const SizedBox(height: 24),
                    Text('Signature', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 220,
                          child: SignaturePad(controller: _signatureController, canvasSize: Size(canvasWidth, 220)),
                        ),
                        const SizedBox(height: 8),
                        // Preferred to do this. Because adding a listener
                        // Will call notifyListeners on the first build of the controller.
                        // This will throw a "set state during build" error.
                        AnimatedBuilder(
                          animation: _signatureController,
                          builder: (final context, final _) {
                            final canClear = _signatureController.hasSignature;
                            return TextButton.icon(
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Clear signature'),
                              onPressed: canClear ? _signatureController.clear : null,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.save_alt_outlined),
                label: _isSaving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save PDF'),
                onPressed: _isSaving
                    ? null
                    : () async {
                        setState(() => _isSaving = true);

                        final document = widget.document;
                        document.data
                          ..setText(binding: 'firstName', value: _firstNameController.text.trim())
                          ..setText(binding: 'lastName', value: _lastNameController.text.trim())
                          ..setCheckbox(binding: 'subscribe', value: _someFlag)
                          ..setSignature(binding: 'signature', controller: _signatureController);

                        try {
                          final pdfBytes = await document.generate();
                          final pdfName = document.pdfName;
                          final filename = '$pdfName-${DateTime.now().millisecondsSinceEpoch}.pdf';
                          final directory = Directory.systemTemp;
                          final file = File('${directory.path}/$filename');
                          await file.writeAsBytes(pdfBytes, flush: true);
                          debugPrint('Saved PDF to: ${file.path}');
                          if (!mounted) {
                            return;
                          }
                          _someFlag = false;
                          _signatureController.clear();
                          _firstNameController.clear();
                          _lastNameController.clear();
                          setState(() {
                            _isSaving = false;
                          });
                          debugPrint('Saved to ${file.path}');
                        } catch (error, stackTrace) {
                          debugPrint('Failed to save PDF: $error\n$stackTrace');
                          if (!mounted) {
                            return;
                          }
                          setState(() => _isSaving = false);
                          debugPrint('Failed to save PDF');
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
