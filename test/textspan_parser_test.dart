import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:textspan_parser/textspan_parser.dart';

void main() {
  test('parse text', () {
    final def = TextSpanDefinition();
    final parser = def.build(start: def.text);
    expect(parser.parse('hello').value, 'hello');
    expect(parser.parse('hello {').value, 'hello '); // cannot eat begin of span, unless ..
    expect(parser.parse('hello \\{').value, 'hello {'); // .. escaped!
    expect(parser.parse(r'\n').value, '\n');
    expect(parser.parse(r'\t').value, '\t');
    expect(parser.parse(r'\u0062').value, '\u0062'); // just 'b'
    expect(parser.parse(r'\u{1f604}').value, '\u{1f604}');
    expect(parser.parse('😄').value, '\u{1f604}');
    expect(parser.parse(r'\u006q').value, 'u006q'); // almost correct unicode will render still
    expect(parser.parse(r'\u0062q').value, 'bq');
  });

  test('parse textSpan', () {
    final def = TextSpanDefinition();
    final parser = def.build();
    expect(parser.parse('Hello {bold world!}').isSuccess, isTrue);
    expect(parser.parse('Hello {bold world!}. My name is {italic Kasper}').isSuccess, isTrue);
    expect(parser.parse('Hello {bold w{large o}rld!}').isSuccess, isTrue);
    expect(parser.parse('Hello {}').isSuccess, isFalse);
    expect(parser.parse('Hello {b}').isSuccess, isTrue); // but doesn't make sense
  });

  test('evaluate textSpan', () {
    final theme = Typography.material2018(platform: TargetPlatform.iOS).black;
    const style = TextStyle();
    final eval = TextSpanEvaluator(theme, style, defaultTextStyleEvaluator).build();

    expect(eval.parse('Hello {italic world!}').isSuccess, isTrue);
  });

  testGoldens('Hello World!', (tester) async {
    final theme = Typography.material2018(platform: TargetPlatform.iOS).black;
    const style = TextStyle(fontWeight: FontWeight.normal);
    final eval = TextSpanEvaluator(theme, style, defaultTextStyleEvaluator).build<TextSpan>();

    final builder = GoldenBuilder.grid(columns: 2, widthToHeightRatio: 3)
      ..addScenario('1', Text.rich(eval.parse('Hello {underline World!}').value))
      ..addScenario('2', Text.rich(eval.parse('Hello {bold world!}. My name is {underline Kasper}').value))
      ..addScenario('3', Text.rich(eval.parse('Hello {bold w{headline1 o}rld!}').value));

    await tester.pumpWidgetBuilder(builder.build());
    await screenMatchesGolden(tester, 'hello_world_grid');
  });

  testGoldens('Alignment', (tester) async {
    final builder = GoldenBuilder.column(
        wrap: (w) => Container(
              child: w,
              width: 200,
            ))
      ..addScenario('plain', Text('Hello'))
      ..addScenario(
        'overflow',
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'Hello my friend! '),
            TextSpan(text: 'How do you do?', style: TextStyle(decoration: TextDecoration.underline)),
          ]),
        ),
      )
      ..addScenario(
        'center',
        Text.rich(
          TextSpan(text: 'Hello'),
          textAlign: TextAlign.center,
        ),
      )
      ..addScenario(
        'end',
        Text.rich(
          TextSpan(text: 'Hello'),
          textAlign: TextAlign.end,
        ),
      )
      ..addScenario(
        'overflow-then-end',
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'Hello my friend! How do you do? '),
//            WidgetSpan(child: Flex(direction: Axis.horizontal, children: [Spacer()])),
            WidgetSpan(
              child: Flex(
                direction: Axis.horizontal,
                children: [
                  Expanded(
                    child: Text(
                      'foo',
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
            TextSpan(text: 'Hello', style: TextStyle()),
          ]),
        ),
      );

    await tester.pumpWidgetBuilder(builder.build());
    await screenMatchesGolden(tester, 'alignment');
  });
}
