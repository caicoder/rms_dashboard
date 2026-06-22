import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'robot_controller.dart';

class MqttController extends GetxController with WidgetsBindingObserver {
  final String serverUri = 'prod-mqtt.huaxiai.com.cn';
  final int port = kIsWeb ? 8083 : 1883;

  MqttClient? client;
  StreamSubscription? _messageSubscription;
  var connectionState = MqttConnectionState.disconnected.obs;
  var isRetrying = false.obs;
  var retryCount = 0.obs;
  Timer? _reconnectTimer;
  Timer? _healthCheckTimer;

  // Track last message time for health check
  DateTime _lastMessageTime = DateTime.now();
  // Health check: if no message received in 3x keepAlive period, reconnect
  static const Duration _messageTimeOut = Duration(minutes: 3);

  final RobotController robotController = Get.find<RobotController>();

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _connect();
    _startHealthCheck();
  }

  // =========================
  // AppLifecycle handling
  // =========================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('AppLifecycle changed to: $state');
    if (state == AppLifecycleState.resumed) {
      // App returned to foreground — verify connection is still alive
      _checkAndRecoverConnection();
    }
  }

  Future<void> _checkAndRecoverConnection() async {
    // Give a short delay for the system to restore network
    await Future.delayed(const Duration(seconds: 2));

    final isActuallyConnected = client?.connectionStatus?.state == MqttConnectionState.connected;
    if (!isActuallyConnected) {
      print('Connection lost while in background, triggering reconnect...');
      manualReconnect();
    } else {
      print('Connection still alive after resume.');
    }
  }

  // =========================
  // Health check: application-level heartbeat using message timeout
  // =========================
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _performHealthCheck();
    });
  }

  void _performHealthCheck() {
    // Skip if already reconnecting or disconnected
    if (isRetrying.value) return;
    if (connectionState.value != MqttConnectionState.connected) return;

    // Check 1: library-level connection status
    final isConnected = client?.connectionStatus?.state == MqttConnectionState.connected;
    if (!isConnected) {
      print('Health check: library reports disconnected. Reconnecting...');
      connectionState.value = MqttConnectionState.disconnected;
      _scheduleReconnect();
      return;
    }

    // Check 2: message timeout — if no MQTT message received for too long
    final timeSinceLastMsg = DateTime.now().difference(_lastMessageTime);
    if (timeSinceLastMsg > _messageTimeOut) {
      print('Health check: No MQTT message received for ${timeSinceLastMsg.inSeconds}s. Reconnecting...');
      _forceReconnect();
    }
  }

  void _forceReconnect() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    client?.disconnect();
    connectionState.value = MqttConnectionState.disconnected;
    _scheduleReconnect();
  }

  // =========================
  // Connection & Reconnection
  // =========================
  Future<void> _connect() async {
    // Clean up old subscription before creating new client
    await _cleanupOldClient();

    // Use a unique clientId to prevent connection conflicts
    final clientId = 'rms_mac_dashboard_${DateTime.now().millisecondsSinceEpoch}';

    if (kIsWeb) {
      client = MqttBrowserClient('ws://$serverUri', clientId);
      client!.port = port;
    } else {
      client = MqttServerClient.withPort(serverUri, clientId, port);
      client!.logging(on: true);
      client!.keepAlivePeriod = 60;
    }

    client!.setProtocolV311();
    client!.onDisconnected = onDisconnected;
    client!.onConnected = onConnected;
    client!.onSubscribed = onSubscribed;

    // Do NOT call startClean() — we want cleanSession=false to preserve subscriptions across reconnects
    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs('huaxi', 'huaxi123');
    client!.connectionMessage = connMess;

    try {
      print('Connecting to MQTT broker at $serverUri:$port');
      final status = await client!.connect();
      print('Connect status: ${status?.state}');
    } catch (e) {
      print('MQTT connection exception: $e');
      try {
        client?.disconnect();
      } catch (_) {}
    }

    if (client?.connectionStatus?.state == MqttConnectionState.connected) {
      connectionState.value = MqttConnectionState.connected;
      isRetrying.value = false;
      retryCount.value = 0;
      _reconnectTimer?.cancel();
      _lastMessageTime = DateTime.now();

      // Subscribe with wildcard '+' to all robot heartbeat/event topics
      client!.subscribe('HuaXi/01/01/huaxi001/D/P/+', MqttQos.atLeastOnce);
      client!.subscribe('HuaXi/01/01/huaxi001/D/U/+', MqttQos.atLeastOnce);
      print('Subscribed to wildcard topics for all robots');

      // Cancel old subscription before creating new one
      _messageSubscription?.cancel();
      _messageSubscription = client!.updates!.listen(_onMessageReceived);
    } else {
      connectionState.value = MqttConnectionState.disconnected;
      _scheduleReconnect();
    }
  }

  Future<void> _cleanupOldClient() async {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    try {
      client?.disconnect();
    } catch (_) {}
    client = null;
  }

  void _onMessageReceived(List<MqttReceivedMessage<MqttMessage?>>? c) {
    if (c == null || c.isEmpty) return;
    _lastMessageTime = DateTime.now(); // Update health check timestamp

    final recMess = c[0].payload as MqttPublishMessage;
    final pt = utf8.decode(recMess.payload.message);
    final topic = c[0].topic;
    _handleMessage(topic, pt);
  }

  // =========================
  // Reconnect scheduling with exponential backoff (no hard limit)
  // =========================
  void _scheduleReconnect() {
    if (connectionState.value == MqttConnectionState.connected) return;
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;

    isRetrying.value = true;
    retryCount.value++;

    // Exponential backoff: 10s, 20s, 40s, 80s, 160s (cap at 300s = 5 min)
    final delaySeconds = (10 * (1 << (retryCount.value - 1))).clamp(10, 300);
    print('Scheduling reconnect attempt ${retryCount.value} in $delaySeconds seconds...');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _connect();
    });
  }

  void manualReconnect() {
    print('Manual reconnect triggered');
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    retryCount.value = 0;
    isRetrying.value = true;
    _connect();
  }

  // =========================
  // Message handling
  // =========================
  void _handleMessage(String topic, String payload) {
    try {
      final parts = topic.split('/');
      if (parts.length >= 7) {
        final sn = parts[6];
        final data = jsonDecode(payload);

        int cmdId = data['cmdId'] ?? 0;
        var body = data['body'];

        if (body == null) return;

        if (cmdId == 1) {
          robotController.updateHeartbeat(sn, body);
        } else if (cmdId == 9) {
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
    // Wildcard subscription already covers all SNs
  }

  void unsubscribeFromRobot(String sn) {
    // Wildcard subscription covers all; just remove locally
  }

  // =========================
  // Callbacks
  // =========================
  void onDisconnected() {
    print('MQTT client disconnected (callback)');
    connectionState.value = MqttConnectionState.disconnected;
    _scheduleReconnect();
  }

  void onConnected() {
    print('MQTT client connected (callback)');
  }

  void onSubscribed(String topic) {
    print('Subscribed to topic: $topic');
  }

  // =========================
  // Cleanup
  // =========================
  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _messageSubscription?.cancel();
    _messageSubscription = null;
    client?.disconnect();
    client = null;
    super.onClose();
  }
}
