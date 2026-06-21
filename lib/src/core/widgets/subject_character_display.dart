import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../resources/resource_providers.dart';
import '../wanikani/models/wanikani_subject.dart';

/// Displays the character for a [WaniKaniSubject]: an SVG image for radicals
/// that have one, or the subject's [WaniKaniSubject.displayText] otherwise.
class SubjectCharacterDisplay extends ConsumerWidget {
  const SubjectCharacterDisplay({
    super.key,
    required this.subject,
    required this.size,
    required this.color,
  });

  final WaniKaniSubject subject;

  /// Font size for text display, or width/height for the SVG.
  final double size;

  /// Text color (non-SVG) or SVG tint color.
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svgUrl = subject.svgUrl;
    if (svgUrl != null) {
      final file =
          ref.read(resourceServiceProvider).cachedSvgFile(subject);
      if (file != null) {
        return SvgPicture.file(
          file,
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      }
    }
    return Text(
      subject.displayText,
      style: TextStyle(fontSize: size, color: color),
    );
  }
}
