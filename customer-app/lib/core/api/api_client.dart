import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../auth/session_store.dart';
import '../errors/app_exception.dart';

class ApiClient {
  ApiClient(String baseUrl, this.store)
      : dio=Dio(BaseOptions(baseUrl:baseUrl,connectTimeout:const Duration(seconds:15),
          receiveTimeout:const Duration(seconds:20),headers:{'Accept':'application/json'})),
        _plain=Dio(BaseOptions(baseUrl:baseUrl,connectTimeout:const Duration(seconds:8),receiveTimeout:const Duration(seconds:8))) {
    dio.interceptors.add(InterceptorsWrapper(onRequest:_request,onError:_error));
  }
  final Dio dio;
  final Dio _plain;
  final SessionStore store;
  Future<String>? _refreshOperation;

  Future<void> _request(RequestOptions options,RequestInterceptorHandler handler) async {
    final token=await store.accessToken();
    if(token!=null) options.headers['Authorization']='Bearer $token';
    options.headers['X-Correlation-Id']=const Uuid().v4();
    handler.next(options);
  }

  Future<bool> readiness() async {
    try {
      final response=await _plain.get<void>('/actuator/health/readiness');
      return response.statusCode!=null && response.statusCode!>=200 && response.statusCode!<300;
    } on DioException catch(error) {
      throw _classify(error);
    }
  }

  Future<void> ensureValidSession({bool force=false}) async {
    final refresh=await store.refreshToken();
    if(refresh==null) throw const AppException('Tu sesión expiró. Inicia sesión nuevamente.',code:'AUTH_EXPIRED');
    if(!force && !await store.needsRefresh()) return;
    await _refreshAccessToken(refresh);
  }

  Future<String> _refreshAccessToken(String refreshToken) {
    final current=_refreshOperation;
    if(current!=null) return current;
    final operation=_performRefresh(refreshToken);
    _refreshOperation=operation;
    return operation.whenComplete(() { if(identical(_refreshOperation,operation)) _refreshOperation=null; });
  }

  Future<String> _performRefresh(String refreshToken) async {
    _log('SESSION_REFRESH_STARTED');
    try {
      final response=await _plain.post<Map<String,dynamic>>('/api/v1/auth/refresh-mobile',data:{'refreshToken':refreshToken});
      final token=response.data?['accessToken'] as String?;
      final nextRefresh=response.data?['refreshToken'] as String?;
      if(token==null) throw const AppException('No se pudo renovar la sesión.',code:'SESSION_REFRESH_FAILED');
      await store.save(accessToken:token,refreshToken:nextRefresh);
      _log('SESSION_REFRESH_SUCCEEDED');
      return token;
    } on DioException catch(error) {
      _log('SESSION_REFRESH_FAILED status=${error.response?.statusCode}');
      if(error.response?.statusCode==401 || error.response?.statusCode==403) {
        await store.clear();
        throw const AppException('Tu sesión expiró. Inicia sesión nuevamente.',code:'AUTH_EXPIRED');
      }
      final classified=_classify(error);
      throw AppException(classified.message,code:'SESSION_REFRESH_FAILED');
    }
  }

  Future<void> _error(DioException error,ErrorInterceptorHandler handler) async {
    final request=error.requestOptions;
    final alreadyRetried=request.extra['sessionRefreshRetried']==true;
    if(error.response?.statusCode==401 && !alreadyRetried && !request.path.contains('/auth/refresh')) {
      try {
        final refresh=await store.refreshToken();
        if(refresh==null) throw const AppException('Tu sesión expiró. Inicia sesión nuevamente.',code:'AUTH_EXPIRED');
        final token=await _refreshAccessToken(refresh);
        request.extra['sessionRefreshRetried']=true;
        request.headers['Authorization']='Bearer $token';
        handler.resolve(await dio.fetch<dynamic>(request));
        return;
      } catch(error) {
        handler.reject(DioException(requestOptions:request,error:error));
        return;
      }
    }
    handler.reject(DioException(requestOptions:request,response:error.response,type:error.type,error:_classify(error)));
  }

  AppException _classify(DioException error) {
    final status=error.response?.statusCode;
    final data=error.response?.data;
    final map=data is Map<String,dynamic>?data:null;
    final details=(map?['details'] as Map?)?.map((k,v)=>MapEntry(k.toString(),v.toString()))??<String,String>{};
    if(status==401) return AppException(map?['message']?.toString()??'Tu sesión expiró. Inicia sesión nuevamente.',code:'AUTH_EXPIRED',fieldErrors:details);
    if(status==403) return AppException(map?['message']?.toString()??'No tienes permiso para realizar esta acción.',code:'FORBIDDEN',fieldErrors:details);
    if(status==503) return const AppException('No pudimos conectar con Cerka. Intenta nuevamente.',code:'SERVICE_UNAVAILABLE');
    if(error.type==DioExceptionType.connectionTimeout || error.type==DioExceptionType.receiveTimeout || error.type==DioExceptionType.sendTimeout) {
      return const AppException('La conexión tardó demasiado. Intenta nuevamente.',code:'NETWORK_TIMEOUT');
    }
    if(error.error is SocketException || error.type==DioExceptionType.connectionError) {
      return const AppException('Sin conexión a Internet.',code:'NETWORK_UNAVAILABLE');
    }
    return AppException(map?['message']?.toString()??'No se pudo completar la operación.',
      code:map?['code']?.toString()??map?['error']?.toString()??'HTTP_ERROR',fieldErrors:details);
  }

  AppException exception(Object error) {
    if(error is AppException) return error;
    if(error is DioException && error.error is AppException) return error.error! as AppException;
    if(error is TimeoutException) return const AppException('La conexión tardó demasiado. Intenta nuevamente.',code:'NETWORK_TIMEOUT');
    if(error is SocketException) return const AppException('Sin conexión a Internet.',code:'NETWORK_UNAVAILABLE');
    return const AppException('No se pudo completar la operación.');
  }
  void _log(String value) { if(kDebugMode) debugPrint('[Session] $value'); }
}
