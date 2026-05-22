import '../services/api_client.dart';

class VoicePresignResult {
  const VoicePresignResult({
    required this.uploadUrl,
    required this.s3Key,
    required this.fileId,
    required this.expiresIn,
  });

  final String uploadUrl;
  final String s3Key;
  final String fileId;
  final int expiresIn;

  factory VoicePresignResult.fromJson(Map<String, dynamic> json) {
    return VoicePresignResult(
      uploadUrl: json['uploadUrl'] as String,
      s3Key: json['s3Key'] as String,
      fileId: json['fileId'] as String,
      expiresIn: json['expiresIn'] as int? ?? 300,
    );
  }
}

class TranscriptionJob {
  const TranscriptionJob({
    required this.jobId,
    required this.status,
    this.transcript,
    this.message,
  });

  final String jobId;
  final String status;
  final String? transcript;
  final String? message;

  bool get isComplete => status == 'COMPLETED';
  bool get isFailed => status == 'FAILED';
  bool get isInProgress => status == 'IN_PROGRESS';
}

class GeneratedVoicePlan {
  const GeneratedVoicePlan({
    required this.title,
    required this.emoji,
    required this.vibe,
    this.locationName,
    required this.maxAttendees,
    required this.expiresInMinutes,
    required this.summary,
  });

  final String title;
  final String emoji;
  final String vibe;
  final String? locationName;
  final int maxAttendees;
  final int expiresInMinutes;
  final String summary;

  factory GeneratedVoicePlan.fromJson(Map<String, dynamic> json) {
    final loc = json['location'];
    String? locationName;
    if (loc is Map<String, dynamic>) {
      locationName = loc['name'] as String?;
    } else if (loc is String) {
      locationName = loc;
    }
    return GeneratedVoicePlan(
      title: json['title'] as String? ?? 'New plan',
      emoji: json['emoji'] as String? ?? '✨',
      vibe: json['vibe'] as String? ?? 'other',
      locationName: locationName,
      maxAttendees: json['maxAttendees'] as int? ?? 10,
      expiresInMinutes: json['expiresInMinutes'] as int? ?? 120,
      summary: json['summary'] as String? ?? '',
    );
  }
}

class ApiVoiceRepository {
  ApiVoiceRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<VoicePresignResult> presignUpload(String contentType) async {
    final data = await _client.postJson(
      '/voice/presign',
      body: {'contentType': contentType},
    );
    return VoicePresignResult.fromJson(data);
  }

  Future<TranscriptionJob> startTranscription(
    String s3Key, {
    String languageCode = 'en-US',
  }) async {
    final data = await _client.postJson(
      '/voice/transcribe',
      body: {'s3Key': s3Key, 'languageCode': languageCode},
    );
    return TranscriptionJob(
      jobId: data['jobId'] as String,
      status: data['status'] as String? ?? 'IN_PROGRESS',
      message: data['message'] as String?,
    );
  }

  Future<TranscriptionJob> pollTranscription(String jobId) async {
    final data = await _client.getJson('/voice/transcribe/$jobId');
    return TranscriptionJob(
      jobId: jobId,
      status: data['status'] as String? ?? 'IN_PROGRESS',
      transcript: data['transcript'] as String?,
      message: data['message'] as String?,
    );
  }

  Future<GeneratedVoicePlan> generatePlan(String transcript) async {
    final data = await _client.postJson(
      '/voice/generate-plan',
      body: {'transcript': transcript},
    );
    final plan = data['plan'] as Map<String, dynamic>? ?? {};
    return GeneratedVoicePlan.fromJson(plan);
  }
}
