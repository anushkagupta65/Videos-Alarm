import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppStore {
  AppStore._();

  FlutterSecureStorage storage = const FlutterSecureStorage();

  static final AppStore _secureStorage = AppStore._();


  factory AppStore(){
    return _secureStorage;
  }

  clear() async {
    await storage.deleteAll();
  }

  Future<void> setToken(String token) async {await storage.write(key: 'token', value: token);}
  Future<String> getToken() async {return await storage.read(key: 'token')??"";}

  Future<void> setMobile(String mobile) async {await storage.write(key: 'mobile', value: mobile);}
  Future<String> getMobile() async {return await storage.read(key: 'mobile')??"";}

  Future<void> setUserId(String userId) async {await storage.write(key: 'userId', value: userId);}
  Future<String> getUserId() async {return await storage.read(key: 'userId')??"";}


}