// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:notus/notus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zefyr/src/widgets/looker.dart';

import 'editable_box.dart';
import 'horizontal_rule.dart';
import 'image.dart';
import 'rich_text.dart';
import 'scope.dart';
import 'theme.dart';

/// Raw widget representing a single line of rich text document in Zefyr editor.
///
/// See [ZefyrParagraph] and [ZefyrHeading] which wrap this widget and
/// integrate it with current [ZefyrTheme].
class RawZefyrLine extends StatefulWidget {
  const RawZefyrLine({
    Key key,
    @required this.node,
    this.style,
    this.padding,
  }) : super(key: key);

  /// Line in the document represented by this widget.
  final LineNode node;

  /// Style to apply to this line. Required for lines with text contents,
  /// ignored for lines containing embeds.
  final TextStyle style;

  /// Padding to add around this paragraph.
  final EdgeInsets padding;

  @override
  _RawZefyrLineState createState() => _RawZefyrLineState();
}

class _RawZefyrLineState extends State<RawZefyrLine> {
  final LayerLink _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final scope = ZefyrScope.of(context);
    final theme = ZefyrTheme.of(context);

    Widget content;
    if (widget.node.hasEmbed) {
      content = buildEmbed(context, scope);
    } else {
      assert(widget.style != null);
      content = ZefyrRichText(
        node: widget.node,
        text: buildText(context, scope),
      );
    }

    if (scope.isEditable) {
      content = EditableBox(
        child: content,
        node: widget.node,
        layerLink: _link,
        renderContext: scope.renderContext,
        showCursor: scope.showCursor,
        selection: scope.selection,
        selectionColor: theme.selectionColor,
        cursorColor: theme.cursorColor,
      );
      content = CompositedTransformTarget(link: _link, child: content);
    }

    if (widget.padding != null) {
      return Padding(padding: widget.padding, child: content);
    }
    return content;
  }

  TextSpan buildText(BuildContext context, ZefyrScope scope) {
    final theme = ZefyrTheme.of(context);
    final List<TextSpan> children = widget.node.children
        .map((node) => _segmentToTextSpan(node, theme, scope))
        .toList(growable: false);
    return TextSpan(style: widget.style, children: children);
  }

  TextSpan _segmentToTextSpan(Node node, ZefyrThemeData theme, ZefyrScope scope) {
    final TextNode segment = node;
    final attrs = segment.style;

    if (attrs.contains(NotusAttribute.link)) {
      return LinkTextSpan(
        text: segment.value,
        style: _getTextStyle(attrs, theme),
        link: attrs.value(NotusAttribute.link),
        isEnabled: !scope.mode.canEdit
      );
    }

    if (attrs.contains(NotusAttribute.mention)){
      return MentionTextSpan(
        text: segment.value,
        style: theme.boldStyle
      );
    }

    return TextSpan(
      text: segment.value,
      style: _getTextStyle(attrs, theme),
    );
  }

  TextStyle _getTextStyle(NotusStyle style, ZefyrThemeData theme) {
    TextStyle result = TextStyle();
    if (style.containsSame(NotusAttribute.bold)) {
      result = result.merge(theme.boldStyle);
    }
    if (style.containsSame(NotusAttribute.italic)) {
      result = result.merge(theme.italicStyle);
    }
    if (style.containsSame(NotusAttribute.underline)) {
      result = result.merge(theme.underlineStyle);
    }
    if (style.contains(NotusAttribute.mention)) {
      result = result.merge(theme.boldStyle);
    }
    if (style.contains(NotusAttribute.link)) {
      result = result.merge(theme.linkStyle);
    }
    return result;
  }

  Widget buildEmbed(BuildContext context, ZefyrScope scope) {
    EmbedNode node = widget.node.children.single;
    EmbedAttribute embed = node.style.get(NotusAttribute.embed);
    if (embed.type == EmbedType.looker) {
      return ZefyrLooker(node: node, delegate: scope.lookerDelegate);
    } else if (embed.type == EmbedType.horizontalRule) {
      return ZefyrHorizontalRule(node: node);
    } else if (embed.type == EmbedType.image) {
      return ZefyrImage(node: node, delegate: scope.imageDelegate);
    } else {
      throw UnimplementedError('Unimplemented embed type ${embed.type}');
    }
  }
}


class MentionTextSpan extends TextSpan {
  MentionTextSpan({ String text, TextStyle style }) : super(text: text, style: style);
}

class LinkTextSpan extends TextSpan {
  final String link;
  final bool isEnabled;
  LinkTextSpan({ String text, TextStyle style, this.link, this.isEnabled = false }) : super(text: text, style: style);

  void onTap() async {
    if (isEnabled) { 
      if (await canLaunch(link)) {
        await launch(link);
      }
    }
  }
}