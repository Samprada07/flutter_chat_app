import 'dart:io';

class Config {
  static const bool isPhysicalDevice =
      false; // change to true for physical device
  static const String localIP = '192.168.1.79'; // PC's IP for physical device

  static String get baseUrl {
    if (isPhysicalDevice) {
      return 'http://$localIP:3000/api';
    }
    return Platform.isAndroid
        ? 'http://10.0.2.2:3000/api'
        : 'http://localhost:3000/api';
  }
}
