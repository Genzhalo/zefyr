// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:quill_delta/quill_delta.dart';

import 'attributes.dart';
import 'line.dart';
import 'node.dart';

/// A block represents a group of adjacent [LineNode]s with the same block
/// style.
///
/// Block examples: lists, quotes, code snippets.
class BlockNode extends ContainerNode<LineNode>
    with StyledNodeMixin
    implements StyledNode {
  /// Creates new unmounted [BlockNode] with the same attributes.
  BlockNode clone() {
    final node = BlockNode();
    node.applyStyle(style);
    return node;
  }

  /// Unwraps [line] from this block.
  void unwrapLine(LineNode line) {
    assert(children.contains(line));

    if (line.isFirst) {
      line.unlink();
      insertBefore(line);
    } else if (line.isLast) {
      line.unlink();
      insertAfter(line);
    } else {
      /// need to split this block into two as [line] is in the middle.
      BlockNode before = clone();
      insertBefore(before);

      LineNode child = this.first;
      while (child != line) {
        child.unlink();
        before.add(child);
        child = this.first as LineNode;
      }
      line.unlink();
      insertBefore(line);
    }
    optimize();
  }

  bool get isBullet => style.get(NotusAttribute.block) == NotusAttribute.block.bulletList;
  bool get isNumber => style.get(NotusAttribute.block) == NotusAttribute.block.numberList;
  bool get isList => isBullet || isNumber;

  int get indent => style.contains(NotusAttribute.indent) ? style.value(NotusAttribute.indent) : 0;

  List<BlockNode> get listNodesWithTheSameStyle {
    List<BlockNode> list = [];
    if (!isList || isFirst) return list;
    var prev = previous;
    while (prev is BlockNode && prev.isList && prev.indent >= indent ) {
      if ((prev as BlockNode).style == style) list.insert(0, prev);
      prev = prev.previous;
    }
    return list; 
  }

  @override
  LineNode get defaultChild => LineNode();

  @override
  Delta toDelta() {
    // Line nodes take care of incorporating block style into their delta.
    return children
        .map((child) => child.toDelta())
        .fold(Delta(), (a, b) => a.concat(b));
  }

  @override
  String toString() {
    final block = style.value(NotusAttribute.block);
    final buffer = StringBuffer('§ {$block}\n');
    for (var child in children) {
      final tree = child.isLast ? '└' : '├';
      buffer.write('  $tree $child');
      if (!child.isLast) buffer.writeln();
    }
    return buffer.toString();
  }

  @override
  void optimize() {
    if (isEmpty) {
      Node sibling = this.previous;
      unlink();
      if (sibling != null) sibling.optimize();
      return;
    }

    var block = this;
    if (!block.isFirst && block.previous is BlockNode) {
      BlockNode prev = block.previous;
      if (prev.style == block.style) {
        block.moveChildren(prev);
        block.unlink();
        block = prev;
      }
    }
    if (!block.isLast && block.next is BlockNode) {
      BlockNode nextBlock = block.next;
      if (nextBlock.style == block.style) {
        nextBlock.moveChildren(block);
        nextBlock.unlink();
      }
    }
  }
}
