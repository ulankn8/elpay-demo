import 'package:shared_preferences/shared_preferences.dart';

/// Тонкая обёртка над SharedPreferences: всё, что переживает перезапуск.
class AppPrefs {
  AppPrefs(this._p);
  final SharedPreferences _p;

  static Future<AppPrefs> open() async => AppPrefs(await SharedPreferences.getInstance());

  static const _kSession = 'session';
  static const _kLocale = 'locale';
  static const _kTheme = 'theme';
  static const _kPin = 'pin';
  static const _kBio = 'bio';
  static const _kOnboarded = 'onboarded';

  String? get sessionJson => _p.getString(_kSession);
  Future<void> setSession(String? v) async =>
      v == null ? _p.remove(_kSession) : _p.setString(_kSession, v);

  String get locale => _p.getString(_kLocale) ?? 'ru';
  Future<void> setLocale(String v) => _p.setString(_kLocale, v);

  String get themeMode => _p.getString(_kTheme) ?? 'system';
  Future<void> setThemeMode(String v) => _p.setString(_kTheme, v);

  String? get pin => _p.getString(_kPin);
  Future<void> setPin(String? v) async => v == null ? _p.remove(_kPin) : _p.setString(_kPin, v);

  bool get biometrics => _p.getBool(_kBio) ?? true;
  Future<void> setBiometrics(bool v) => _p.setBool(_kBio, v);

  bool get onboarded => _p.getBool(_kOnboarded) ?? false;
  Future<void> setOnboarded(bool v) => _p.setBool(_kOnboarded, v);
}
