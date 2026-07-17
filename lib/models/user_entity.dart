/// userId : 6
/// scope : null
/// access_token : "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJsb2dpblR5cGUiOiJsb2dpbiIsImxvZ2luSWQiOiJzeXNfdXNlcjo2Iiwicm5TdHIiOiIxa2NJaDVxcTNGVlJwQ0ljR05CY2tWRUswem0xNUdzcSIsImNsaWVudGlkIjoiYTMzM2JhMWFmNWI3ODgzMzI4OWQwMGRkMjc0YTJhMmQiLCJ0ZW5hbnRJZCI6IjE1Njg0NiIsInVzZXJJZCI6NiwidXNlck5hbWUiOiIxMzgxMTExMTExMSIsImRlcHRJZCI6MTg0ODI2Njc1OTc5OTgxMjExMCwiZGVwdE5hbWUiOiLog6Hmo67nhpnmnLrmnoQwMyIsImRlcHRDYXRlZ29yeSI6IiJ9.q5PBM8LVPKGLYO7HoFKQl6kqNu1Ru9JwPyLPw3sIES4"
/// refresh_token : null
/// expire_in : 604799
/// refresh_expire_in : null
/// client_id : "a333ba1af5b78833289d00dd274a2a2d"
/// is_modified : null

class UserEntity {
  UserEntity({
    dynamic userId,
    dynamic scope,
    String? accessToken,
    dynamic refreshToken,
    num? expireIn,
    dynamic refreshExpireIn,
    String? clientId,
    dynamic isModified,
  }) {
    _userId = userId;
    _scope = scope;
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _expireIn = expireIn;
    _refreshExpireIn = refreshExpireIn;
    _clientId = clientId;
    _isModified = isModified;
  }

  UserEntity.fromJson(dynamic json) {
    _userId = json['userId'];
    _scope = json['scope'];
    _accessToken = json['access_token'];
    _refreshToken = json['refresh_token'];
    _expireIn = json['expire_in'];
    _refreshExpireIn = json['refresh_expire_in'];
    _clientId = json['client_id'];
    _isModified = json['is_modified'];
  }
  dynamic _userId;
  dynamic _scope;
  String? _accessToken;
  dynamic _refreshToken;
  num? _expireIn;
  dynamic _refreshExpireIn;
  String? _clientId;
  dynamic _isModified;
  UserEntity copyWith({
    String? userId,
    dynamic scope,
    String? accessToken,
    dynamic refreshToken,
    num? expireIn,
    dynamic refreshExpireIn,
    String? clientId,
    dynamic isModified,
  }) =>
      UserEntity(
        userId: userId ?? _userId,
        scope: scope ?? _scope,
        accessToken: accessToken ?? _accessToken,
        refreshToken: refreshToken ?? _refreshToken,
        expireIn: expireIn ?? _expireIn,
        refreshExpireIn: refreshExpireIn ?? _refreshExpireIn,
        clientId: clientId ?? _clientId,
        isModified: isModified ?? _isModified,
      );
  dynamic get userId => _userId;
  dynamic get scope => _scope;
  String? get accessToken => _accessToken;
  dynamic get refreshToken => _refreshToken;
  num? get expireIn => _expireIn;
  dynamic get refreshExpireIn => _refreshExpireIn;
  String? get clientId => _clientId;
  dynamic get isModified => _isModified;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['userId'] = _userId;
    map['scope'] = _scope;
    map['access_token'] = _accessToken;
    map['refresh_token'] = _refreshToken;
    map['expire_in'] = _expireIn;
    map['refresh_expire_in'] = _refreshExpireIn;
    map['client_id'] = _clientId;
    map['is_modified'] = _isModified;
    return map;
  }
}
