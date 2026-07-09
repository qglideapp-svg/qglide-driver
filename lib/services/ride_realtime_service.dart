import 'package:supabase/supabase.dart';

import '../config/api_config.dart';

typedef RideRealtimeCallback = void Function(Map<String, dynamic> ride);

/// Subscribes to live `rides` row updates via Supabase Realtime.
class RideRealtimeService {
  SupabaseClient? _client;
  RealtimeChannel? _channel;
  String? _rideId;

  Future<void> subscribe({
    required String rideId,
    required String accessToken,
    required RideRealtimeCallback onRideUpdated,
  }) async {
    if (_rideId == rideId && _channel != null) return;

    await unsubscribe();

    _rideId = rideId;
    _client = SupabaseClient(
      ApiConfig.supabaseUrl,
      ApiConfig.supabaseAnonKey,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    _client!.realtime.setAuth(accessToken);

    _channel = _client!
        .channel('ride-$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rides',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: rideId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            onRideUpdated(Map<String, dynamic>.from(record));
          },
        )
        .subscribe();
  }

  Future<void> unsubscribe() async {
    final channel = _channel;
    final client = _client;
    _channel = null;
    _client = null;
    _rideId = null;

    if (channel != null && client != null) {
      await client.removeChannel(channel);
    }
  }
}
