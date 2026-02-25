/// Represents the current status of a V2Ray connection.
///
/// This class holds various metrics and state information about the V2Ray
/// service, including connection duration, speeds, and traffic data.
class V2RayStatus {
  /// The duration of the current connection in 'HH:MM:SS' format.
  final String duration;

  /// The current upload speed in bytes per second.
  final int uploadSpeed;

  /// The current download speed in bytes per second.
  final int downloadSpeed;

  /// The total uploaded data in bytes.
  final int upload;

  /// The total downloaded data in bytes.
  final int download;

  /// The current connection state (e.g., 'CONNECTED', 'DISCONNECTED').
  final String state;

  /// Creates a new V2RayStatus instance with the given parameters.
  ///
  /// [duration] defaults to '00:00:00' if not provided.
  /// [uploadSpeed] defaults to 0.
  /// [downloadSpeed] defaults to 0.
  /// [upload] defaults to 0.
  /// [download] defaults to 0.
  /// [state] defaults to 'DISCONNECTED'.
  V2RayStatus({
    this.duration = '00:00:00',
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
    this.upload = 0,
    this.download = 0,
    this.state = 'DISCONNECTED',
  });
}
