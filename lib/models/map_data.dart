import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

enum MapStyle {
  light, // 默认：黑灰白 (无障碍区域为白色)
  dark,  // 黑色风格 (暗夜模式)
}

class MapConfig {
  double resolution = 0.05;
  double originX = 0.0;
  double originY = 0.0;
  double originTheta = 0.0;
  int width = 0;
  int height = 0;
}

class MapData {
  final MapConfig config;
  final Uint8List rawData;
  ui.Image image;
  MapStyle style;

  MapData({
    required this.config,
    required this.rawData,
    required this.image,
    this.style = MapStyle.light,
  });

  Future<ui.Image> updateStyle(MapStyle newStyle) async {
    style = newStyle;
    final newImage = await generateImage(rawData, config.width, config.height, newStyle);
    image.dispose();
    image = newImage;
    return newImage;
  }

  static Future<ui.Image> generateImage(
    Uint8List rawData,
    int width,
    int height,
    MapStyle style,
  ) async {
    final pixelData = Uint8List(width * height * 4);
    final bool isLight = (style == MapStyle.light);

    for (int py = 0; py < height; py++) {
      for (int px = 0; px < width; px++) {
        int index = py * width + px;
        if (index < rawData.length) {
          int val = rawData[index];
          int pIndex = index * 4;

          int r, g, b;
          if (isLight) {
            // 默认【黑灰白】风格：
            // val < 100 障碍物/墙壁 -> 黑色
            // val > 250 无障碍/通行区域 -> 纯白色
            // 其它 未知区域 -> 浅灰色
            if (val < 100) {
              r = 0; g = 0; b = 0;
            } else if (val > 250) {
              r = 255; g = 255; b = 255;
            } else {
              r = 205; g = 205; b = 205;
            }
          } else {
            // 【黑色暗夜】风格：
            // val < 100 障碍物 -> 暗灰色
            // val > 250 无障碍区域 -> 极深灰色
            // 其它 未知区域 -> 黑灰色
            if (val < 100) {
              r = 60; g = 60; b = 60;
            } else if (val > 250) {
              r = 30; g = 30; b = 30;
            } else {
              r = 20; g = 20; b = 20;
            }
          }

          pixelData[pIndex] = r;
          pixelData[pIndex + 1] = g;
          pixelData[pIndex + 2] = b;
          pixelData[pIndex + 3] = 255;
        }
      }
    }

    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(pixelData);
    final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final ui.Codec codec = await descriptor.instantiateCodec();
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image mapImage = frameInfo.image;

    buffer.dispose();
    descriptor.dispose();
    codec.dispose();

    return mapImage;
  }

  // Load from SN
  static Future<MapData?> loadFromCloud(String sn, {MapStyle initialStyle = MapStyle.light}) async {
    try {
      final yamlUrl = 'https://huaxi-1330823579.cos.ap-shanghai.myqcloud.com/devicemap/$sn/map.yaml';
      final pgmUrl = 'https://huaxi-1330823579.cos.ap-shanghai.myqcloud.com/devicemap/$sn/map.pgm';

      print('Fetching YAML: $yamlUrl');
      final yamlRes = await http.get(Uri.parse(yamlUrl));
      if (yamlRes.statusCode != 200) return null;

      var doc = loadYaml(yamlRes.body);
      final config = MapConfig();
      config.resolution = (doc['resolution'] as num?)?.toDouble() ?? 0.05;
      final origin = doc['origin'] as YamlList?;
      if (origin != null && origin.length >= 2) {
        config.originX = (origin[0] as num).toDouble();
        config.originY = (origin[1] as num).toDouble();
        if (origin.length >= 3) {
          config.originTheta = (origin[2] as num).toDouble();
        }
      }

      print('Fetching PGM: $pgmUrl');
      final pgmRes = await http.get(Uri.parse(pgmUrl));
      if (pgmRes.statusCode != 200) return null;

      final pgmBytes = pgmRes.bodyBytes;
      
      // Parse PGM (P5 binary format)
      int i = 0;
      if (pgmBytes[i] != 80 || pgmBytes[i+1] != 53) return null; // 'P', '5'
      i += 2;
      while (i < pgmBytes.length && _isWhitespace(pgmBytes[i])) i++;
      
      // Handle comments
      while (i < pgmBytes.length && pgmBytes[i] == 35) { // '#'
        while (i < pgmBytes.length && pgmBytes[i] != 10) i++; // read until newline
        i++;
      }
      
      // Read width
      int width = 0;
      while (i < pgmBytes.length && !_isWhitespace(pgmBytes[i])) {
        width = width * 10 + (pgmBytes[i] - 48).toInt();
        i++;
      }
      while (i < pgmBytes.length && _isWhitespace(pgmBytes[i])) i++;
      
      // Read height
      int height = 0;
      while (i < pgmBytes.length && !_isWhitespace(pgmBytes[i])) {
        height = height * 10 + (pgmBytes[i] - 48).toInt();
        i++;
      }
      while (i < pgmBytes.length && _isWhitespace(pgmBytes[i])) i++;
      
      // Read max_val
      int maxVal = 0;
      while (i < pgmBytes.length && !_isWhitespace(pgmBytes[i])) {
        maxVal = maxVal * 10 + (pgmBytes[i] - 48).toInt();
        i++;
      }
      if (maxVal > 255) return null;
      while (i < pgmBytes.length && _isWhitespace(pgmBytes[i])) i++;

      config.width = width;
      config.height = height;

      // Extract raw binary data
      final rawData = pgmBytes.sublist(i);
      final mapImage = await generateImage(rawData, width, height, initialStyle);

      return MapData(config: config, rawData: rawData, image: mapImage, style: initialStyle);
    } catch (e) {
      print('Failed to load map: $e');
      return null;
    }
  }

  static bool _isWhitespace(int byte) {
    return byte == 32 || byte == 10 || byte == 13 || byte == 9;
  }

  // Convert global ROS coordinates to map pixel coordinates
  ui.Offset toPixel(double x, double y) {
    double px = (x - config.originX) / config.resolution;
    double py = config.height - (y - config.originY) / config.resolution;
    return ui.Offset(px, py);
  }
}
