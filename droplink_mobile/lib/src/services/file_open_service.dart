import 'package:flutter/services.dart';

class FileOpenService {
  static const _channel = MethodChannel('droplink/file_open');

  Future<void> open(String path) async {
    await _channel.invokeMethod<void>('openFile', {'path': path});
  }
}
