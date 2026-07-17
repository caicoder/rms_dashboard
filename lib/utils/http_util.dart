import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart' as Get;
import 'log_util.dart';
import 'event_bus_utils.dart';
import 'huaxi_util.dart';

/*
 * dio网络请求失败的回调错误码
 */
class ResultCode {
  //正常返回是1
  static const SUCCESS = 1;

  //异常返回是0
  static const ERROR = 1;

  /// When opening url timeout, it occurs.
  static const CONNECT_TIMEOUT = -1;

  ///It occurs when receiving timeout.
  static const RECEIVE_TIMEOUT = -2;

  /// When the server response, but with a incorrect status, such as 404, 503...
  static const RESPONSE = -3;

  /// When the request is cancelled, dio will throw a error with this type.
  static const CANCEL = -4;

  /// read the DioError.error if it is not null.
  static const DEFAULT = -5;
}

const bool _debug = kDebugMode;

class HttpUtil {
  //写一个单例
  //在 Dart 里，带下划线开头的变量是私有变量
  static HttpUtil? _instance;

  String? httpHeader;

  static HttpUtil? getInstance() {
    if (_instance == null) {
      _instance = HttpUtil();
    }
    return _instance;
  }

  Dio dio = Dio();
  HttpUtil() {
    // Set default configs
    if (_debug == true) {
      dio.options.baseUrl = HuaxiUtil.serverUrl; //正式环境
    } else {
      dio.options.baseUrl = HuaxiUtil.serverUrl; //正式环境
    }
    dio.options.connectTimeout = const Duration(seconds: 30);
    dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  // 抛出Dio 实例
  Dio getDio() {
    return dio;
  }

  void setHeader({required String headerkey, required String headerValue}) {
    dio.options.headers[headerkey] = headerValue;
  }

  Future setupProxy(String proxyHostAndPort) async {
    if (proxyHostAndPort.isNotEmpty) {
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient()
          ..findProxy = (uri) {
            return proxyHostAndPort;
          }
          ..badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
        return client;
      };
    }
  }

  T getData<T>(T value) {
    return value;
  }

  void setHeaders(headerStr) {
    // dio.options.headers = json.decode(headerStr);
  }

  void setHttpTop(headerStr) {
    dio.options.baseUrl = headerStr;
  }

  //get请求
  get(String url, dynamic params, Function successCallBack,
      [Function? errorCallBack,
      bool? isOther,
      bool? isGetBody,
      bool? responseOnly = false,
      bool? onlyResponse = false,
      ResponseType? responseType]) async {
    // params 转 Map<string dynamic>
    if (params is Map) {
      params = Map<String, dynamic>.from(params);
    }
    await _requstHttp(url,
        successCallBack: successCallBack,
        method: 'get',
        params: params,
        errorCallBack: errorCallBack,
        isOther: isOther,
        getBody: isGetBody,
        responseOnly: responseOnly,
        responseType: responseType,
        onlyResponse: onlyResponse);
  }

  //post请求
  post(String url, dynamic params, Function successCallBack,
      [Function? errorCallBack,
      bool? isOther,
      bool? responseOnly = false]) async {
    if (params is Map) {
      params = Map<String, dynamic>.from(params);
    }
    await _requstHttp(url,
        successCallBack: successCallBack,
        method: "post",
        params: params,
        errorCallBack: errorCallBack,
        isOther: isOther,
        responseOnly: responseOnly);
  }

  //put请求
  put(String url, dynamic params, Function successCallBack,
      [Function? errorCallBack,
      bool? isOther]) async {
    if (params is Map) {
      params = Map<String, dynamic>.from(params);
    }
    await _requstHttp(url,
        successCallBack: successCallBack,
        method: "put",
        params: params,
        errorCallBack: errorCallBack,
        isOther: isOther);
  }

  //DELETE请求
  delete(String url, dynamic params, Function successCallBack,
      [Function? errorCallBack]) async {
    if (params is Map) {
      params = Map<String, dynamic>.from(params);
    }
    _requstHttp(url,
        successCallBack: successCallBack,
        method: 'delete',
        params: params,
        errorCallBack: errorCallBack);
  }

  uploadFile(String url, dynamic params, Function successCallBack,
      [Function? errorCallBack]) async {
    await _requstHttp(url,
        successCallBack: successCallBack,
        method: "upload",
        params: params,
        errorCallBack: errorCallBack);
  }

  Future<String?> downLoad(String url, String savePath,
      {Map<String, dynamic>? queryParameters, Function? progressBack}) async {
    try {
      await dio.download(url, savePath, onReceiveProgress: (received, total) {
        if (total != -1 && progressBack != null) {
          LogUtil.d('下载进度$received-------$total');
          progressBack(received, total);
        }
      });
      return savePath;
    } catch (e) {
      LogUtil.e('Error downloading audio: $e');
      return null;
    }
  }

  Future setProxy() async {
    if (hasBeenSet) {
      return;
    }
  }

  bool hasBeenSet = false;

