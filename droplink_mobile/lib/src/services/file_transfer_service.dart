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
  FileTransferService(this.identity)
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 8),
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 75),
          ),
        );

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
    } on DioException catch (error) {
      onChanged(item.copyWith(status: TransferStatus.failed, error: _friendlyDioError(error, device)));
    } catch (error) {
      onChanged(item.copyWith(status: TransferStatus.failed, error: error.toString()));
    }
  }

  String _friendlyDioError(DioException error, NearbyDevice device) {
    if (error.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach ${device.name}. Allow DropLink/Python through Windows Firewall on Private networks.';
    }
    if (error.type == DioExceptionType.receiveTimeout) {
      return '${device.name} did not respond. Check the accept dialog on the PC and try again.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Connection failed to ${device.name}. Make sure both devices are on the same WiFi and Windows Firewall allows port ${device.port}.';
    }
    final status = error.response?.statusCode;
    if (status != null) {
      return 'Transfer failed: receiver returned HTTP $status.';
    }
    return error.message ?? error.toString();
  }
}
