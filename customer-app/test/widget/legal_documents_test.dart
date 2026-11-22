import 'package:delivery_customer/features/legal/legal_documents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la versión legal coincide con la del backend', () {
    expect(currentLegalVersion, '2026-11-21');
  });

  testWidgets('renderiza títulos, viñetas, notas y párrafos', (tester) async {
    late List<Widget> blocks;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      blocks = legalMarkdownBlocks(context,
          '# Título\n\n## Sección\n\n- Punto uno\n> Nota\nTexto normal\n');
      return Scaffold(body: ListView(children: blocks));
    })));
    expect(blocks, hasLength(5));
    expect(find.text('Título'), findsOneWidget);
    expect(find.text('Sección'), findsOneWidget);
    expect(find.text('Punto uno'), findsOneWidget);
    expect(find.text('Nota'), findsOneWidget);
    expect(find.text('Texto normal'), findsOneWidget);
  });
}
