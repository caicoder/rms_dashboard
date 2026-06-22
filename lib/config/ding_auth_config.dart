class DingAuthConfig {
  // Callback URL matching DingTalk configuration
  static const String redirectUri = "https://www.huaxiai.com.cn";
  
  // DingTalk AppKey
  static const String appKey = "dingboaqzi27igf7zidf";
  
  // Your real backend API endpoint that will take the 'code' and AppSecret to get the user token
  static const String backendDingLoginApi = "https://your-backend.com/api/auth/ding-login";
  
  // CorpId (for frontend display or mock, actual validation must be in backend)
  static const String targetCorpId = "dingad4721eca1a179c9a39a90f97fcb1e09";

  // Allowed User IDs (Whitelist)
  static const List<String> proUserIds = [
    "185704456832568076",
    "061267104438643993",
    "162214276120472408",
    "054143443625933731",
    "014555171536549691",
    "200138430835513282",
    "216732471624271837",
    "125358116626598745",
    "064703103024284888",
    "01441155244235901239"
  ];
}
