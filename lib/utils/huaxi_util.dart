import 'package:get/get.dart';

class HuaxiUtil {
  static final RxBool _isLogn = false.obs;
  static bool get isLogn => _isLogn.value;
  static set isLogn(bool value) => _isLogn.value = value;

  static const String serverUrl = 'https://prod-api.huaxiai.com.cn';
}
