import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:textspan_parser/textspan_parser.dart';

import 'fake_path_provider.dart';

class CustomHttpOverrides extends HttpOverrides {}

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

  test('bad format fails to parse', () {
    final def = TextSpanDefinition();
    final parser = def.build();
    const badFormat = 'کیا {آپ کی صحت اب ایک}منزل تک سیڑھیاں چڑھنے میں {رکاوٹ ہے} ؟ اگر ہے، تو کس حد تک؟';
    expect(parser.parse(badFormat).isSuccess, isFalse);
  });

  test('bad format still produce text span', () {
    final theme = Typography.englishLike2018;
    const style = TextStyle();
    final eval = TextSpanEvaluator(theme, style, defaultTextStyleEvaluator);
    const badFormat = 'کیا {آپ کی صحت اب ایک}منزل تک سیڑھیاں چڑھنے میں {رکاوٹ ہے} ؟ اگر ہے، تو کس حد تک؟';
    expect(eval.evaluate(badFormat).toPlainText(), badFormat);
  });

  test('evaluate textSpan', () {
    final theme = Typography.englishLike2018;
    const style = TextStyle();
    final eval = TextSpanEvaluator(theme, style, defaultTextStyleEvaluator);

    final result = eval.evaluate('Hello {italic world!}');
    expect(result.children.length, 3);
    expect(result.children[0].toPlainText(), 'Hello ');
    expect(result.children[1].toPlainText(), 'world!');
    expect(result.children[2].toPlainText(), '');
  });

  group('Goldens', () {
    setUp(() async {
      PathProviderPlatform.instance = FakePathProviderPlatform();
    });

    testGoldens('Hello World!', (tester) async {
      final theme = Typography.englishLike2018;
      const style = TextStyle(fontWeight: FontWeight.normal);
      final eval = TextSpanEvaluator(theme, style, defaultTextStyleEvaluator);

      final builder = GoldenBuilder.grid(columns: 2, widthToHeightRatio: 3)
        ..addScenario('1', Text.rich(eval.evaluate('Hello {underline World!}')))
        ..addScenario('2', Text.rich(eval.evaluate('Hello {italic world!}. My name is {underline Kasper}')))
        ..addScenario('3', Text.rich(eval.evaluate('Hello {italic w{headline4 o}rld!}')));

      await tester.pumpWidgetBuilder(builder.build());
      await screenMatchesGolden(tester, 'hello_world_grid');
    });

    testGoldens('Theme styles', (tester) async {
      final theme = Typography.englishLike2018;
      const style = TextStyle(fontWeight: FontWeight.normal);
      final eval = TextSpanEvaluator(theme, style, defaultTextStyleEvaluator);

      final builder = GoldenBuilder.column()..addScenario('styles', Text.rich(eval.evaluate(r'''
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
      ''')));

      await tester.pumpWidgetBuilder(builder.build());
      await screenMatchesGolden(tester, 'theme_styles');
    });

    TextStyle customEvaluator(style, theme, command) {
      final arguments = command.argv;
      if (arguments.length > 1) {
        final op = arguments[0];
        final arg = arguments[1];
        switch (op) {
          case 'color':
            return style.apply(color: Color(int.parse(arg, radix: 16)));
          case 'font':
            return GoogleFonts.getFont(arg.replaceAll('_', ' '), textStyle: style);
        }
      }
      return defaultTextStyleEvaluator(style, theme, command);
    }

    testGoldens('Complex example', (tester) async {
      final theme = Typography.englishLike2018;
      const style = TextStyle(fontWeight: FontWeight.normal);
      final eval = TextSpanEvaluator(theme, style, customEvaluator);

      final span = (await tester.runAsync(() async {
        final result = HttpOverrides.runWithHttpOverrides(() {
          return eval.evaluate(r'''
{headline4 A complex example...}
\n
This is a normal paragraph, sprinkled with a bit of {italic italic}, a bit of 
{caption theming}, and a pinch of {color:ffff0000 color}.
\n\n
The {italic color} command is an example of a custom command, that is interpreted 
by a user supplied {italic TextStyleEvaluator}
\n\n
{bold {italic {underline {color:ff0000ff Now}}}} it gets interesting with a series 
of nested commands. This was achieved with the script: 
{italic \{bold \{italic \{underline \{color:ff0000ff Now\}\}\}\}}. 
\n\n
Using {font:Comic_Neue a {headline6 {italic dynamically}} loaded google font} is another 
trick possible with a custom evaluator. Here we loaded 'Comic Neue'.'''
              .replaceAll('\n', '')); // strip implicit newlines
        }, CustomHttpOverrides());
        await Future.delayed(const Duration(seconds: 1)); // wait for font to load
        return result;
      }));

      final builder = GoldenBuilder.column(
        wrap: (w) => SizedBox(
          child: w,
          width: 300, // force line-wrap
        ),
      )..addScenario('complex', Text.rich(span));
      await tester.pumpWidgetBuilder(builder.build());
      await screenMatchesGolden(tester, 'complex');
    });

    testGoldens('Alignment', (tester) async {
      final builder = GoldenBuilder.column(
        wrap: (w) => SizedBox(
          child: w,
          width: 200,
        ),
      )
        ..addScenario('plain', const Text('Hello'))
        ..addScenario(
          'overflow',
          const Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Hello my friend! '),
              TextSpan(text: 'How do you do?', style: TextStyle(decoration: TextDecoration.underline)),
            ]),
          ),
        )
        ..addScenario(
          'center',
          const Text.rich(
            TextSpan(text: 'Hello'),
            textAlign: TextAlign.center,
          ),
        )
        ..addScenario(
          'end',
          const Text.rich(
            TextSpan(text: 'Hello'),
            textAlign: TextAlign.end,
          ),
        )
        ..addScenario(
          'overflow-then-end',
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Hello my friend! How do you do? '),
              WidgetSpan(
                child: Flex(
                  direction: Axis.horizontal,
                  children: const [
                    Expanded(
                      child: Text(
                        'foo',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
              const TextSpan(text: 'Hello', style: TextStyle()),
            ]),
          ),
        );

      await tester.pumpWidgetBuilder(builder.build());
      await screenMatchesGolden(tester, 'alignment');
    });
  });
}
