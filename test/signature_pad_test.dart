import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_edit/pdf_edit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SignaturePad', () {
    testWidgets('exposes strokes and canvas size via the controller', (
      tester,
    ) async {
      final controller = SignaturePadController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          ),
          home: Scaffold(
            body: Center(
              child: SignaturePad(
                controller: controller,
                canvasSize: const Size(240, 140),
              ),
            ),
          ),
        ),
      );

      expect(controller.canvasSize, const Size(240, 140));
      expect(controller.hasSignature, isFalse);

      final padFinder = find.byType(SignaturePad);
      final gesture = await tester.startGesture(tester.getCenter(padFinder));
      await tester.pump();
      await gesture.moveBy(const Offset(24, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(12, 6));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.hasSignature, isTrue);
      expect(controller.isEmpty, isFalse);
      expect(controller.strokes, isNotEmpty);

      final originalLength = controller.strokes.first.length;
      final mutated = controller.strokes;
      mutated.first.add(const Offset(99, 99));

      expect(
        controller.strokes.first.length,
        originalLength,
        reason: 'strokes should be defensive copies',
      );

      controller.clear();
      await tester.pumpAndSettle();

      expect(controller.hasSignature, isFalse);
      expect(controller.isEmpty, isTrue);
      expect(controller.strokes, isEmpty);
    });
  });
}
