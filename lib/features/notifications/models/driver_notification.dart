import '../../../config/app_strings.dart';

class DriverNotification {
  const DriverNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.notificationType,
    this.transaction,
    this.ride,
  });

  final String id;
  final String title;
  final String message;
  final DateTime? createdAt;
  final bool isRead;
  final String? notificationType;
  final Map<String, dynamic>? transaction;
  final Map<String, dynamic>? ride;

  String get displayTitle => AppStrings.current().localizedNotificationTitle(
        rawTitle: title,
        notificationType: notificationType,
      );

  String get displayMessage =>
      AppStrings.current().localizedNotificationMessage(
        rawMessage: message,
        notificationType: notificationType,
        transaction: transaction,
        ride: ride,
      );

  String get timeAgo => AppStrings.current().formatTimeAgo(createdAt);

  DriverNotification copyWith({bool? isRead}) {
    return DriverNotification(
      id: id,
      title: title,
      message: message,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      notificationType: notificationType,
      transaction: transaction,
      ride: ride,
    );
  }

  factory DriverNotification.fromJson(Map<String, dynamic> json) {
    final notificationType = _readString(json['notification_type']) ??
        _readString(json['type']);

    return DriverNotification(
      id: _readString(json['id']) ??
          _readString(json['notification_id']) ??
          '',
      title: _readString(json['title']) ??
          _readString(json['subject']) ??
          notificationType ??
          'Notification',
      message: _readString(json['message']) ??
          _readString(json['body']) ??
          _readString(json['content']) ??
          _readString(json['description']) ??
          '',
      createdAt: _parseDateTime(
        json['created_at'] ??
            json['createdAt'] ??
            json['sent_at'] ??
            json['timestamp'],
      ),
      isRead: _parseBool(json['is_read'] ?? json['read'] ?? json['isRead']),
      notificationType: notificationType,
      transaction: json['transaction'] is Map
          ? Map<String, dynamic>.from(json['transaction'] as Map)
          : null,
      ride: json['ride'] is Map
          ? Map<String, dynamic>.from(json['ride'] as Map)
          : null,
    );
  }

  static String? _readString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      final raw = value.toInt();
      final millis = raw > 9999999999 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
    }

    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }
}
