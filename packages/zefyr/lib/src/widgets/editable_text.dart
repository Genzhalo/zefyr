// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:notus/notus.dart';

import 'caret.dart';
import 'controller.dart';
import 'cursor_timer.dart';
import 'editor.dart';
import 'image.dart';
import 'input.dart';
import 'mode.dart';
import 'render_context.dart';
import 'render_document.dart';
import 'scope.dart';
import 'selection.dart';
import 'theme.dart';
import 'dart:math' as math;
/// Core widget responsible for editing Zefyr documents.
///
/// Depends on presence of [ZefyrTheme] and [ZefyrScope] somewhere up the
/// widget tree.
///
/// Consider using [ZefyrEditor] which wraps this widget and adds a toolbar to
/// edit style attributes.
class ZefyrEditableText extends StatefulWidget {
  const ZefyrEditableText({
    Key key,
    @required this.controller,
    @required this.focusNode,
    @required this.imageDelegate,
    this.selectionControls,
    this.autofocus = true,
    this.mode = ZefyrMode.edit,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
    this.physics,
  })  : assert(mode != null),
        assert(controller != null),
        assert(focusNode != null),
        super(key: key);
 

  /// Controls the document being edited.
  final ZefyrController controller;

  /// Controls whether this editor has keyboard focus.
  final FocusNode focusNode;
  final ZefyrImageDelegate imageDelegate;

  /// Whether this text field should focus itself if nothing else is already
  /// focused.
  ///
  /// If true, the keyboard will open as soon as this text field obtains focus.
  /// Otherwise, the keyboard is only shown after the user taps the text field.
  ///
  /// Defaults to true. Cannot be null.
  final bool autofocus;

  /// Editing mode of this text field.
  final ZefyrMode mode;

  /// Controls physics of scrollable text field.
  final ScrollPhysics physics;

  /// Optional delegate for building the text selection handles and toolbar.
  ///
  /// If not provided then platform-specific implementation is used by default.
  final TextSelectionControls selectionControls;

  /// Padding around editable area.
  final EdgeInsets padding;

  @override
  _ZefyrEditableTextState createState() => _ZefyrEditableTextState();
}

