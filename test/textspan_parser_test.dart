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
    final theme = Typography.englishLike2018;
    const style = TextStyle();
    final eval = TextSpanEvaluator(theme, style, defaultTextStyleEvaluator).build();

    expect(eval.parse('Hello {italic world!}').isSuccess, isTrue);
  });

  testGoldens('Hello World!', (tester) async {
    final theme = Typography.englishLike2018;
    const style = TextStyle(fontWeight: FontWeight.normal);
    final eval = TextSpanEvaluator(theme, style, defaultTextStyleEvaluator).build<TextSpan>();

    final builder = GoldenBuilder.grid(columns: 2, widthToHeightRatio: 3)
      ..addScenario('1', Text.rich(eval.parse('Hello {underline World!}').value))
      ..addScenario('2', Text.rich(eval.parse('Hello {italic world!}. My name is {underline Kasper}').value))
      ..addScenario('3', Text.rich(eval.parse('Hello {italic w{headline4 o}rld!}').value));

    await tester.pumpWidgetBuilder(builder.build());
    await screenMatchesGolden(tester, 'hello_world_grid');
  });

  TextStyleEvaluator customEvaluator = (theme, style, command) {
    final arguments = command.argv;
    if (arguments.length > 1) {
      final op = arguments[0];
      final arg = arguments[1];
      switch (op) {
        case 'color':
          return theme.apply(color: Color(int.parse(arg, radix: 16)));
        case 'font':
          return theme.apply(fontFamily: arg);
      }
    }
    return defaultTextStyleEvaluator(theme, style, command);
  };

  testGoldens('Theme styles', (tester) async {
    final theme = Typography.englishLike2018;
    const style = TextStyle(fontWeight: FontWeight.normal);
    final eval = TextSpanEvaluator(theme, style, defaultTextStyleEvaluator).build<TextSpan>();

    final builder = GoldenBuilder.column()..addScenario('complex', Text.rich(eval.parse(r'''
      {bodyText1 bodyText1}
      {bodyText2 bodyText2}
      {button button}
      {caption caption}
      {headline1 headline1}
      {headline2 headline2}
      {headline3 headline3}
      {headline4 headline4}
      {headline5 headline5}
      {headline5 headline5}
      {headline6 headline6}
      {overline overline}
      {subtitle1 subtitle1}
      {subtitle2 subtitle2}
      ''').value));

    await tester.pumpWidgetBuilder(builder.build());
    await screenMatchesGolden(tester, 'theme_styles');
  });

  testGoldens('Complex example', (tester) async {
    final theme = Typography.englishLike2018;
    const style = TextStyle(fontWeight: FontWeight.normal);
    final eval = TextSpanEvaluator(theme, style, customEvaluator).build<TextSpan>();

    final builder = GoldenBuilder.column()..addScenario('complex', Text.rich(eval.parse(r'''
      {headline3 A complex example...}
      This is a normal paragraph, sprinkled with a bit of {italic italic}, a bit of 
      {caption theming}, and a pinch of {color:ffff0000 color}.

      {bold {italic {underline {color:ff0000ff Now}}}} it gets interesting with nested commands.
      This was achieved with \{bold \{italic \{underline \{color:ff0000ff Now\}\}\}\}.
      ''').value));

    await tester.pumpWidgetBuilder(builder.build());
    await screenMatchesGolden(tester, 'complex');
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
