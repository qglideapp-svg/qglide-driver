import '../../features/notifications/models/driver_notification.dart';
import '../../features/profile/models/support_ticket.dart';
import '../../services/auth_service.dart';

class SupportChatMessage {
  const SupportChatMessage({
    required this.id,
    required this.message,
    required this.isFromDriver,
    this.createdAt,
    this.isUnread = false,
  });

  final String id;
  final String message;
  final bool isFromDriver;
  final DateTime? createdAt;
  final bool isUnread;

  SupportTicketMessage toTicketMessage() {
    return SupportTicketMessage(
      id: id,
      message: message,
      isFromDriver: isFromDriver,
      createdAt: createdAt,
    );
  }
}

class SupportChatSession {
  const SupportChatSession({
    required this.messages,
    required this.unreadNotificationIds,
    this.activeTicketId,
    this.subject = '',
    this.canReply = true,
  });

  final List<SupportChatMessage> messages;
  final List<String> unreadNotificationIds;
  final String? activeTicketId;
  final String subject;
  final bool canReply;
}

class SupportChatLoader {
  SupportChatLoader._();

  static const _adminNotificationLimit = 50;
  static const _adminMessagePrefix = 'Message from QGlide Admin:';

  static String cleanAdminMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith(_adminMessagePrefix)) {
      return trimmed.substring(_adminMessagePrefix.length).trim();
    }
    return trimmed;
  }

  static SupportChatMessage _fromNotification(DriverNotification notification) {
    return SupportChatMessage(
      id: 'notification-${notification.id}',
      message: cleanAdminMessage(notification.message),
      isFromDriver: false,
      createdAt: notification.createdAt,
      isUnread: !notification.isRead,
    );
  }

  static SupportChatMessage _fromTicketMessage(SupportTicketMessage message) {
    return SupportChatMessage(
      id: 'ticket-${message.id}',
      message: message.isFromDriver
          ? message.message
          : cleanAdminMessage(message.message),
      isFromDriver: message.isFromDriver,
      createdAt: message.createdAt,
    );
  }

  static void _sortMessages(List<SupportChatMessage> messages) {
    messages.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
  }

  static List<SupportChatMessage> _dedupeMessages(
    List<SupportChatMessage> messages,
  ) {
    final seenIds = <String>{};
    final deduped = <SupportChatMessage>[];

    for (final message in messages) {
      if (message.id.isEmpty) {
        deduped.add(message);
        continue;
      }
      if (seenIds.contains(message.id)) continue;
      seenIds.add(message.id);
      deduped.add(message);
    }

    return deduped;
  }

  static Future<SupportTicket?> findActiveTicket() async {
    final ticketsResponse = await AuthService.getMySupportTickets(
      page: 1,
      limit: 10,
    );
    if (ticketsResponse['success'] != true) return null;

    final ticketsResult = AuthService.extractMySupportTickets(ticketsResponse);
    for (final ticket in ticketsResult?.tickets ?? const <SupportTicket>[]) {
      if (ticket.status == SupportTicketStatus.open ||
          ticket.status == SupportTicketStatus.pending ||
          ticket.status == SupportTicketStatus.unknown) {
        return ticket;
      }
    }
    return null;
  }

  static Future<({
    List<SupportChatMessage> adminMessages,
    List<String> unreadIds,
  })> _loadAdminMessages({required bool unreadOnly}) async {
    final notificationsResponse = await AuthService.getAdminSystemNotifications(
      limit: _adminNotificationLimit,
      includeRead: !unreadOnly,
    );

    if (notificationsResponse['success'] != true) {
      return (adminMessages: <SupportChatMessage>[], unreadIds: <String>[]);
    }

    final notifications = unreadOnly
        ? AuthService.extractUnreadAdminNotifications(notificationsResponse)
        : AuthService.extractDriverNotifications(notificationsResponse);

    final adminMessages = notifications
        .where((notification) => notification.message.trim().isNotEmpty)
        .map(_fromNotification)
        .toList();

    final unreadIds = AuthService.extractDriverNotifications(notificationsResponse)
        .where((notification) => !notification.isRead)
        .map((notification) => notification.id)
        .where((id) => id.isNotEmpty)
        .toList();

    _sortMessages(adminMessages);
    return (adminMessages: adminMessages, unreadIds: unreadIds);
  }

  static Future<SupportChatSession> loadActiveSession() async {
    final adminResult = await _loadAdminMessages(unreadOnly: false);

    final activeTicket = await findActiveTicket();
    var canReply = true;
    var subject = '';
    String? activeTicketId;

    final ticketMessages = <SupportChatMessage>[];
    if (activeTicket != null && activeTicket.id.isNotEmpty) {
      activeTicketId = activeTicket.id;
      subject = activeTicket.displaySubject;

      final response = await AuthService.getSupportTicketConversation(
        ticketId: activeTicket.id,
      );
      if (response['success'] == true) {
        final conversation =
            AuthService.extractSupportTicketConversation(response);
        if (conversation != null) {
          canReply = conversation.canReply;
          if (conversation.ticket != null &&
              conversation.ticket!.subject.trim().isNotEmpty) {
            subject = conversation.ticket!.displaySubject;
          }
          ticketMessages.addAll(
            conversation.messages.map(_fromTicketMessage),
          );
        }
      }
    }

    final merged = _dedupeMessages([
      ...adminResult.adminMessages,
      ...ticketMessages,
    ]);
    _sortMessages(merged);

    return SupportChatSession(
      messages: merged,
      unreadNotificationIds: adminResult.unreadIds,
      activeTicketId: activeTicketId,
      subject: subject,
      canReply: canReply,
    );
  }

  /// Unread admin private messages only (`notification_type: system`).
  static Future<SupportChatSession> loadAdminUnreadHistory() async {
    final adminResult = await _loadAdminMessages(unreadOnly: true);
    final activeTicket = await findActiveTicket();

    return SupportChatSession(
      messages: adminResult.adminMessages,
      unreadNotificationIds: adminResult.unreadIds,
      activeTicketId: activeTicket?.id,
      canReply: true,
    );
  }

  static Future<void> markUnreadAsRead(List<String> unreadIds) async {
    if (unreadIds.isEmpty) return;
    await AuthService.markNotificationsAsRead(notificationIds: unreadIds);
  }
}
