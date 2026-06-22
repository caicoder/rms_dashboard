import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../../models/map_data.dart';
import '../../../models/robot_model.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flame/events.dart';

class MapLayerComponent extends PositionComponent {
  final MapData mapData;

  MapLayerComponent(this.mapData) {
    size = Vector2(mapData.config.width.toDouble(), mapData.config.height.toDouble());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawImage(mapData.image, Offset.zero, Paint());
  }
}

class RobotPoseComponent extends PositionComponent {
  final RobotModel robot;
  final MapData mapData;

  RobotPoseComponent(this.robot, this.mapData) {
    size = Vector2(10, 10);
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 实时更新位置
    final px = mapData.toPixel(robot.positionX, robot.positionY);
    position = Vector2(px.dx, px.dy);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()..color = Colors.blueAccent;
    canvas.drawCircle(const Offset(5, 5), 5, paint);
  }
}

class TrajectoryLayerComponent extends PositionComponent with TapCallbacks {
  final RobotModel robot;
  final MapData mapData;
  final void Function(TrajectoryPoint)? onPointClicked;

  TrajectoryLayerComponent(this.robot, this.mapData, {this.onPointClicked}) {
    size = Vector2(mapData.config.width.toDouble(), mapData.config.height.toDouble());
  }

  @override
  bool containsLocalPoint(Vector2 point) => true;

  @override
  void onTapUp(TapUpEvent event) {
    if (onPointClicked == null) return;
    
    final tapX = event.localPosition.x;
    final tapY = event.localPosition.y;
    
    TrajectoryPoint? closestPoint;
    double minDistance = 15.0; // 点击半径阈值

    for (var point in robot.trajectory) {
      final px = mapData.toPixel(point.x, point.y);
      final dx = px.dx - tapX;
      final dy = px.dy - tapY;
      final distance = math.sqrt(dx * dx + dy * dy);
      
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = point;
      }
    }
    
    if (closestPoint != null) {
      onPointClicked!(closestPoint);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (robot.trajectory.length < 2) return;

    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool isFirst = true;

    for (var point in robot.trajectory) {
      final px = mapData.toPixel(point.x, point.y);
      if (isFirst) {
        path.moveTo(px.dx, px.dy);
        isFirst = false;
      } else {
        path.lineTo(px.dx, px.dy);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // Draw dots
    final dotPaint = Paint()..color = Colors.redAccent;
    for (var point in robot.trajectory) {
      final px = mapData.toPixel(point.x, point.y);
      canvas.drawCircle(Offset(px.dx, px.dy), 2.0, dotPaint);
    }
  }
}

class RobotMapGame extends FlameGame with ScaleDetector, ScrollDetector {
  final MapData mapData;
  final RobotModel robot;
  final void Function(TrajectoryPoint)? onPointClicked;
  
  double _currentScale = 1.0;
  double _scaleStartZoom = 1.0;
  Vector2? _lastFocalPoint;

  RobotMapGame(this.mapData, this.robot, {this.onPointClicked});

  @override
  Color backgroundColor() => Colors.black;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final mapLayer = MapLayerComponent(mapData);
    world.add(mapLayer);

    final trajectoryLayer = TrajectoryLayerComponent(robot, mapData, onPointClicked: onPointClicked);
    world.add(trajectoryLayer);

    final robotPose = RobotPoseComponent(robot, mapData);
    world.add(robotPose);

    // Wait for onGameResize to handle initial fit and rotation
  }

  bool _hasInitialFit = false;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!_hasInitialFit && mapData.config.width > 0 && size.x > 0 && size.y > 0) {
      _fitMapToScreen(size);
      _hasInitialFit = true;
    }
  }

  void _fitMapToScreen(Vector2 size) {
    double screenAspect = size.x / size.y;
    double mapAspect = mapData.config.width / mapData.config.height;

    // 如果屏幕很宽而地图很长，或者屏幕很长地图很宽，则自动旋转90度
    bool needsRotation = (screenAspect > 1 && mapAspect < 1) || (screenAspect < 1 && mapAspect > 1);
    
    if (needsRotation) {
      camera.viewfinder.angle = math.pi / 2; // 顺时针旋转90度
    } else {
      camera.viewfinder.angle = 0;
    }

    double visibleMapWidth = needsRotation ? mapData.config.height.toDouble() : mapData.config.width.toDouble();
    double visibleMapHeight = needsRotation ? mapData.config.width.toDouble() : mapData.config.height.toDouble();

    double zoomX = size.x / visibleMapWidth;
    double zoomY = size.y / visibleMapHeight;
    
    // 取最小值确保所有边都在屏幕内
    double fitZoom = math.min(zoomX, zoomY);
    _currentScale = (fitZoom * 0.95).clamp(0.01, 10.0); // 留白5%
    
    camera.viewfinder.zoom = _currentScale;
    camera.viewfinder.position = Vector2(mapData.config.width / 2, mapData.config.height / 2);
  }

  // ========================
  // Scale: handles both single-finger pan AND two-finger pinch-to-zoom
  // ========================
  @override
  void onScaleStart(ScaleStartInfo info) {
    _scaleStartZoom = _currentScale;
    final fp = info.raw.focalPoint;
    _lastFocalPoint = Vector2(fp.dx, fp.dy);
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    // Two-finger pinch: apply zoom
    if (info.raw.pointerCount >= 2) {
      final newScale = (_scaleStartZoom * info.raw.scale).clamp(0.05, 20.0);
      _currentScale = newScale;
      camera.viewfinder.zoom = _currentScale;
    }

    // Pan: works for both single-finger and two-finger (focal point movement)
    final fp = info.raw.focalPoint;
    final currentFocal = Vector2(fp.dx, fp.dy);
    if (_lastFocalPoint != null) {
      final delta = currentFocal - _lastFocalPoint!;
      final a = camera.viewfinder.angle;
      final worldDx = delta.x * math.cos(a) + delta.y * math.sin(a);
      final worldDy = -delta.x * math.sin(a) + delta.y * math.cos(a);
      camera.viewfinder.position -= Vector2(worldDx, worldDy) / _currentScale;
    }
    _lastFocalPoint = currentFocal;
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    _lastFocalPoint = null;
  }

  void zoomIn() {
    _currentScale = (_currentScale * 1.2).clamp(0.01, 20.0);
    camera.viewfinder.zoom = _currentScale;
  }

  void zoomOut() {
    _currentScale = (_currentScale / 1.2).clamp(0.01, 20.0);
    camera.viewfinder.zoom = _currentScale;
  }

  void moveUp() => _panScreen(Vector2(0, -50));
  void moveDown() => _panScreen(Vector2(0, 50));
  void moveLeft() => _panScreen(Vector2(-50, 0));
  void moveRight() => _panScreen(Vector2(50, 0));

  void _panScreen(Vector2 deltaScreen) {
    final a = camera.viewfinder.angle;
    final dx = deltaScreen.x;
    final dy = deltaScreen.y;
    final worldDx = dx * math.cos(a) + dy * math.sin(a);
    final worldDy = -dx * math.sin(a) + dy * math.cos(a);
    camera.viewfinder.position += Vector2(worldDx, worldDy) / _currentScale;
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final zoomChange = -info.scrollDelta.global.y.sign * 0.2;
    _currentScale = (_currentScale + zoomChange).clamp(0.1, 10.0);
    camera.viewfinder.zoom = _currentScale;
  }
}
