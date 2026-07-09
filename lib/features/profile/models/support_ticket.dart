import '../../../config/app_strings.dart';

class DriverSupportTicketCategory {
  DriverSupportTicketCategory._();

  static const earnings = 'earnings';
  static const withdrawal = 'withdrawal';
  static const payments = 'payments';
  static const documents = 'documents';
  static const vehicle = 'vehicle';
  static const technical = 'technical';
  static const ratings = 'ratings';
  static const rideIssues = 'ride_issues';
  static const others = 'others';
  static const defaultValue = others;

  static const options = <MapEntry<String, String>>[
    MapEntry(earnings, 'Earnings'),
    MapEntry(withdrawal, 'Withdrawal'),
    MapEntry(payments, 'Payments'),
    MapEntry(documents, 'Documents'),
    MapEntry(vehicle, 'Vehicle'),
    MapEntry(technical, 'Technical'),
    MapEntry(ratings, 'Ratings'),
    MapEntry(rideIssues, 'Ride issues'),
    MapEntry(others, 'Others'),
  ];
}

class SupportTicketAttachmentPayload {
  const SupportTicketAttachmentPayload({
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
  });

  final String fileUrl;
  final String fileName;
  final String fileType;
  final int fileSize;

  Map<String, dynamic> toJson() => {
        'file_url': fileUrl,
        'file_name': fileName,
        'file_type': fileType,
        'file_size': fileSize,
      };
}

class SupportTicketConversation {
  const SupportTicketConversation({
    required this.messages,
    this.ticket,
    this.canReply = true,
  });

  final List<SupportTicketMessage> messages;
  final SupportTicket? ticket;
  final bool canReply;
}

class SupportTicketMessage {
  const SupportTicketMessage({
    required this.id,
    required this.message,
    required this.isFromDriver,
    this.createdAt,
  });

  final String id;
  final String message;
  final bool isFromDriver;
  final DateTime? createdAt;

  factory SupportTicketMessage.fromJson(Map<String, dynamic> json) {
    final senderType = json['sender_type'] ??
        json['sender'] ??
        json['user_type'] ??
        json['author_type'];
    final isFromDriver = _parseBool(json['is_from_driver']) ||
        senderType?.toString().trim().toLowerCase() == 'driver';

    return SupportTicketMessage(
      id: _readString(json['id']) ??
          _readString(json['message_id']) ??
          '',
      message: _readString(json['message']) ??
          _readString(json['body']) ??
          _readString(json['content']) ??
          _readString(json['text']) ??
          '',
      isFromDriver: isFromDriver,
      createdAt: _parseDateTime(
        json['created_at'] ??
            json['sent_at'] ??
            json['createdAt'],
      ),
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
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }
}

enum SupportTicketStatus { open, pending, resolved, unknown }

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String subject;
  final SupportTicketStatus status;
  final DateTime? createdAt;

  String get displayId => AppStrings.current().formatTicketDisplayId(id);

  String get displaySubject {
    final trimmed = subject.trim();
    if (trimmed.isEmpty || trimmed == 'Support ticket') {
      return AppStrings.current().supportTicketSubjectFallback;
    }
    return trimmed;
  }

  String get submittedOnDisplay =>
      AppStrings.current().formatSupportTicketDateTime(createdAt);

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: _readString(json['id']) ??
          _readString(json['ticket_id']) ??
          _readString(json['ticket_number']) ??
          _readString(json['reference']) ??
          '',
      subject: _readString(json['subject']) ??
          _readString(json['title']) ??
          'Support ticket',
      status: _parseStatus(json['status']),
      createdAt: _parseDateTime(
        json['created_at'] ??
            json['submitted_at'] ??
            json['createdAt'] ??
            json['updated_at'],
      ),
    );
  }

  static String? _readString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static SupportTicketStatus _parseStatus(dynamic value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'open' => SupportTicketStatus.open,
      'pending' => SupportTicketStatus.pending,
      'resolved' => SupportTicketStatus.resolved,
      _ => SupportTicketStatus.unknown,
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }
}

class SupportTicketsResult {
  const SupportTicketsResult({
    required this.tickets,
    required this.page,
    required this.limit,
    required this.hasMore,
    required this.totalCount,
  });

  final List<SupportTicket> tickets;
  final int page;
  final int limit;
  final bool hasMore;
  final int totalCount;
}
