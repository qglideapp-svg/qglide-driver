import 'dart:convert';

class RtcZegoSessionData {
  const RtcZegoSessionData({
    required this.rideId,
    required this.roomId,
    required this.token,
    required this.appId,
    required this.userId,
    this.expiresInSeconds,
    this.tokenExpiresAt,
  });

  final String rideId;
  final String roomId;
  final String token;
  final int appId;
  final String userId;
  final int? expiresInSeconds;
  final DateTime? tokenExpiresAt;
}

class CallStartData extends RtcZegoSessionData {
  const CallStartData({
    required this.callId,
    required super.rideId,
    required super.roomId,
    required super.token,
    required super.appId,
    required super.userId,
    super.expiresInSeconds,
    super.tokenExpiresAt,
  });

  final String callId;
}

class IncomingCallPayload {
  const IncomingCallPayload({
    required this.callId,
    required this.rideId,
    required this.roomId,
    required this.token,
    required this.appId,
    required this.userId,
    required this.callerId,
  });

  final String callId;
  final String rideId;
  final String roomId;
  final String token;
  final int appId;
  final String userId;
  final String callerId;

  static IncomingCallPayload? tryParse(Map<String, dynamic> data) {
    dynamic v(String a, [String? b, String? c]) {
      if (data.containsKey(a) && data[a] != null && '${data[a]}'.isNotEmpty) {
        return data[a];
      }
      if (b != null &&
          data.containsKey(b) &&
          data[b] != null &&
          '${data[b]}'.isNotEmpty) {
        return data[b];
      }
      if (c != null &&
          data.containsKey(c) &&
          data[c] != null &&
          '${data[c]}'.isNotEmpty) {
        return data[c];
      }
      return null;
    }

    Map<String, dynamic>? nested;
    final zegoRaw = data['zego'];
    if (zegoRaw is String && zegoRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(zegoRaw);
        if (decoded is Map<String, dynamic>) nested = decoded;
      } catch (_) {}
    } else if (zegoRaw is Map) {
      nested = Map<String, dynamic>.from(zegoRaw);
    }

    String pick(String snake, [String? camel, String? alt]) {
      final x = v(snake, camel, alt);
      if (x != null) return x.toString();
      if (nested != null) {
        final n = nested;
        final y = n[snake] ??
            (camel != null ? n[camel] : null) ??
            (alt != null ? n[alt] : null);
        if (y != null) return y.toString();
      }
      return '';
    }

    final callId = pick('call_id', 'callId');
    final rideId = pick('ride_id', 'rideId');
    final roomId = pick('room_id', 'roomId');
    var effectiveToken = pick('token');
    if (effectiveToken.isEmpty) {
      effectiveToken = pick('zego_token', 'zegoToken');
    }
    if (effectiveToken.isEmpty) {
      effectiveToken = pick('rtc_token', 'rtcToken');
    }
    final callerId = pick('caller_id', 'callerId');
    final userId = pick('user_id', 'userId');
    final appId = int.tryParse(pick('app_id', 'appId')) ?? 0;

    if (callId.isEmpty ||
        rideId.isEmpty ||
        roomId.isEmpty ||
        effectiveToken.isEmpty ||
        callerId.isEmpty ||
        userId.isEmpty ||
        appId <= 0) {
      return null;
    }

    return IncomingCallPayload(
      callId: callId,
      rideId: rideId,
      roomId: roomId,
      token: effectiveToken,
      appId: appId,
      userId: userId,
      callerId: callerId,
    );
  }
}

RtcZegoSessionData parseRtcZegoSessionData(Map<String, dynamic> response) {
  final data = response['data'];
  if (data is! Map<String, dynamic>) {
    throw const FormatException('Missing call session data');
  }

  final root = _unwrapPayload(data);
  final zego = root['zego'] as Map<String, dynamic>? ?? const {};
  final rideId = root['ride_id']?.toString() ?? '';
  final roomId = root['room_id']?.toString() ?? '';
  final token = zego['token']?.toString() ?? '';
  final appId = zego['app_id'] is int
      ? zego['app_id'] as int
      : int.tryParse(zego['app_id']?.toString() ?? '') ?? 0;
  final userId = zego['user_id']?.toString() ?? '';
  final expiresIn = zego['expires_in'] is int
      ? zego['expires_in'] as int
      : int.tryParse(zego['expires_in']?.toString() ?? '');
  final expiresAtRaw = root['token_expires_at']?.toString();
  final expiresAt =
      expiresAtRaw != null ? DateTime.tryParse(expiresAtRaw)?.toUtc() : null;

  if (rideId.isEmpty ||
      roomId.isEmpty ||
      token.isEmpty ||
      appId <= 0 ||
      userId.isEmpty) {
    throw const FormatException('Missing required ZEGO session fields');
  }

  return RtcZegoSessionData(
    rideId: rideId,
    roomId: roomId,
    token: token,
    appId: appId,
    userId: userId,
    expiresInSeconds: expiresIn,
    tokenExpiresAt: expiresAt,
  );
}

CallStartData parseCallStartData(Map<String, dynamic> response) {
  final data = response['data'];
  if (data is! Map<String, dynamic>) {
    throw const FormatException('Missing call start data');
  }

  final root = _unwrapPayload(data);
  final callId = root['call_id']?.toString() ?? '';
  if (callId.isEmpty) {
    throw const FormatException('Missing call_id');
  }

  final session = parseRtcZegoSessionData(response);
  return CallStartData(
    callId: callId,
    rideId: session.rideId,
    roomId: session.roomId,
    token: session.token,
    appId: session.appId,
    userId: session.userId,
    expiresInSeconds: session.expiresInSeconds,
    tokenExpiresAt: session.tokenExpiresAt,
  );
}

Map<String, dynamic> _unwrapPayload(Map<String, dynamic> payload) {
  var current = payload;
  for (var depth = 0; depth < 3; depth++) {
    if (current['zego'] is Map ||
        current['ride_id'] != null ||
        current['room_id'] != null) {
      return current;
    }
    final nested = current['data'];
    if (nested is Map<String, dynamic>) {
      current = nested;
      continue;
    }
    break;
  }
  return current;
}
