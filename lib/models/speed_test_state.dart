enum SpeedTestStep {
  ready,
  loading,
  testing,
  completed,
  error,
}

enum TestPhase {
  loading,
  download,
  upload,
}

class SpeedTestResult {
  final double downloadSpeed;
  final double uploadSpeed;
  final int ping;
  final int jitter;
  final bool isConnectionStable;

  const SpeedTestResult({
    this.downloadSpeed = 0.0,
    this.uploadSpeed = 0.0,
    this.ping = 0,
    this.jitter = 0,
    this.isConnectionStable = true,
  });

  SpeedTestResult copyWith({
    double? downloadSpeed,
    double? uploadSpeed,
    int? ping,
    int? jitter,
    bool? isConnectionStable,
  }) {
    return SpeedTestResult(
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      ping: ping ?? this.ping,
      jitter: jitter ?? this.jitter,
      isConnectionStable: isConnectionStable ?? this.isConnectionStable,
    );
  }

  @override
  String toString() {
    return 'SpeedTestResult(download: ${downloadSpeed.toStringAsFixed(2)} Mbps, '
        'upload: ${uploadSpeed.toStringAsFixed(2)} Mbps, '
        'ping: $ping ms, jitter: $jitter ms)';
  }
}

class SpeedTestState {
  final SpeedTestStep step;
  final TestPhase? currentPhase;
  final SpeedTestResult result;
  final double progress;
  final double currentSpeed;
  final bool isConnectionStable;
  final String? errorMessage;
  final bool hadError;

  const SpeedTestState({
    this.step = SpeedTestStep.ready,
    this.currentPhase,
    this.result = const SpeedTestResult(),
    this.progress = 0.0,
    this.currentSpeed = 0.0,
    this.isConnectionStable = true,
    this.errorMessage,
    this.hadError = false,
  });

  SpeedTestState copyWith({
    SpeedTestStep? step,
    TestPhase? currentPhase,
    SpeedTestResult? result,
    double? progress,
    double? currentSpeed,
    bool? isConnectionStable,
    String? errorMessage,
    bool clearError = false,
    bool? hadError,
  }) {
    return SpeedTestState(
      step: step ?? this.step,
      currentPhase: currentPhase ?? this.currentPhase,
      result: result ?? this.result,
      progress: progress ?? this.progress,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      isConnectionStable: isConnectionStable ?? this.isConnectionStable,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hadError: hadError ?? this.hadError,
    );
  }
}
