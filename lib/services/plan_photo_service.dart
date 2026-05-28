import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/api_json.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'api_loading.dart';

class PlanPhotoService {
  PlanPhotoService({ApiClient? client, http.Client? httpClient})
      : _client = client ?? ApiClient(),
        _http = httpClient ?? http.Client();

  final ApiClient _client;
  final http.Client _http;

  static const maxHostInitialPhotos = 5;

  static String contentTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<List<PlanPhoto>> uploadPlanPhotos(
    String planId,
    List<XFile> files, {
    int? maxCount,
    void Function(int completed, int total)? onProgress,
  }) async {
    return ApiLoading.runSilently(() async {
      final slice = (maxCount != null ? files.take(maxCount) : files).toList();
      final total = slice.length;
      final added = <PlanPhoto>[];
      var completed = 0;
      onProgress?.call(completed, total);
      for (final file in slice) {
        final bytes = await file.readAsBytes();
        final contentType = contentTypeForPath(file.path);
        added.add(await _uploadOne(planId, bytes, contentType));
        completed++;
        onProgress?.call(completed, total);
      }
      return added;
    });
  }

  Future<void> deletePlanPhoto(String planId, String photoId) async {
    await ApiLoading.runSilently(
      () => _client.deleteJson('/plans/$planId/photos/$photoId'),
    );
  }

  Future<PlanPhoto> _uploadOne(
    String planId,
    Uint8List bytes,
    String contentType,
  ) async {
    final presign = await _client.postJson(
      '/plans/$planId/photos/presign',
      body: {'contentType': contentType},
    );

    final uploadUrl = presign['uploadUrl'] as String;
    final photoId = presign['photoId'] as String;
    final s3Key = presign['s3Key'] as String;

    final putRes = await _http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
      throw ApiException(
        putRes.statusCode,
        'Image upload to storage failed',
      );
    }

    final confirmed = await _client.postJson(
      '/plans/$planId/photos',
      body: {
        'photoId': photoId,
        's3Key': s3Key,
        'contentType': contentType,
      },
    );
    return planPhotoFromJson(confirmed['photo'] as Map<String, dynamic>);
  }
}
