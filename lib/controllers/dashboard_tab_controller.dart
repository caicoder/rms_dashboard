import 'package:get/get.dart';

class DashboardTabController extends GetxController {
  final RxInt selectedTabIndex = 0.obs;

  void changeTab(int index) {
    selectedTabIndex.value = index;
  }
}
