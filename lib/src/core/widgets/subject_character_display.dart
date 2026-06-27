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

  /// Font size for text display, or SVG width/height.
  final double size;

  /// Text color, also used as the SVG stroke color.
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svgUrl = subject.svgUrl;
    if (svgUrl != null) {
      final file = ref.read(resourceServiceProvider).cachedSvgFile(subject);
      if (file != null) {
        final hexColor =
            '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
        final svg = _prepareWaniKaniSvg(file.readAsStringSync(), hexColor);
        return SvgPicture.string(svg, width: size, height: size);
      }
    }
    return Text(
      subject.displayText,
      style: TextStyle(fontSize: size, color: color),
    );
  }
}

/// Transforms a WaniKani radical SVG so that flutter_svg renders it correctly.
///
/// WaniKani SVGs use a `<style>` block with CSS class rules and the custom
/// property `var(--color-text)` for the stroke color. flutter_svg does not
/// support either CSS class styles or CSS custom properties, so paths fall
/// back to solid black fill. This function:
///   1. Parses the `<style>` block to find which class carries the stroke.
///   2. Removes the `<style>` block.
///   3. Replaces that class attribute on path elements with equivalent SVG
///      presentation attributes (fill, stroke, stroke-linecap, etc.).
///   4. Replaces any remaining class attributes with `fill="none"`.
///   5. Converts `style="clip-path:…"` to the `clip-path` attribute form.
String _prepareWaniKaniSvg(String svg, String strokeColor) {
  final styleMatch = RegExp(
    r'<style>(.*?)</style>',
    dotAll: true,
  ).firstMatch(svg);
  if (styleMatch != null) {
    final styleBlock = styleMatch.group(1)!;

    // Find the class that contains stroke:var(--color-text…).
    final strokeClassMatch = RegExp(
      r'\.(\w+)\{[^}]*stroke:var\(--color-text',
    ).firstMatch(styleBlock);
    final strokeClassName = strokeClassMatch?.group(1);

    // Extract stroke-width (digits only, dropping the css "px" unit).
    final strokeWidth =
        RegExp(r'stroke-width:(\d+)').firstMatch(styleBlock)?.group(1) ?? '68';

    // Remove the <style> block.
    svg = svg.replaceAll(RegExp(r'<style>.*?</style>', dotAll: true), '');

    if (strokeClassName != null) {
      // Replace the stroke class with inline presentation attributes.
      svg = svg.replaceAll(
        'class="$strokeClassName"',
        'fill="none" stroke="$strokeColor" stroke-linecap="square" '
            'stroke-miterlimit="2" stroke-width="$strokeWidth"',
      );
    }
  }

  // Replace any leftover class attributes (fill:none-only classes, clipPath
  // children, etc.) with an explicit fill="none".
  svg = svg.replaceAll(RegExp(r'\s+class="[^"]*"'), ' fill="none"');

  // Handle any remaining var(--color-text…) in inline style attributes.
  svg = svg.replaceAll(RegExp(r'var\(--color-text[^)]*\)'), strokeColor);

  // Convert `style="clip-path:url(…)"` to the attribute form; flutter_svg
  // handles the clip-path attribute more reliably than the CSS property.
  svg = svg.replaceAllMapped(
    RegExp(r'style="([^"]*?)clip-path:(url\([^)]+\))([^"]*?)"'),
    (m) {
      final before = m.group(1)!.trim().replaceAll(RegExp(r';$'), '');
      final clipPath = m.group(2)!;
      final after = m.group(3)!.trim().replaceAll(RegExp(r'^;'), '');
      final remaining = [before, after].where((s) => s.isNotEmpty).join(';');
      return remaining.isEmpty
          ? 'clip-path="$clipPath"'
          : 'clip-path="$clipPath" style="$remaining"';
    },
  );

  return svg;
}
