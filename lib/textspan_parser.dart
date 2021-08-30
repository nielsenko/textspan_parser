library textspan_parser;

import 'package:flutter/material.dart';
import 'package:petitparser/petitparser.dart';

extension Intertwined<T> on Parser<T> {
  /// Returns a parser that consumes the receiver one or more times intertwined
  /// by the [separator] parser. The resulting parser returns a flat list of
  /// the parse results of the receiver interleaved with the parse result of the
  /// separator parser. The type parameter `R` defines the type of the returned
  /// list.
  ///
  /// For example, the parser `digit().intertwined(char('-'))` returns a parser
  /// that consumes input like `'-1-2-3-'` and returns a list of the elements and
  /// separators: `['-'. '1', '-', '2', '-', '3', '-']`.
  Parser<List<R>> intertwined<R>(Parser separator) {
    final parser = [
      separator,
      [this, separator].toSequenceParser().star(),
    ].toSequenceParser();
    return parser.map((list) {
      final result = <R>[];
      result.add(list[0]);
      for (final tuple in list[1]) {
        result.add(tuple[0]);
        result.add(tuple[1]);
      }
      return result;
    });
  }
}

typedef TextStyleEvaluator = TextStyle Function(TextStyle, TextTheme, Command);

abstract class Node {
  TextSpan toTextSpan(TextStyle style, TextTheme theme, TextStyleEvaluator evaluator);
}

class MixedNode extends Node {
  final List<Node> subSpans;

  MixedNode(this.subSpans);

  @override
  String toString() {
    return '{ subSpans: $subSpans }';
  }

  @override
  TextSpan toTextSpan(TextStyle style, TextTheme theme, TextStyleEvaluator evaluator) {
    return TextSpan(children: subSpans.map((n) => n.toTextSpan(style, theme, evaluator)).toList());
  }
}

class TextNode extends Node {
  final String text;

  TextNode(this.text);

  @override
  String toString() => text;

  @override
  TextSpan toTextSpan(TextStyle style, TextTheme theme, TextStyleEvaluator evaluator) => TextSpan(text: text, style: style);
}

class SpanNode extends Node {
  final Command command;
  final Node node;

  SpanNode(this.command, this.node);

  @override
  String toString() {
    return '{ command: $command, node: $node }';
  }

  @override
  TextSpan toTextSpan(TextStyle style, TextTheme theme, TextStyleEvaluator evaluator) {
    return node.toTextSpan(evaluator(style, theme, command), theme, evaluator);
  }
}

class Command {
  final List<String> argv;

  Command(this.argv);
}

class TextSpanDefinition extends GrammarDefinition {
  @override
  Parser start() => ref(textSpan).end();

  Parser<MixedNode> textSpan() => ref(span).intertwined<Node>(text().map((t) => TextNode(t))).map((subSpans) {
        return MixedNode(subSpans);
      });

  Parser<SpanNode> span() => (beginSpan() & command() & ref(textSpan) & endSpan()).map((list) {
        final command = list[1] as Command;
        final node = list[2] as Node;
        return SpanNode(command, node);
      });

  Parser<Command> command() =>
      ((letter() & word().star()).flatten().trim()).separatedBy<String>(char(':'), includeSeparators: false).map((c) => Command(c));

  Parser<String> text() => characterPrimitive().star().map((v) {
        // use map-join instead of flatten here, as flatten only works on buffer
        // offsets, and doesn't honor actual results (see escapedCharacter parser)
        return v.join();
      });

  Parser<String> beginSpan() => char('{');
  Parser<String> endSpan() => char('}');
  Parser<String> escape() => char('\\');

  Parser<String> characterPrimitive() => [normalCharacter(), unicodeCharacter(), escapedCharacter()].toChoiceParser().cast<String>();
  Parser<String> normalCharacter() => [beginSpan(), endSpan(), escape()].toChoiceParser().neg().map((c) {
        return c;
      });
  Parser<String> escapedCharacter() => [escape(), any()].toSequenceParser().pick(1).map((c) {
        return escapeChars[c] ?? c;
      });
  Parser<String> unicodeCharacter() => (string('\\u') & (unicode(4) | (char('{') & unicode(5) & char('}')).pick(1))).pick(1).cast<String>();
  Parser<String> unicode(int digits) => hexDigit().times(digits).flatten().map((v) => String.fromCharCode(int.parse(v, radix: 16)));
  Parser<String> hexDigit() => pattern('0-9A-Fa-f');

  static const escapeChars = {
    'n': '\n',
    't': '\t',
  };
}

TextStyle defaultTextStyleEvaluator(style, theme, command) {
  final op = command.argv[0];
  return () {
        switch (op) {
          case 'bold':
          case 'w700':
          case 'b':
            return style.copyWith(fontWeight: FontWeight.bold);
          case 'italic':
          case 'i':
            return style.apply(fontStyle: FontStyle.italic);
          case 'underline':
          case 'u':
            return style.apply(decoration: TextDecoration.underline);

          // Text theme styles
          case 'bodyText1':
            return theme.bodyText1;
          case 'bodyText2':
            return theme.bodyText2;

          case 'button':
            return theme.button;

          case 'caption':
            return theme.caption;

          case 'headline1':
            return theme.headline1;
          case 'headline2':
            return theme.headline2;
          case 'headline3':
            return theme.headline3;
          case 'headline4':
            return theme.headline4;
          case 'headline5':
            return theme.headline5;
          case 'headline6':
            return theme.headline6;

          case 'overline':
            return theme.overline;

          case 'subtitle1':
            return theme.subtitle1;
          case 'subtitle2':
            return theme.subtitle1;

          default:
            return null;
        }
      }() ??
      style; // fallback to same style, if new one not calculated
}

class TextSpanEvaluator {
  final Parser _parser = TextSpanDefinition().build();
  final TextTheme theme;
  final TextStyle initialStyle;
  final TextStyleEvaluator evaluator;

  TextSpanEvaluator(this.theme, this.initialStyle, this.evaluator);

  TextSpan evaluate(String input) {
    final result = _parser.parse(input);
    return result.isSuccess ? result.value.toTextSpan(initialStyle, theme, evaluator) : TextSpan(text: input);
  }
}
