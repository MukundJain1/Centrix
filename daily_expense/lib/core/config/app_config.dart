/// Where the API lives. Change it WITHOUT editing code:
///
///   flutter run --dart-define=API_URL=http://192.168.1.5:8000
///
/// Defaults to the Android emulator's address for your PC (10.0.2.2).
/// Real phone over USB:  adb reverse tcp:8000 tcp:8000   then use
///   --dart-define=API_URL=http://localhost:8000
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',

    
    defaultValue: 'http://10.0.2.2:8000',
  );
}
