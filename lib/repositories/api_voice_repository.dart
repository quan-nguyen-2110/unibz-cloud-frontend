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
    required this.vibeEmoji,
    this.vibeName,
    required this.title,
    required this.description,
    required this.startAt,
    this.location,
    required this.maxPeople,
  });

  final String vibeEmoji;
  final String? vibeName;
  final String title;
  final String description;
  final DateTime startAt;
  final String? location;
  final int maxPeople;

  factory GeneratedVoicePlan.fromJson(Map<String, dynamic> json) {
    final loc = json['location'];
    final location = loc is String
        ? loc
        : (loc is Map<String, dynamic> ? loc['name'] as String? : null);
    final rawStartAt = json['startAt'] as String?;
    final parsedStartAt = rawStartAt == null ? null : DateTime.tryParse(rawStartAt);
    final fallbackStartAt = DateTime.now().add(const Duration(hours: 2));
    return GeneratedVoicePlan(
      vibeEmoji: json['vibeEmoji'] as String? ?? json['emoji'] as String? ?? '✨',
      vibeName: json['vibeName'] as String?,
      title: json['title'] as String? ??
          json['vibeName'] as String? ??
          'New plan',
      description: json['description'] as String? ?? json['summary'] as String? ?? '',
      startAt: parsedStartAt ?? fallbackStartAt,
      location: location,
      maxPeople: json['maxPeople'] as int? ?? json['maxAttendees'] as int? ?? -1,
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
    final now = DateTime.now();
    final data = await _client.postJson(
      '/voice/generate-plan',
      body: {
        'transcript': transcript,
        'referenceNow': now.toIso8601String(),
        'utcOffsetMinutes': now.timeZoneOffset.inMinutes,
      },
      silent: true,
    );
    final plan = data['plan'] as Map<String, dynamic>? ?? {};
    return GeneratedVoicePlan.fromJson(plan);
  }
}
