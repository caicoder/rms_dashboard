class DingAuthConfig {
  // Callback URL matching DingTalk configuration
  static const String redirectUri = "https://www.huaxiai.com.cn/";
  
  // DingTalk Credentials（RMS 自己的企业内部应用）
  // 需在钉钉开放平台为该应用开通：
  //   通讯录个人信息读权限(Contact.User.Read)、个人手机号信息(Contact.User.mobile)、成员信息读权限
  static const String appId = "9505a1c4-7f04-4fa7-b31f-f998a61549d9";
  static const String agentId = "4401933793";
  static const String appKey = "dingboaqzi27igf7zidf";
  static const String appSecret = "YAhwYE1wO-hdHYfujVLtAV4M_K37S0VbJpafx687VindSzdJKT94Wx4JFBVnO0OH"; 
  
  // 后端中转接口（留空则客户端直连钉钉 OpenAPI）
  static const String backendDingLoginApi = "";
  
  // CorpId (for frontend display or mock, actual validation must be in backend)
  static const String targetCorpId = "dingad4721eca1a179c9a39a90f97fcb1e09";

  // 登录白名单（UserId / unionId / openId）
  // 留空表示不限制，任何成功授权且属于本企业的用户均可登录（与 TRMS 一致）。
  static const List<String> proUserIds = <String>[];

  // 是否启用白名单校验
  static bool get whitelistEnabled => proUserIds.isNotEmpty;
}
