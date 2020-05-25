// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:flutter/material.dart';
import 'package:notus/notus.dart';

import 'common.dart';
import 'paragraph.dart';
import 'theme.dart';


abstract class IndentInterface {
  String get next;
}

class BulletIndent implements IndentInterface {
  String get next => '•';
}

class NumberIndent implements IndentInterface {
  int _value = 1;

  String get next => (_value++).toString() + ".";
}

class AlphabetIndent implements IndentInterface {
  static final a = "a".codeUnitAt(0);
  static final z = "z".codeUnitAt(0);
  List<int> _codes = [ a - 1 ]; 

  String get next {
    for(int index = _codes.length - 1; index >= 0; index--) {
      _codes[index]++;
      if (_codes[index] <= z) break;
      _codes[index] = a;
      if (index == 0) _codes.insert(index, a);
    }
    return String.fromCharCodes(_codes) + ".";
  }
}

class RomanNumberIndent implements IndentInterface {
  int _value = 0;
  final _romanNumbersToLetters = {
    1: 'i',
    4: 'iv',
    5: 'v',
    9: 'ix',
    10: 'x',
    40: 'xl',
    50: 'l',
    90: 'xc',
    100: 'c',
    400: 'cd',
    500: 'd',
    900: 'cm',
    1000: 'm'
  };

  String get next { 
    _value++;
    final nRevMap = _romanNumbersToLetters.keys.toList();
    nRevMap.sort((a, b) => b.compareTo(a));
    var curString = '';
    var accum = _value;
    var nIndex = 0;
    while (accum > 0) {
      var divisor = nRevMap[nIndex];
      var units = accum ~/ divisor;
      if (units > 0) {
        var got = _romanNumbersToLetters[divisor];
        if (got != null) {
          curString += got;
          accum -= divisor;
        }
      } else {
        nIndex += 1;
      }
    }
    return curString + ".";
  }
}


/// Represents number lists and bullet lists in a Zefyr editor.
class ZefyrList extends StatelessWidget {

  static IndentInterface getOrderedIterator(int indent) {
    switch(indent  % 3) {
      case 1: return NumberIndent();
      case 2: return AlphabetIndent();
      case 0: return RomanNumberIndent();
      default: return NumberIndent();
    }
  }

  ZefyrList({Key key, @required this.node }) : super(key: key) {
    _indentIterator = node.isBullet ? BulletIndent() : getOrderedIterator(node.indent + 1);
    for(BlockNode block in node.nodesWithTheSameStyle) {
       block.children.forEach((entry) {_indentIterator.next; });
    }
  }

  final BlockNode node;
  IndentInterface _indentIterator;


  @override
  Widget build(BuildContext context) {
    final theme = ZefyrTheme.of(context);
    List<Widget> items = [];

    for (LineNode line in node.children) {
      items.add(
        Padding(
          padding: EdgeInsets.only(left: (node.indent + 1) * theme.indentSize),
          child: ZefyrListItem(
            node: line, 
            bulletText: _indentIterator.next
          )
        )
      );
    }
    return Column(children: items);
  }
}

/// An item in a [ZefyrList].
class ZefyrListItem extends StatelessWidget {
  ZefyrListItem({ Key key, this.node, this.bulletText }) : super(key: key);

  final String bulletText;
  final LineNode node;

  @override
  Widget build(BuildContext context) {
    final theme = ZefyrTheme.of(context);
    TextStyle textStyle;
    Widget content;

    if (node.style.contains(NotusAttribute.heading)) {
      final headingTheme = ZefyrHeading.themeOf(node, context);
      textStyle = headingTheme.textStyle;
      content = ZefyrHeading(node: node);
    } else {
      textStyle = theme.paragraphTheme.textStyle;
      content = RawZefyrLine(node: node, style: textStyle);
    }

    Widget bullet = ConstrainedBox(
      constraints: BoxConstraints(minWidth: 30.0), 
      child: Text(bulletText, style: textStyle, textAlign: TextAlign.right)
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[bullet, SizedBox(width: 5), Expanded(child: content)],
    );
  }
}
