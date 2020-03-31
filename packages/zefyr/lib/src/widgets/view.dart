// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:notus/notus.dart';
import 'package:zefyr/src/widgets/looker.dart';
import 'package:zefyr/zefyr.dart';
import 'image.dart';
import 'scope.dart';
import 'theme.dart';

/// Non-scrollable read-only view of Notus rich text documents.
@experimental
class ZefyrView extends StatefulWidget {
  final NotusDocument document;
  final ZefyrImageDelegate imageDelegate;
  final ZefyrLookerDelegate lookerDelegate;
  
  const ZefyrView({Key key, @required this.document, this.imageDelegate, this.lookerDelegate })
      : super(key: key);

  @override
  ZefyrViewState createState() => ZefyrViewState();
}

class ZefyrViewState extends State<ZefyrView> {
  ZefyrScope _scope;
  ZefyrThemeData _themeData;

  ZefyrImageDelegate get imageDelegate => widget.imageDelegate;

  @override
  void initState() {
    super.initState();
    _scope = ZefyrScope.view(imageDelegate: widget.imageDelegate, lookerDelegate: widget.lookerDelegate );
  }

  @override
  void didUpdateWidget(ZefyrView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scope.imageDelegate = widget.imageDelegate;
    _scope.lookerDelegate = widget.lookerDelegate;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parentTheme = ZefyrTheme.of(context, nullOk: true);
    final fallbackTheme = ZefyrThemeData.fallback(context);
    _themeData = (parentTheme != null)
        ? fallbackTheme.merge(parentTheme)
        : fallbackTheme;
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ZefyrTheme(
      data: _themeData,
      child: ZefyrScopeAccess(
        scope: _scope,
        child: RenderZefyrDocument(document: widget.document)
      ),
    );
  }
}
