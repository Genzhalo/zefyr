

import 'package:flutter/material.dart';
import 'package:notus/notus.dart';
import '../../zefyr.dart';


class RenderZefyrDocument extends StatelessWidget {
  final NotusDocument document;  
  final Widget firstChild;      
  RenderZefyrDocument({ @required this.document, this.firstChild }) : assert( document != null );

   @override
  Widget build(BuildContext context) {
    List<Widget> children = firstChild != null ? [ firstChild ] : [];
    for (var node in document.root.children) {
      children.add(_defaultChildBuilder(context, node));
    }
    return ListBody(children: children);
  }

  Widget _defaultChildBuilder(BuildContext context, Node node) {
    if (node is LineNode) {
      if (node.hasEmbed) {
        return RawZefyrLine(node: node);
      } else if (node.style.contains(NotusAttribute.heading)) {
        return ZefyrHeading(node: node);
      }
      return ZefyrParagraph(node: node);
    }

    final BlockNode block = node;
    final blockStyle = block.style.get(NotusAttribute.block);
    if (blockStyle == NotusAttribute.block.code) {
      return ZefyrCode(node: block);
    } else if (blockStyle == NotusAttribute.block.bulletList) {
      return ZefyrList(node: block);
    } else if (blockStyle == NotusAttribute.block.numberList) {
      return ZefyrList(node: block);
    } else if (blockStyle == NotusAttribute.block.quote) {
      return ZefyrQuote(node: block);
    }

    throw UnimplementedError('Block format $blockStyle.');
  }

}