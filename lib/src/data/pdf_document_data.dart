import 'dart:ui';

import '../signature/pdf_signature_data.dart';
import '../signature/signature_pad.dart';

typedef SignatureStrokes = List<List<Offset>>;

/// Mutable container for the values and signatures that drive PDF rendering.
///
/// Instances are attached to [PdfDocument] objects and provide a focused API
/// for setting rich data bindings. Values are stored by their template binding
/// name and can be populated incrementally before rendering.
class PdfDocumentData {
  /// Creates a populated store from optional [values] and [signatures].
  PdfDocumentData({
    final Map<String, Object?>? values,
    final Map<String, PdfSignatureData>? signatures,
  }) {
    if (values != null) {
      _values.addAll(values);
    }
    if (signatures != null) {
      _signatures.addAll(signatures);
    }
  }

  final Map<String, Object?> _values = <String, Object?>{};
  final Map<String, PdfSignatureData> _signatures =
      <String, PdfSignatureData>{};

  /// Snapshot of the current values keyed by binding name.
  Map<String, Object?> get values => Map<String, Object?>.unmodifiable(_values);

  /// Snapshot of captured signatures keyed by binding name.
  Map<String, PdfSignatureData> get signatures =>
      Map<String, PdfSignatureData>.unmodifiable(_signatures);

  /// Sets or clears an arbitrary value for [binding].
  void setValue({required final String binding, final Object? value}) {
    if (value == null) {
      _values.remove(binding);
    } else {
      _values[binding] = value;
    }
  }

  /// Convenience for storing a string value.
  void setText({required final String binding, required final String value}) =>
      setValue(binding: binding, value: value);

  /// Convenience for storing a checkbox value.
  void setCheckbox({
    required final String binding,
    required final bool value,
  }) => setValue(binding: binding, value: value);

  /// Sets or clears the signature associated with [binding] using a
  /// [SignaturePadController].
  ///
  /// Passing `null` or a controller with no meaningful strokes removes the
  /// stored signature. Captured strokes are defensively copied so the data
  /// remains stable even if the controller is cleared later on.
  void setSignature({
    required final String binding,
    SignaturePadController? controller,
  }) {
    if (controller == null || controller.isEmpty) {
      _signatures.remove(binding);
      return;
    }

    _signatures[binding] = PdfSignatureData(
      strokes: controller.strokes,
      canvasSize: controller.canvasSize,
    );
  }

  /// Sets or clears the signature associated with [binding] using pre-built
  /// [PdfSignatureData]. Useful when signature capture originates outside the
  /// packaged [SignaturePadController].
  void setSignatureData({
    required final String binding,
    final PdfSignatureData? signature,
  }) {
    if (signature == null || signature.isEmpty) {
      _signatures.remove(binding);
    } else {
      _signatures[binding] = signature;
    }
  }

  /// Returns the raw value for [binding], or `null` if the binding is unset.
  Object? value(final String binding) => _values[binding];

  /// Returns the signature for [binding], or `null` when no signature is stored.
  PdfSignatureData? signature(final String binding) => _signatures[binding];
}