class _ZefyrEditableTextState extends State<ZefyrEditableText>
    with AutomaticKeepAliveClientMixin {
  //
  // New public members
  //

  /// Document controlled by this widget.
  NotusDocument get document => widget.controller.document;

  /// Current text selection.
  TextSelection get selection => widget.controller.selection;
  FocusNode _focusNode;
  FocusAttachment _focusAttachment;

  /// Express interest in interacting with the keyboard.
  ///
  /// If this control is already attached to the keyboard, this function will
  /// request that the keyboard become visible. Otherwise, this function will
  /// ask the focus system that it become focused. If successful in acquiring
  /// focus, the control will then attach to the keyboard and request that the
  /// keyboard become visible.
  void requestKeyboard() {
    if (_focusNode.hasFocus) {
      _input.openConnection(widget.controller.plainTextEditingValue);
    } else {
      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  void focusOrUnfocusIfNeeded() {
    if (!_didAutoFocus && widget.autofocus && widget.mode.canEdit) {
      FocusScope.of(context).autofocus(_focusNode);
      _didAutoFocus = true;
    }
    if (!widget.mode.canEdit && _focusNode.hasFocus) {
      _didAutoFocus = false;
      _focusNode.unfocus();
    }
  }

  TextSelectionControls defaultSelectionControls(BuildContext context) {
    TargetPlatform platform = Theme.of(context).platform;
    if (platform == TargetPlatform.iOS) {
      return cupertinoTextSelectionControls;
    }
    return materialTextSelectionControls;
  }

  //
  // Overridden members of State
  //


  @override
  Widget build(BuildContext context) {
    _focusAttachment.reparent();
    super.build(context); // See AutomaticKeepAliveState.

    final body = SingleChildScrollView(
      physics: widget.physics,
      controller: _scrollController,
      child: Container(
        padding: widget.padding ?? EdgeInsets.zero,
        child: RenderZefyrDocument(document: document),
      ),
    );
   
    return Stack(
      children: [
        body,
        Positioned(top: 0, left: 0, right: 0, bottom: 0, child: ZefyrSelectionOverlay(
          controls: widget.selectionControls ?? defaultSelectionControls(context),
        )
      )
    ]);
  }


  @override
  void initState() {
    _focusNode = widget.focusNode;
    super.initState();
    _focusAttachment = _focusNode.attach(context);
    _input = InputConnectionController(_handleRemoteValueChange, context, _updateFloatinCursor);
    _updateSubscriptions();
  }

  @override
  void didUpdateWidget(ZefyrEditableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode != widget.focusNode) {
      _focusAttachment.detach();
      _focusNode = widget.focusNode;
      _focusAttachment = _focusNode.attach(context);
    }
    _updateSubscriptions(oldWidget);
    focusOrUnfocusIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = ZefyrScope.of(context);
    if (_renderContext != scope.renderContext) {
      _renderContext?.removeListener(_handleRenderContextChange);
      _renderContext = scope.renderContext;
      _renderContext.addListener(_handleRenderContextChange);
    }
    if (_cursorTimer != scope.cursorTimer) {
      _cursorTimer?.stop();
      _cursorTimer = scope.cursorTimer;
      _cursorTimer.startOrStop(_focusNode, selection);
    }
    focusOrUnfocusIfNeeded();
  }

  @override
  void dispose() {
    _focusAttachment.detach();
    _cancelSubscriptions();
    super.dispose();
  }

  //
  // Overridden members of AutomaticKeepAliveClientMixin
  //

  @override
  bool get wantKeepAlive => _focusNode.hasFocus;

  //
  // Private members
  //

  final ScrollController _scrollController = ScrollController();
  ZefyrRenderContext _renderContext;
  CursorTimer _cursorTimer;
  InputConnectionController _input;
  bool _didAutoFocus = false;

  void _updateSubscriptions([ZefyrEditableText oldWidget]) {
    if (oldWidget == null) {
      widget.controller.addListener(_handleLocalValueChange);
      _focusNode.addListener(_handleFocusChange);
      return;
    }

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_handleLocalValueChange);
      widget.controller.addListener(_handleLocalValueChange);
      _input.updateRemoteValue(widget.controller.plainTextEditingValue);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChange);
      widget.focusNode.addListener(_handleFocusChange);
      updateKeepAlive();
    }
  }

  void _cancelSubscriptions() {
    _renderContext.removeListener(_handleRenderContextChange);
    widget.controller.removeListener(_handleLocalValueChange);
    _focusNode.removeListener(_handleFocusChange);
    _input.closeConnection();
    _cursorTimer.stop();
  }

  // Triggered for both text and selection changes.
  void _handleLocalValueChange() {
    if (widget.mode.canEdit &&
        widget.controller.lastChangeSource == ChangeSource.local) {
      // Only request keyboard for user actions.
      requestKeyboard();
    }
    _input.updateRemoteValue(widget.controller.plainTextEditingValue);
    _cursorTimer.startOrStop(_focusNode, selection);
    setState(() {
      // nothing to update internally.
    });
  }

  void _handleFocusChange() {
    _input.openOrCloseConnection(
        _focusNode, widget.controller.plainTextEditingValue);
    _cursorTimer.startOrStop(_focusNode, selection);
    updateKeepAlive();
  }

  void _handleRemoteValueChange(
      int start, String deleted, String inserted, TextSelection selection) {
    widget.controller
        .replaceText(start, deleted.length, inserted, selection: selection);
  }


  Offset _startFloaingGlobalOffset;
  Rect _rectOfEditorContext = Rect.zero;

  void _updateFloatinCursor(RawFloatingCursorPoint point){
    switch(point.state){
      case FloatingCursorDragState.Start:
        final paragraph = _renderContext.boxForTextOffset(selection.baseOffset);
        if (paragraph != null) {
          final offsetOfCaret = paragraph.getOffsetForCaret(
            TextPosition(offset: selection.baseOffset, affinity: selection.affinity),
            CursorPainter.buildPrototype(2)
          );
          _startFloaingGlobalOffset = paragraph.localToGlobal(offsetOfCaret);
        }
        _rectOfEditorContext = _renderContext.getGlobalRect();
        break;
      case FloatingCursorDragState.Update:
        final newOffset = _calculateBoundedFloatingCursorOffset(_startFloaingGlobalOffset + point.offset);
        final paragraph = _renderContext.boxForGlobalPoint(newOffset);
        if (paragraph != null) {
          final newSelection = paragraph.getPositionForOffset(paragraph.globalToLocal(newOffset));
          if (newSelection.offset != selection.baseOffset){
            widget.controller.updateSelection(
              TextSelection(
                baseOffset: newSelection.offset, 
                extentOffset: newSelection.offset), 
              source: ChangeSource.local
            );         
          }
        } 
        break;
      case FloatingCursorDragState.End:
        _startFloaingGlobalOffset = null;
        _previousOffset = null;
        _rectOfEditorContext = Rect.zero;
        _resetOriginOnLeft = false;
        _resetOriginOnRight = false;
        _resetOriginOnTop = false;
        _resetOriginOnBottom = false;
        _relativeOrigin = Offset(0, 0);
        break;
    }
  }

  void _handleRenderContextChange() {
    setState(() {
      // nothing to update internally.
    });
  }

  // The relative origin in relation to the distance the user has theoretically
  // dragged the floating cursor offscreen. This value is used to account for the
  // difference in the rendering position and the raw offset value.
  Offset _relativeOrigin = const Offset(0, 0);
  Offset _previousOffset;
  bool _resetOriginOnLeft = false;
  bool _resetOriginOnRight = false;
  bool _resetOriginOnTop = false;
  bool _resetOriginOnBottom = false;
  double _resetFloatingCursorAnimationValue;  

  Offset _calculateBoundedFloatingCursorOffset(Offset rawCursorOffset) {
    Offset deltaPosition = const Offset(0, 0);
    final double topBound = _rectOfEditorContext.top;
    final double bottomBound = _rectOfEditorContext.bottom;
    final double leftBound = _rectOfEditorContext.left;
    final double rightBound = _rectOfEditorContext.right;

    if (_previousOffset != null)
      deltaPosition = rawCursorOffset - _previousOffset;

    // If the raw cursor offset has gone off an edge, we want to reset the relative
    // origin of the dragging when the user drags back into the field.
    if (_resetOriginOnLeft && deltaPosition.dx > 0) {
      _relativeOrigin = Offset(rawCursorOffset.dx - leftBound, _relativeOrigin.dy);
      _resetOriginOnLeft = false;
    } else if (_resetOriginOnRight && deltaPosition.dx < 0) {
      _relativeOrigin = Offset(rawCursorOffset.dx - rightBound, _relativeOrigin.dy);
      _resetOriginOnRight = false;
    }
    if (_resetOriginOnTop && deltaPosition.dy > 0) {
      _relativeOrigin = Offset(_relativeOrigin.dx, rawCursorOffset.dy - topBound);
      _resetOriginOnTop = false;
    } else if (_resetOriginOnBottom && deltaPosition.dy < 0) {
      _relativeOrigin = Offset(_relativeOrigin.dx, rawCursorOffset.dy - bottomBound);
      _resetOriginOnBottom = false;
    }

    final double currentX = rawCursorOffset.dx - _relativeOrigin.dx;
    final double currentY = rawCursorOffset.dy - _relativeOrigin.dy;
    final double adjustedX = math.min(math.max(currentX, leftBound), rightBound);
    final double adjustedY = math.min(math.max(currentY, topBound), bottomBound);
    final Offset adjustedOffset = Offset(adjustedX, adjustedY);

    if (currentX < leftBound && deltaPosition.dx < 0)
      _resetOriginOnLeft = true;
    else if (currentX > rightBound && deltaPosition.dx > 0)
      _resetOriginOnRight = true;
    if (currentY < topBound && deltaPosition.dy < 0)
      _resetOriginOnTop = true;
    else if (currentY > bottomBound && deltaPosition.dy > 0)
      _resetOriginOnBottom = true;

    _previousOffset = rawCursorOffset;

    return adjustedOffset;
  }

}
