import 'dart:ui';

/// Immutable snapshot of captured signature strokes.
///
/// Instances can be constructed directly or produced via
/// [SignaturePadController.snapshot]. Each stroke contains the ordered points
/// captured while the user maintained contact with the canvas.
class PdfSignatureData {
  PdfSignatureData({required List<List<Offset>> strokes, Size? canvasSize})
    : strokes = List<List<Offset>>.unmodifiable(strokes.map((final stroke) => List<Offset>.unmodifiable(stroke))),
      canvasSize = canvasSize ?? Size.zero;

  /// Individual strokes, where each stroke is a series of [Offset] samples.
  final List<List<Offset>> strokes;

  /// Size of the drawing surface used to capture [strokes].
  final Size canvasSize;

  /// Indicates whether any meaningful stroke data is present.
  bool get hasSignature => strokes.any((final stroke) => stroke.length > 1);

  /// Returns true when no stroke data is available.
  bool get isEmpty => !hasSignature;
}
