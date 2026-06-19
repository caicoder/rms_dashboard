import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

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
  final ui.Image image;

  MapData({required this.config, required this.image});

  // Load from SN
  static Future<MapData?> loadFromCloud(String sn) async {
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
      // Header: P5 \n width height \n max_val \n
      int i = 0;
      // Read magic number
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
        width = width * 10 + (pgmBytes[i] - 48);
        i++;
      }
      while (i < pgmBytes.length && _isWhitespace(pgmBytes[i])) i++;
      
      // Read height
      int height = 0;
      while (i < pgmBytes.length && !_isWhitespace(pgmBytes[i])) {
        height = height * 10 + (pgmBytes[i] - 48);
        i++;
      }
      while (i < pgmBytes.length && _isWhitespace(pgmBytes[i])) i++;
      
      // Read max_val
      int maxVal = 0;
      while (i < pgmBytes.length && !_isWhitespace(pgmBytes[i])) {
        maxVal = maxVal * 10 + (pgmBytes[i] - 48);
        i++;
      }
      if (maxVal > 255) return null; // We only support 8-bit PGM
      while (i < pgmBytes.length && _isWhitespace(pgmBytes[i])) i++; // consume single whitespace after maxVal

      config.width = width;
      config.height = height;

      // Extract raw binary data
      final rawData = pgmBytes.sublist(i);
      
      // Convert raw grayscale to RGBA
      final pixelData = Uint8List(width * height * 4);
      for (int py = 0; py < height; py++) {
        for (int px = 0; px < width; px++) {
          int index = py * width + px;
          if (index < rawData.length) {
            int val = rawData[index];
            int pIndex = index * 4;
            
            // Map the PGM val (0=black/obstacle, 254/255=white/free, 205=gray/unknown)
            if (val < 100) {
              // Obstacle
              pixelData[pIndex] = 60; // R
              pixelData[pIndex + 1] = 60; // G
              pixelData[pIndex + 2] = 60; // B
              pixelData[pIndex + 3] = 255; // A
            } else if (val > 250) {
              // Free space
              pixelData[pIndex] = 30; // R
              pixelData[pIndex + 1] = 30; // G
              pixelData[pIndex + 2] = 30; // B
              pixelData[pIndex + 3] = 255; // A
            } else {
              // Unknown space
              pixelData[pIndex] = 20; // R
              pixelData[pIndex + 1] = 20; // G
              pixelData[pIndex + 2] = 20; // B
              pixelData[pIndex + 3] = 255; // A
            }
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

      return MapData(config: config, image: mapImage);
    } catch (e) {
      print('Failed to load map: $e');
      return null;
    }
  }

  static bool _isWhitespace(int byte) {
    return byte == 32 || byte == 10 || byte == 13 || byte == 9; // space, newline, carriage return, tab
  }

  // Convert global ROS coordinates to map pixel coordinates
  ui.Offset toPixel(double x, double y) {
    double px = (x - config.originX) / config.resolution;
    double py = config.height - (y - config.originY) / config.resolution;
    return ui.Offset(px, py);
  }
}
