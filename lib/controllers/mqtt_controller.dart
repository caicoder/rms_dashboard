import 'dart:convert';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:flutter/foundation.dart';
import 'robot_controller.dart';

class MqttController extends GetxController {
  final String serverUri = 'prod-mqtt.huaxiai.com.cn';
  final int port = kIsWeb ? 8083 : 1883;
  
  MqttClient? client;
  var connectionState = MqttConnectionState.disconnected.obs;

  final RobotController robotController = Get.find<RobotController>();

  @override
  void onInit() {
    super.onInit();
    _connect();
  }

  Future<void> _connect() async {
    // 必须使用固定的 clientId，否则 cleanSession=false 时 broker 可能会拒绝连接或导致连接未响应
    final clientId = 'rms_mac_dashboard_001';
    
    if (kIsWeb) {
      client = MqttBrowserClient('ws://$serverUri', clientId);
      client!.port = port;
    } else {
      client = MqttServerClient(serverUri, clientId);
      client!.port = port;
      client!.logging(on: true); // Enable detailed logging
      client!.keepAlivePeriod = 60;
    }

    client!.setProtocolV311(); // Enforce MQTT 3.1.1
    client!.onDisconnected = onDisconnected;
    client!.onConnected = onConnected;
    client!.onSubscribed = onSubscribed;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs('huaxi', 'huaxi123');
    client!.connectionMessage = connMess;

    try {
      print('Connecting to MQTT broker at $serverUri:$port');
      final status = await client!.connect();
      print('Connect status: ${status?.state}');
    } catch (e) {
      print('Exception: $e');
      client!.disconnect();
    }

    if (client!.connectionStatus!.state == MqttConnectionState.connected) {
      connectionState.value = MqttConnectionState.connected;
      // 使用通配符 '+' 一次性订阅该项目下所有的机器人心跳与事件主题
      client!.subscribe('HuaXi/01/01/huaxi001/D/P/+', MqttQos.atLeastOnce);
      client!.subscribe('HuaXi/01/01/huaxi001/D/U/+', MqttQos.atLeastOnce);
      print('Subscribed to wildcard topics for all robots');
      
      client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        final recMess = c![0].payload as MqttPublishMessage;
        final pt = utf8.decode(recMess.payload.message);
        final topic = c[0].topic;
        _handleMessage(topic, pt);
      });
    } else {
      connectionState.value = MqttConnectionState.disconnected;
    }
  }

  void _handleMessage(String topic, String payload) {
    try {
      // Extract SN from topic: HuaXi/01/01/huaxi001/D/P/{sn}
      final parts = topic.split('/');
      if (parts.length >= 7) {
        final sn = parts[6];
        final data = jsonDecode(payload);
        
        int cmdId = data['cmdId'] ?? 0;
        var body = data['body'];
        
        if (body == null) return;

        if (cmdId == 1) {
          // Heartbeat
          robotController.updateHeartbeat(sn, body);
        } else if (cmdId == 9) {
          // Business events
          String type = body['type']?.toString() ?? '';
          int subtype = body['subtype'] ?? 0;
          if (type == '6') {
            robotController.updateAlarmEvent(sn, body, subtype);
          } else if (type == '4') {
            robotController.updateHealthEvent(sn, body);
          } else {
            var params = body['params'];
            if (params != null) {
              if (type == '1') {
                robotController.updatePatrolEvent(sn, params, subtype);
              } else if (type == '10') {
                robotController.updatePatrolStatus(sn, params, subtype);
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
  }

  void subscribeToRobot(String sn) {
    // 已经采用通配符 '+' 统一订阅，此处不再需要单独发订阅请求以降低网络开销
  }

  void unsubscribeFromRobot(String sn) {
    // 通配符统一订阅模式下，大盘不需要针对单个机器取消订阅，直接在本地移出模型即可
  }

  void onDisconnected() {
    print('MQTT client disconnected');
    connectionState.value = MqttConnectionState.disconnected;
  }

  void onConnected() {
    print('MQTT client connected');
  }

  void onSubscribed(String topic) {
    print('Subscribed to topic: $topic');
  }

  @override
  void onClose() {
    client?.disconnect();
    super.onClose();
  }
}
