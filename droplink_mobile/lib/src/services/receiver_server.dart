import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

import '../models/transfer_offer.dart';

typedef OfferHandler = Future<bool> Function(TransferOffer offer);
typedef ReceiveProgressHandler = void Function(String transferId, int receivedBytes, {String? savedPath});

class ReceiverServer {
  ReceiverServer({
    required this.onOffer,
    required this.onProgress,
  });

  static const int preferredPort = 45872;

  final OfferHandler onOffer;
  final ReceiveProgressHandler onProgress;
  final _tokens = <String, _PendingToken>{};
  final _random = Random.secure();

  HttpServer? _server;
  int get port => _server?.port ?? preferredPort;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort, shared: true);
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/api/health') {
        await _json(request, {'status': 'ok', 'port': port});
        return;
      }

      if (request.method == 'POST' && request.uri.path == '/api/offers') {
        await _handleOffer(request);
        return;
      }

      final uploadMatch = RegExp(r'^/api/transfers/([^/]+)/upload$').firstMatch(request.uri.path);
      if (request.method == 'POST' && uploadMatch != null) {
        await _handleUpload(request, uploadMatch.group(1)!);
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } catch (error) {
      request.response.statusCode = HttpStatus.internalServerError;
      await _json(request, {'error': error.toString()});
    }
  }

  Future<void> _handleOffer(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final offer = TransferOffer.fromJson(jsonDecode(body) as Map<String, dynamic>);
    final accepted = await onOffer(offer);
    if (!accepted) {
      await _json(request, {'accepted': false, 'message': 'Transfer declined'});
      return;
    }

    final token = _makeToken();
    _tokens[offer.transferId] = _PendingToken(token, DateTime.now().add(const Duration(minutes: 2)));
    await _json(request, {'accepted': true, 'token': token});
  }

  Future<void> _handleUpload(HttpRequest request, String transferId) async {
    final token = _tokens[transferId];
    final auth = request.headers.value(HttpHeaders.authorizationHeader);
    if (token == null || token.expiresAt.isBefore(DateTime.now())) {
      _tokens.remove(transferId);
      request.response.statusCode = HttpStatus.unauthorized;
      await _json(request, {'error': 'Transfer token expired or missing'});
      return;
    }
    if (auth != 'Bearer ${token.value}') {
      request.response.statusCode = HttpStatus.forbidden;
      await _json(request, {'error': 'Invalid transfer token'});
      return;
    }

    final contentType = request.headers.contentType;
    if (contentType == null || !contentType.mimeType.startsWith('multipart/')) {
      request.response.statusCode = HttpStatus.badRequest;
      await _json(request, {'error': 'Expected multipart upload'});
      return;
    }

    final boundary = contentType.parameters['boundary'];
    if (boundary == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await _json(request, {'error': 'Missing multipart boundary'});
      return;
    }

    final dir = await _downloadDirectory();
    var savedPath = '';
    var received = 0;
    final parts = MimeMultipartTransformer(boundary).bind(request);

    await for (final part in parts) {
      final disposition = part.headers['content-disposition'] ?? '';
      final filename = _filenameFromDisposition(disposition) ?? 'droplink-file';
      final destination = await _safeDestination(dir, filename);
      final sink = destination.openWrite();
      try {
        await for (final chunk in part) {
          received += chunk.length;
          sink.add(chunk);
          onProgress(transferId, received);
        }
      } finally {
        await sink.close();
      }
      savedPath = destination.path;
    }

    _tokens.remove(transferId);
    onProgress(transferId, received, savedPath: savedPath);
    await _json(request, {'status': 'saved', 'path': savedPath, 'bytes': received});
  }

  Future<Directory> _downloadDirectory() async {
    if (Platform.isAndroid) {
      for (final path in const [
        '/storage/emulated/0/Download/DropLink',
        '/sdcard/Download/DropLink',
      ]) {
        try {
          final dir = Directory(path);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir;
        } catch (_) {
          // Android can block public Downloads writes on newer versions.
        }
      }
    }

    Directory? base;
    try {
      base = await getDownloadsDirectory();
    } catch (_) {
      base = null;
    }
    base ??= await getExternalStorageDirectory();
    base ??= await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/DropLink');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _safeDestination(Directory dir, String filename) async {
    final clean = filename.split(RegExp(r'[\\/]')).last;
    var file = File('${dir.path}/$clean');
    if (!await file.exists()) return file;

    final dot = clean.lastIndexOf('.');
    final stem = dot > 0 ? clean.substring(0, dot) : clean;
    final suffix = dot > 0 ? clean.substring(dot) : '';
    var counter = 1;
    while (true) {
      file = File('${dir.path}/$stem ($counter)$suffix');
      if (!await file.exists()) return file;
      counter++;
    }
  }

  String? _filenameFromDisposition(String disposition) {
    final match = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
    return match?.group(1);
  }

  String _makeToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  Future<void> _json(HttpRequest request, Map<String, Object?> body) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }
}

class _PendingToken {
  const _PendingToken(this.value, this.expiresAt);

  final String value;
  final DateTime expiresAt;
}
