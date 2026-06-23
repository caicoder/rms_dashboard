import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvFocusHelper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool autofocus;
  final double scaleOnFocus;
  final Color focusColor;
  final BorderRadius borderRadius;
  final FocusNode? focusNode;
  final EdgeInsets? margin;

  const TvFocusHelper({
    Key? key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.autofocus = false,
    this.scaleOnFocus = 1.03,
    this.focusColor = const Color(0xFF3B82F6),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.focusNode,
    this.margin,
  }) : super(key: key);

  @override
  State<TvFocusHelper> createState() => _TvFocusHelperState();
}

class _TvFocusHelperState extends State<TvFocusHelper> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  Timer? _longPressTimer;
  bool _longPressTriggered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    // Only dispose if created internally
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  bool _isSelectKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.dpadCenter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.numpadEnter;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;

    // Handle Menu / ContextMenu keys directly for onLongPress
    if (key == LogicalKeyboardKey.menu || key == LogicalKeyboardKey.contextMenu) {
      if (event is KeyDownEvent && widget.onLongPress != null) {
        widget.onLongPress!();
        return KeyEventResult.handled;
      }
    }

    if (_isSelectKey(key)) {
      if (event is KeyDownEvent) {
        _longPressTriggered = false;
        _longPressTimer?.cancel();
        if (widget.onLongPress != null) {
          _longPressTimer = Timer(const Duration(milliseconds: 600), () {
            _longPressTriggered = true;
            widget.onLongPress!();
          });
        }
        return KeyEventResult.handled;
      } else if (event is KeyUpEvent) {
        _longPressTimer?.cancel();
        if (!_longPressTriggered) {
          widget.onTap();
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: widget.margin ?? EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: widget.focusColor.withOpacity(0.5),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: AnimatedScale(
          scale: _isFocused ? widget.scaleOnFocus : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              border: Border.all(
                color: _isFocused ? widget.focusColor : Colors.transparent,
                width: 2.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
