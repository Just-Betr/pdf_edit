# Example App

This directory holds a minimal Flutter app that demonstrates the `pdf_edit` package.

## Getting started

1. From the repository root run:
   ```sh
   flutter pub get
   cd example
   flutter pub get
   ```
2. Choose an emulator or physical device.
3. Launch the sample:
   ```sh
   flutter run
   ```

The app collects a few fields, captures a signature, and uses `PdfDocumentBuilder` to generate the filled PDF. The bytes are saved to disk so you can inspect them with any viewer on the device.

## Project structure

- `lib/` – Flutter widgets and state used in the demo UI.
- `assets/` – Sample PDF form bundled with the app. Declare additional assets in `pubspec.yaml` if needed. You will also find `getfields.py`, a helper script for inspecting form fields.
- `README.md` – You are here.

## Notes

- Make sure a device or emulator is connected before running `flutter run`.
- Update dependencies with `flutter pub upgrade` if you want to try newer package versions.
- The sample depends on the local `pdf_edit` package via a path reference in `pubspec.yaml`.
- Using `adb exec-out run-as com.example.pdf_edit cat code_cache/example-insert-time-stamp.pdf > example.pdf` will transfer the pdf to your current working directory. Using powershell will break the file, it transfers "text objects" versus raw bytes.

## Using `getfields.py`

The helper script under `assets/getfields.py` reads a PDF and reports the locations of each form field.

1. Install the Python dependency once:
   ```sh
   pip install PyPDF2
   ```
2. Run the script from the repository root (or anywhere) with the target PDF:
   ```sh
   python example/assets/getfields.py path/to/form.pdf
   ```
3. Review the printed output for page numbers and raw coordinates, or inspect the generated JSON file (`<pdf_name>.form_fields.json` by default). The values can be copied directly into `PdfDocumentBuilder` when defining bindings.

Pass `--output <path>` to control where the JSON file is written.
