import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import '../models/nearby_device.dart';
import '../models/transfer_item.dart';
import 'device_identity.dart';

typedef TransferChanged = void Function(TransferItem item);

class FileTransferService {
  FileTransferService(this.identity) : _dio = Dio();

  final DeviceIdentity identity;
  final Dio _dio;

  Future<void> pickAndSend(NearbyDevice device, TransferChanged onChanged) async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    final path = result?.files.single.path;
    if (path == null) return;
    await sendFile(device, File(path), onChanged);
  }

  Future<void> sendFile(NearbyDevice device, File file, TransferChanged onChanged) async {
    final transferId = const Uuid().v4();
    final length = await file.length();
    final filename = file.uri.pathSegments.last;
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

    var item = TransferItem(
      id: transferId,
      filename: filename,
      totalBytes: length,
      sentBytes: 0,
      speedBytesPerSecond: 0,
      status: TransferStatus.offering,
    );
    onChanged(item);

    try {
      final offer = await _dio.post<Map<String, dynamic>>(
        '${device.baseUrl}/api/offers',
        data: {
          'transfer_id': transferId,
          'sender_id': identity.id,
          'sender_name': identity.name,
          'filename': filename,
          'size': length,
          'mime_type': mimeType,
        },
        options: Options(sendTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 30)),
      );

      final data = offer.data ?? {};
      if (data['accepted'] != true) {
        throw Exception(data['message'] ?? 'Transfer declined');
      }

      final started = DateTime.now();
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      });

      await _dio.post(
        '${device.baseUrl}/api/transfers/$transferId/upload',
        data: form,
        options: Options(headers: {'Authorization': 'Bearer ${data['token']}'}),
        onSendProgress: (sent, total) {
          final elapsed = DateTime.now().difference(started).inMilliseconds / 1000;
          final speed = elapsed <= 0 ? 0.0 : sent / elapsed;
          item = item.copyWith(
            sentBytes: sent,
            speedBytesPerSecond: speed,
            status: TransferStatus.transferring,
          );
          onChanged(item);
        },
      );

      onChanged(item.copyWith(sentBytes: length, status: TransferStatus.completed));
    } catch (error) {
      onChanged(item.copyWith(status: TransferStatus.failed, error: error.toString()));
    }
  }
}
