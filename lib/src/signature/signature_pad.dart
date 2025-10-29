import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'pdf_signature_data.dart';

class SignaturePadController extends ChangeNotifier {
  SignaturePadController();

  List<List<Offset>> _strokes = const <List<Offset>>[];
  Size _canvasSize = Size.zero;
  VoidCallback? _clearCallback;

  List<List<Offset>> get strokes => _strokes.map((final stroke) => List<Offset>.from(stroke)).toList(growable: false);

  /// Size of the capture surface in logical pixels. This reflects the
  /// dimensions provided to the accompanying [SignaturePad] and can differ
  /// from the PDF field size declared in the builder (measured in points).
  Size get canvasSize => _canvasSize;

  bool get hasSignature => _strokes.any((final stroke) => stroke.length > 1);

  bool get isEmpty => !hasSignature;

  void clear() {
    _clearCallback?.call();
  }

  void _bind({
    required final VoidCallback clearCallback,
    required final List<List<Offset>> initialStrokes,
    required final Size canvasSize,
  }) {
    _clearCallback = clearCallback;
    _updateFromWidget(initialStrokes, canvasSize);
  }

  void _unbind(final VoidCallback clearCallback) {
    if (identical(_clearCallback, clearCallback)) {
      _clearCallback = null;
    }
  }

  void _updateFromWidget(final List<List<Offset>> strokes, final Size canvasSize) {
    final hasSameSize = _canvasSize == canvasSize;
    final hasSameStrokes = _hasSameStrokes(strokes);
    if (hasSameSize && hasSameStrokes) {
      return;
    }
    _strokes = strokes.map((final stroke) => List<Offset>.unmodifiable(stroke)).toList(growable: false);
    _canvasSize = canvasSize;
    notifyListeners();
  }

  /// Captures the current strokes and drawing surface into a [PdfSignatureData].
  PdfSignatureData snapshot() {
    return PdfSignatureData(strokes: _strokes, canvasSize: _canvasSize);
  }

  bool _hasSameStrokes(final List<List<Offset>> candidate) {
    if (_strokes.length != candidate.length) {
      return false;
    }
    for (var i = 0; i < candidate.length; i++) {
      if (!listEquals(_strokes[i], candidate[i])) {
        return false;
      }
    }
    return true;
  }
}

/// Signature capture widget that exposes captured strokes via [SignaturePadController].
class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    required this.controller,
    required this.canvasSize,
    this.strokeWidth = 2.4,
    this.cornerRadius = 12,
    this.backgroundColor,
  });

  final SignaturePadController controller;
  final Size canvasSize;
  final double strokeWidth;
  final double cornerRadius;
  final Color? backgroundColor;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  List<List<Offset>> _strokes = <List<Offset>>[];
  List<Offset> _currentStroke = <Offset>[];
  ScrollHoldController? _scrollHold;

  @override
  void initState() {
    super.initState();
    widget.controller._bind(
      clearCallback: _clearPad,
      initialStrokes: _snapshotStrokes(),
      canvasSize: widget.canvasSize,
    );
  }

  @override
  void didUpdateWidget(final SignaturePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._unbind(_clearPad);
      widget.controller._bind(
        clearCallback: _clearPad,
        initialStrokes: _snapshotStrokes(),
        canvasSize: widget.canvasSize,
      );
      return;
    }
    if (oldWidget.canvasSize != widget.canvasSize) {
      _scheduleControllerSync();
    }
  }

  @override
  void dispose() {
    widget.controller._unbind(_clearPad);
    _releaseScrollHold();
    super.dispose();
  }

  List<List<Offset>> _snapshotStrokes() {
    return _strokes.map((final stroke) => List<Offset>.from(stroke)).toList(growable: false);
  }

  void _scheduleControllerSync() {
    WidgetsBinding.instance.addPostFrameCallback((final _) {
      if (!mounted) {
        return;
      }
      widget.controller._updateFromWidget(_snapshotStrokes(), widget.canvasSize);
    });
  }

  void _clearPad() {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentStroke = <Offset>[];
      _strokes = <List<Offset>>[];
    });
    _scheduleControllerSync();
  }

  void _holdScrollIfNeeded() {
    if (_scrollHold != null) {
      return;
    }
    final position = Scrollable.maybeOf(context)?.position;
    if (position != null) {
      _scrollHold = position.hold(() {});
    }
  }

  void _releaseScrollHold() {
    _scrollHold?.cancel();
    _scrollHold = null;
  }

  void _startStroke(final Offset position) {
    final newStroke = <Offset>[position];
    setState(() {
      _currentStroke = newStroke;
      _strokes = <List<Offset>>[..._strokes, newStroke];
    });
    _scheduleControllerSync();
  }

  void _handlePanDown(final DragDownDetails details) {
    _holdScrollIfNeeded();
    if (_currentStroke.isNotEmpty) {
      return;
    }
    _startStroke(details.localPosition);
  }

  void _pushPoint(final Offset position) {
    if (_currentStroke.isEmpty) {
      return;
    }
    setState(() {
      _currentStroke.add(position);
      _strokes = <List<Offset>>[..._strokes];
    });
    _scheduleControllerSync();
  }

  void _finishStroke() {
    if (_currentStroke.isEmpty) {
      _releaseScrollHold();
      return;
    }
    setState(() {
      _currentStroke = <Offset>[];
      _strokes = <List<Offset>>[..._strokes];
    });
    _scheduleControllerSync();
    _releaseScrollHold();
  }

  @override
  Widget build(final BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.cornerRadius),
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.canvasSize.width,
          height: widget.canvasSize.height,
          child: ColoredBox(
            color: widget.backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                _ImmediatePanGestureRecognizer: GestureRecognizerFactoryWithHandlers<_ImmediatePanGestureRecognizer>(
                  () => _ImmediatePanGestureRecognizer(),
                  (final instance) {
                    instance.onDown = _handlePanDown;
                    instance.onStart = (final details) {
                      if (_currentStroke.isEmpty) {
                        _startStroke(details.localPosition);
                      }
                    };
                    instance.onUpdate = (final details) => _pushPoint(details.localPosition);
                    instance.onEnd = (final _) => _finishStroke();
                    instance.onCancel = _finishStroke;
                  },
                ),
              },
              child: CustomPaint(
                painter: _SignaturePainter(
                  strokes: _strokes,
                  strokeWidth: widget.strokeWidth,
                  color: Theme.of(context).colorScheme.primary,
                ),
                isComplex: true,
                willChange: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({required this.strokes, required this.strokeWidth, required this.color});

  final List<List<Offset>> strokes;
  final double strokeWidth;
  final Color color;

  @override
  void paint(final Canvas canvas, final Size size) {
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final stroke in strokes) {
      if (stroke.isEmpty) {
        continue;
      }
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, strokeWidth * 0.5, dotPaint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(final _SignaturePainter oldDelegate) {
    if (!identical(oldDelegate.strokes, strokes)) {
      return true;
    }
    if (oldDelegate.strokeWidth != strokeWidth) {
      return true;
    }
    if (oldDelegate.color != color) {
      return true;
    }
    return false;
  }
}

class _ImmediatePanGestureRecognizer extends PanGestureRecognizer {
  _ImmediatePanGestureRecognizer() {
    dragStartBehavior = DragStartBehavior.down;
  }

  @override
  void addAllowedPointer(final PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }
}
