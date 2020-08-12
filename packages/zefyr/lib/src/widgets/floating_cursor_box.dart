import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:zefyr/src/widgets/caret.dart';

const Offset _kFloatingCaretSizeIncrease = Offset(0.5, 1.0);
const double _kFloatingCaretRadius = 1.0;


class FloatingCursorWidget extends LeafRenderObjectWidget {
  final Color cursorColor;
  FloatingCursorWidget({ Key key, this.cursorColor }) : super(key: key);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return FloatingCursorRender(cursorColor: cursorColor);
  } 
}


class FloatingCursorRender extends RenderBox with RenderObjectWithChildMixin<RenderBox>{
  final Color cursorColor;  
  FloatingCursorRender({ this.cursorColor });

  bool _isCursor = false;
  double _lineHeight = 0;
  Offset _offset = Offset.zero;

  void update({ Offset offset, double lineHeight, FloatingCursorDragState state}) {  
    _offset = offset;
    _isCursor = state != FloatingCursorDragState.End;
    _lineHeight = lineHeight ?? _lineHeight;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  void performResize() {
    size = constraints.biggest;
  }

  bool get isCursor => _isCursor;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_isCursor) {
      final Paint paint = Paint()..color = cursorColor.withOpacity(0.75);
      final _cursorRect = CursorPainter.buildPrototype(_lineHeight);

      double sizeAdjustmentX = _kFloatingCaretSizeIncrease.dx;
      double sizeAdjustmentY = _kFloatingCaretSizeIncrease.dy;
      
      final Rect floatingCaretPrototype = Rect.fromLTRB(
        _cursorRect.left - sizeAdjustmentX,
        _cursorRect.top - sizeAdjustmentY,
        _cursorRect.right + sizeAdjustmentX,
        _cursorRect.bottom + sizeAdjustmentY,
      );
  
      final caretRRect = RRect.fromRectAndRadius(
        floatingCaretPrototype.shift(_offset), 
        Radius.circular(_kFloatingCaretRadius)
      );

      context.canvas.drawRRect(caretRRect, paint);
    }
  }
}
