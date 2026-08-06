import 'package:flutter/material.dart';

class DraggableResizableWindow extends StatefulWidget {
  final Widget child;
  final String title;
  final IconData? icon;
  final VoidCallback onClose;
  final VoidCallback onPointerDown; // 用于提升层级
  final Rect initialRect;
  final double minWidth;
  final double minHeight;
  final Widget? extraHeaderWidget; // 标题栏额外的小部件，例如“屏幕控制”按钮

  const DraggableResizableWindow({
    Key? key,
    required this.child,
    required this.title,
    required this.onClose,
    required this.onPointerDown,
    required this.initialRect,
    this.icon,
    this.minWidth = 300,
    this.minHeight = 200,
    this.extraHeaderWidget,
  }) : super(key: key);

  @override
  State<DraggableResizableWindow> createState() => _DraggableResizableWindowState();
}

class _DraggableResizableWindowState extends State<DraggableResizableWindow> {
  late double _left;
  late double _top;
  late double _width;
  late double _height;

  @override
  void initState() {
    super.initState();
    _left = widget.initialRect.left;
    _top = widget.initialRect.top;
    _width = widget.initialRect.width;
    _height = widget.initialRect.height;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _left += details.delta.dx;
      _top += details.delta.dy;
    });
  }

  void _onResizeUpdate(DragUpdateDetails details) {
    setState(() {
      _width = (_width + details.delta.dx).clamp(widget.minWidth, double.infinity);
      _height = (_height + details.delta.dy).clamp(widget.minHeight, double.infinity);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _left,
      top: _top,
      width: _width,
      height: _height,
      child: Listener(
        onPointerDown: (_) => widget.onPointerDown(),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            children: [
              // 标题栏 - 可拖拽
              GestureDetector(
                onPanUpdate: _onPanUpdate,
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E293B),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Row(
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 16, color: Colors.white70),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (widget.extraHeaderWidget != null) widget.extraHeaderWidget!,
                        if (widget.extraHeaderWidget != null) const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                          onPressed: widget.onClose,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 主内容区域
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                  child: Stack(
                    children: [
                      Positioned.fill(child: widget.child),
                      // 右下角缩放手柄
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onPanUpdate: _onResizeUpdate,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeDownRight,
                            child: Container(
                              width: 20,
                              height: 20,
                              color: Colors.transparent, // 扩大点击区域
                              alignment: Alignment.bottomRight,
                              child: const Icon(
                                Icons.filter_none_rounded, // 缩放图标
                                color: Colors.white38,
                                size: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
