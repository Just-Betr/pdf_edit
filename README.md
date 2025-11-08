## pdf_edit

`pdf_edit` turns static PDF templates into personalised documents.

## Building blocks

- **PdfDocumentBuilder** – describe template pages and fields. Call `build()` to produce a `PdfDocument` ready for rendering.
- **PdfDocument** – holds the compiled template definition, resolves template bytes and backgrounds automatically, exposes `PdfDocumentData`, and renders bytes via `generate()`.
- **PdfDocumentData** – mutable store for field values. Set text, checkbox, and signature bindings on the document after building.
- **PdfSignatureData** – immutable helper for passing captured ink when you need manual control.
- **SignaturePad / SignaturePadController** – drop-in Flutter widget for capturing ink strokes and canvas dimensions for signature fields.

## Workflow

Follow this flow when generating personalised PDFs:

### 1. Describe template bindings

```dart
import 'dart:ui';

import 'package:pdf_edit/pdf_edit.dart';

final builder = PdfDocumentBuilder(assetPath: 'assets/forms/example.pdf')
  ..text(
    page: 0,
    binding: 'firstName',
    x: 120.0,
    y: 200.0,
    size: const Size(140.0, 20.0),
  )
  ..text(
    page: 0,
    binding: 'lastName',
    x: 120.0,
    y: 230.0,
    size: const Size(140.0, 20.0),
  )
  ..checkbox(
    page: 0,
    binding: 'subscribe',
    x: 360.0,
    y: 230.0,
    size: const Size(16.0, 16.0),
  )
  ..signature(
    page: 0,
    binding: 'signature',
    x: 100.0,
    y: 400.0,
    size: const Size(240.0, 60.0),
  );

final document = builder.build();
```

### 2. Populate data bindings

Use a controller per signature field so each binding captures the correct strokes.

```dart
final signatureController = SignaturePadController();

document.data
  ..setText(binding: 'firstName', value: 'Ada')
  ..setText(binding: 'lastName', value: 'Lovelace')
  ..setCheckbox(binding: 'subscribe', value: true)
  ..setSignature(binding: 'signature', controller: signatureController);
```

### 3. Render the PDF

Call `document.generate()` to render the document and obtain the raw bytes. If
you need different data without mutating the original document, pass an
alternate `PdfDocumentData` via the `using` parameter.

```dart
final Uint8List pdfBytes = await document.generate();
// Persist or share `pdfBytes` as needed.
```

### 4. Rehydrate existing PDFs

Existing byte arrays can be wrapped in a `PdfDocument` for downstream export workflows.

```dart
final Uint8List cachedBytes = await storage.loadPdf();
final cachedDocument = PdfDocument.fromBytes(bytes: cachedBytes);
final Uint8List regeneratedBytes = await cachedDocument.generate();
```

## Example app

The `/example` directory contains a minimal Flutter application that captures a few text fields, an optional checkbox, and a signature before saving the filled PDF to disk using the builder. Use it as a reference implementation or drop-in starter.

### Extracting field coordinates with `getfields.py`

When working with unfamiliar PDFs, you can introspect the form field positions with
`example/assets/getfields.py`:

1. Install `PyPDF2` if you have not already:
  ```sh
  pip install PyPDF2
  ```
2. Run the script, pointing it at your template:
  ```sh
  python example/assets/getfields.py path/to/form.pdf
  ```
  It prints a summary of each field and writes a JSON file next to the PDF
  (you can override the destination with `--output`). The `flutterConfig`
  values in the JSON map directly to the coordinates expected by
  `PdfDocumentBuilder`.

Contributions and issues are welcome. If you need support for additional field types or have ideas to streamline authoring, please open a ticket.

Licensed under the BSD 3-Clause License. See [LICENSE](LICENSE) for details.
