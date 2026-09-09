import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qotg_mobile/components/document_discount_field.dart';
import 'package:qotg_mobile/components/pill_button.dart';

void main() {
  testWidgets('discount typing retains focus across parent updates', (tester) async {
    var discount = 0.0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(builder: (context, setState) =>
      DocumentDiscountField(value: discount, type: 'percentage', onTypeChanged: (_) {},
        onValueChanged: (value) => setState(() => discount = value))))));
    await tester.tap(find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), '12.5');
    await tester.pump();
    expect(discount, 12.5);
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.controller.text, '12.5');
  });
  testWidgets('primary button respects disabled and loading states', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PillButton(text: 'Save', isLoading: true, onTap: () => taps++))));
    await tester.tap(find.byType(FilledButton));
    expect(taps, 0);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });
  testWidgets('document controls fit a narrow screen with large text', (tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        DocumentDiscountField(value: 10, type: 'percentage', onTypeChanged: (_) {}, onValueChanged: (_) {}),
        PillButton(text: 'Save changes', onTap: () {}),
      ]))))));
    expect(tester.takeException(), isNull);
  });
}