  _requstHttp(
    String url, {
    Function? successCallBack,
    String? method,
    dynamic params,
    Function? errorCallBack,
    bool? isOther,
    bool? getBody = false,
    bool? responseOnly = false,
    bool? onlyResponse = false,
    ResponseType? responseType,
  }) async {
    Response? response;
    try {
      if (method == 'get') {
        if (params != null && params.length > 0) {
          response = await dio.get(
            url,
            queryParameters: params,
            data: getBody == true ? params : null,
          );
        } else {
          response = await dio.get(url,
              options: responseType != null
                  ? Options(responseType: responseType)
                  : null);
        }
      } else if (method == 'post') {
        if (params != null && params.length > 0) {
          response = await dio.post(url, data: params);
        } else {
          response = await dio.post(url);
        }
      } else if (method == 'put') {
        if (params != null && params.length > 0) {
          response = await dio.put(url,
              data: params,
              options: Options(
                contentType: 'application/json', // 明确设置 Content-Type
              ));
        } else {
          response = await dio.put(url);
        }
      } else if (method == 'delete') {
        if (params != null && params.length > 0) {
          response = await dio.delete(url, queryParameters: params);
        } else {
          response = await dio.delete(url);
        }
      } else if (method == 'upload') {
        response = await dio.post(
          url,
          data: params,
          options: Options(
            contentType: 'multipart/form-data', // 明确设置 Content-Type
          ),
        );
      }
    } on DioException catch (error) {
      // 请求错误处理
      Response? errorResponse;
      if (error.response != null) {
        errorResponse = error.response;
      } else {
        errorResponse = Response(
            statusCode: 666, requestOptions: RequestOptions(path: ''));
      }
      // 请求超时
      if (error.type == DioExceptionType.connectionTimeout) {
        errorResponse!.statusCode = ResultCode.CONNECT_TIMEOUT;
      }
      // 一般服务器错误
      else if (error.type == DioExceptionType.receiveTimeout) {
        errorResponse!.statusCode = ResultCode.RECEIVE_TIMEOUT;
      }
      
      final fullUrl = Uri.tryParse(url)?.hasScheme == true
          ? url
          : Uri.parse(dio.options.baseUrl).resolve(url).toString();
      LogUtil.e(
        '异常 Url: $fullUrl' +
            '\n' +
            '请求头: ${dio.options.headers.toString()}' +
            '\n' +
            'method: $method' +
            '\n' +
            '请求参数: ${jsonEncode(params)}',
        error,
      );
      _error(
        errorCallBack,
        _handleHttpError(errorResponse?.statusCode ?? 0),
        code: errorResponse?.statusCode ?? 0,
      );
      return false;
    }
    
    LogUtil.v('Url: $url' +
        '\n' +
        '请求头: ${dio.options.headers.toString()}' +
        '\n' +
        'method: $method' +
        '\n' +
        '请求参数: ' +
        '\n' +
        '返回: $response');
    if (onlyResponse == true) {
      successCallBack?.call(response!.data);
      return true;
    }
    String dataStr = json.encode(response!.data);

    Map<String, dynamic>? dataMap = json.decode(dataStr);
    if (responseOnly == true) {
      successCallBack?.call(dataMap);
      return true;
    }
    if (dataMap == null) {
      _error(
          errorCallBack,
          '错误码：' +
              dataMap!['errorCode'].toString() +
              '，' +
              response.data.toString());
      return false;
    } else if (dataMap['code'] == 200) {
      if (successCallBack != null) {
        if (isOther == true) {
          successCallBack(dataMap);
        } else {
          successCallBack(dataMap['data']);
        }
      }
      return true;
    } else if (dataMap['code'] == 401) {
      _error(errorCallBack, '您的登录已过期', code: dataMap['code']);

      return false;
    } else {
      _error(errorCallBack, dataMap['msg'], code: dataMap['code']);
      return false;
    }
  }

  _error(
    Function? errorCallBack,
    String? error, {
    int? code = 0,
  }) async {
    ///错误码处理 401 退出登录
    if (code == 401) {
      EventBusUtils.getInstance().fire(LoginOutEvent(1));
    }
    if (errorCallBack != null) {
      try {
        errorCallBack(error);
      } catch (e) {
        errorCallBack(error, code);
        LogUtil.e('错误: $e');
      }
    }
  }

  // 处理 Http 错误码
  static String _handleHttpError(int errorCode) {
    String message;
    switch (errorCode) {
      case 400:
        message = '请求语法错误';
        break;
      case 401:
        message = '您的登录已过期';
        break;
      case 403:
        message = '拒绝访问';
        break;
      case 404:
        message = '请求出错,请重试';
        break;
      case 408:
        message = '请求超时,请重试';
        break;
      case 500:
        message = '服务器异常,稍后重试';
        break;
      case 501:
        message = '服务未实现';
        break;
      case 502:
        message = '服务器异常,稍后重试';
        break;
      case 503:
        message = '服务不可用,稍后重试';
        break;
      case 504:
        message = '服务器超时,稍后重试';
        break;
      case 505:
        message = 'HTTP版本不受支持';
        break;
      default:
        message = '貌似网络不太稳定，请稍后再试！';
    }
    return message;
  }
}
