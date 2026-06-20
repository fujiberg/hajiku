import 'package:flutter/material.dart';

import '../wanikani/models/wanikani_assignment.dart';
import '../theme/subject_type_style.dart';

/// Matches WaniKani's mnemonic markup tags, e.g. `<radical>...</radical>`.
final _tagPattern = RegExp(
  r'<(radical|kanji|vocabulary|meaning|reading|ja)>(.*?)</\1>',
  dotAll: true,
);

/// Renders mnemonic/hint text from the WaniKani API, which uses simple
/// inline tags (`<radical>`, `<kanji>`, `<vocabulary>`, `<meaning>`,
/// `<reading>`, `<ja>`) to highlight key terms.
class WaniKaniMarkupText extends StatelessWidget {
  const WaniKaniMarkupText({super.key, required this.text, this.style});

  /// The raw mnemonic text, including markup tags.
  final String text;

  /// Base style for plain (untagged) text. Tagged spans are derived from
  /// this style.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final spans = <TextSpan>[];
    var index = 0;

    for (final match in _tagPattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(
          TextSpan(text: text.substring(index, match.start), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(2),
          style: _styleForTag(match.group(1)!, baseStyle),
        ),
      );
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index), style: baseStyle));
    }

    return Text.rich(TextSpan(children: spans, style: baseStyle));
  }

  TextStyle _styleForTag(String tag, TextStyle baseStyle) {
    switch (tag) {
      case 'radical':
        return baseStyle.copyWith(
          color: WaniKaniSubjectType.radical.color,
          fontWeight: FontWeight.bold,
        );
      case 'kanji':
        return baseStyle.copyWith(
          color: WaniKaniSubjectType.kanji.color,
          fontWeight: FontWeight.bold,
        );
      case 'vocabulary':
        return baseStyle.copyWith(
          color: WaniKaniSubjectType.vocabulary.color,
          fontWeight: FontWeight.bold,
        );
      case 'ja':
        return baseStyle.copyWith(
          color: WaniKaniSubjectType.kanaVocabulary.color,
          fontStyle: FontStyle.italic,
        );
      case 'meaning':
      case 'reading':
        return baseStyle.copyWith(fontWeight: FontWeight.bold);
      default:
        return baseStyle;
    }
  }
}
