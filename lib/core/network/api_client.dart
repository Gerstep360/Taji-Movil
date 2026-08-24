import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'api_endpoints.dart';
import 'token_store.dart';

class ApiClient {
  ApiClient({TokenStore? tokenStore}) : tokens = tokenStore ?? TokenStore() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: const {'Accept': 'application/json'},
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _authorize, onError: _recoverSession),
    );
  }

  final TokenStore tokens;
  late final Dio dio;
  Future<String?>? _refreshInFlight;

  Future<T?> get<T>(String path, {Map<String, dynamic>? query}) async {
    final response = await dio.get<T>(path, queryParameters: query);
    return response.data;
  }

  Future<T?> post<T>(String path, {Object? data}) async {
    final response = await dio.post<T>(path, data: data);
    return response.data;
  }

  Future<T?> put<T>(String path, {Object? data}) async {
    final response = await dio.put<T>(path, data: data);
    return response.data;
  }

  Future<T?> patch<T>(String path, {Object? data}) async {
    final response = await dio.patch<T>(path, data: data);
    return response.data;
  }

  Future<T?> delete<T>(String path, {Object? data}) async {
    final response = await dio.delete<T>(path, data: data);
    return response.data;
  }

  Future<void> _authorize(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final access = await tokens.access;
    if (access?.isNotEmpty == true) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  Future<void> _recoverSession(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    if (!_canRefresh(error) || request.extra['retried'] == true) {
      handler.next(error);
      return;
    }

    final access = await _refreshOnce();
    if (access == null) {
      handler.next(error);
      return;
    }

    request.headers['Authorization'] = 'Bearer $access';
    request.extra['retried'] = true;
    try {
      handler.resolve(await dio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _canRefresh(DioException error) {
    if (error.response?.statusCode != 401) return false;
    final path = error.requestOptions.path;
    return path != ApiEndpoints.auth.login &&
        path != ApiEndpoints.auth.register &&
        path != ApiEndpoints.auth.refresh &&
        path != ApiEndpoints.auth.forgotPassword &&
        path != ApiEndpoints.auth.resetPassword;
  }

  Future<String?> _refreshOnce() {
    final activeRequest = _refreshInFlight;
    if (activeRequest != null) return activeRequest;

    late final Future<String?> request;
    request = _performRefresh().whenComplete(() {
      if (identical(_refreshInFlight, request)) _refreshInFlight = null;
    });
    _refreshInFlight = request;
    return request;
  }

  Future<String?> _performRefresh() async {
    final refresh = await tokens.refresh;
    if (refresh == null || refresh.isEmpty) return null;

    try {
      final refreshClient = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
        ),
      );
      final response = await refreshClient.post<Map<String, dynamic>>(
        ApiEndpoints.auth.refresh,
        data: {'refresh': refresh, 'client': 'mobile'},
      );
      final tokenJson = response.data?['tokens'] as Map<String, dynamic>?;
      final access = tokenJson?['access'] as String?;
      if (access == null) return null;
      await tokens.updateAccess(
        access,
        rotatedRefresh: tokenJson?['refresh'] as String?,
      );
      return access;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 400 || status == 401 || status == 403) {
        await tokens.clear();
      }
      return null;
    }
  }
}
