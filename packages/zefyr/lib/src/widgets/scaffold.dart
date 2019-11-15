import 'package:flutter/material.dart';

import 'editor.dart';

/// Provides necessary layout for [ZefyrEditor].
class ZefyrScaffold extends StatefulWidget {
  final Widget child;
  final bool isAutoResize;

  const ZefyrScaffold({Key key, this.child, this.isAutoResize = false }) : super(key: key);

  static ZefyrScaffoldState of(BuildContext context) {
    final _ZefyrScaffoldAccess widget =
        context.inheritFromWidgetOfExactType(_ZefyrScaffoldAccess);
    return widget.scaffold;
  }

  @override
  ZefyrScaffoldState createState() => ZefyrScaffoldState();
}

class ZefyrScaffoldState extends State<ZefyrScaffold> {
  WidgetBuilder _toolbarBuilder;

  void showToolbar(WidgetBuilder builder) {
    setState(() {
      _toolbarBuilder = builder;
    });
  }

  void hideToolbar() {
    if (_toolbarBuilder != null) {
      setState(() {
        _toolbarBuilder = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final toolbar =
        (_toolbarBuilder == null) ? Container() : _toolbarBuilder(context);
    final wrapChild = widget.isAutoResize ?  widget.child : Expanded(child: widget.child);
    return _ZefyrScaffoldAccess(
      scaffold: this,
      child: Column(
        mainAxisSize: widget.isAutoResize ? MainAxisSize.min : MainAxisSize.max,
        children: <Widget>[
          wrapChild,
          Divider(height: 1),
          toolbar,
        ],
      ),
    );
  }
}

class _ZefyrScaffoldAccess extends InheritedWidget {
  final ZefyrScaffoldState scaffold;

  _ZefyrScaffoldAccess({Widget child, this.scaffold}) : super(child: child);

  @override
  bool updateShouldNotify(_ZefyrScaffoldAccess oldWidget) {
    return oldWidget.scaffold != scaffold;
  }
}
