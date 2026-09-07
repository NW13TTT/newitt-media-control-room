abstract interface class AiService {
  bool get isConfigured;

  Future<AiResponse> submit(String request);
}

class AiResponse {
  const AiResponse.unavailable()
    : message = 'AI is not configured for this Control Room.',
      isUnavailable = true;

  const AiResponse.error(this.message) : isUnavailable = false;

  final String message;
  final bool isUnavailable;
}

class UnconfiguredAiService implements AiService {
  const UnconfiguredAiService();

  @override
  bool get isConfigured => false;

  @override
  Future<AiResponse> submit(String request) async =>
      const AiResponse.unavailable();
}
