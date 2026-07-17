class EventBusUtils {
  static final EventBusUtils _instance = EventBusUtils._internal();
  
  static EventBusUtils getInstance() {
    return _instance;
  }
  
  EventBusUtils._internal();

  void fire(dynamic event) {
    // Simple mock fire method. Can expand if actual eventbus library is imported.
  }
}

class LoginOutEvent {
  final int type;
  LoginOutEvent(this.type);
}
