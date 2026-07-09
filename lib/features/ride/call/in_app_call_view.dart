import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../services/auth_service.dart';
import '../../../shared/widgets/profile_avatar_image.dart';
import '../../../shared/widgets/ride_panel_shared.dart';
import 'in_app_call_args.dart';
import 'models/zego_call_session.dart';

class InAppCallView extends StatefulWidget {
  const InAppCallView({super.key, required this.args});

  final InAppCallArgs args;

  @override
  State<InAppCallView> createState() => _InAppCallViewState();
}

class _InAppCallViewState extends State<InAppCallView> {
  var _busy = true;
  var _startInFlight = false;
  var _joined = false;
  var _acceptedIncoming = false;
  var _speakerOn = true;
  var _muted = false;
  var _showOpenSettings = false;
  String? _statusText;
  String? _localUserId;
  String? _roomId;
  String? _publishStreamId;
  DateTime? _tokenExpiresAt;
  String? _callId;
  DateTime? _lastRefreshAt;
  String _driverDisplayName = 'Driver';

  final Set<String> _playingRemoteStreams = {};

  bool get _isIncomingFlow => widget.args.incomingPayload != null;

  @override
  void initState() {
    super.initState();
    _acceptedIncoming = widget.args.incomingPayload == null;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_bootstrap()));
  }

  Future<void> _bootstrap() async {
    final profileResponse = await AuthService.getUserProfile();
    final profile = AuthService.extractUserProfile(profileResponse);
    final name = profile == null
        ? null
        : AuthService.extractProfileFullName(profile);
    if (name != null && name.trim().isNotEmpty && mounted) {
      setState(() => _driverDisplayName = name.trim());
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _statusText = _isIncomingFlow && !_acceptedIncoming
          ? 'Incoming call...'
          : 'Connecting...';
    });

    if (_isIncomingFlow && !_acceptedIncoming) return;
    await _startCall();
  }

  Future<void> _startCall() async {
    if (_startInFlight) return;
    _startInFlight = true;

    if (kIsWeb) {
      setState(() {
        _busy = false;
        _statusText =
            'In-app voice call is not supported on web. Use iOS or Android.';
      });
      _startInFlight = false;
      return;
    }

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      setState(() {
        _busy = false;
        _statusText = 'Microphone permission is required for the call.';
        _showOpenSettings = true;
      });
      _startInFlight = false;
      return;
    }

    try {
      setState(() {
        _busy = true;
        _statusText = 'Connecting...';
        _showOpenSettings = false;
      });

      final session = await _resolveSession();
      _roomId = session.roomId;
      _localUserId = session.userId;
      _publishStreamId = session.userId;
      _tokenExpiresAt = session.tokenExpiresAt;

      try {
        await ZegoExpressEngine.destroyEngine();
      } catch (_) {}

      await ZegoExpressEngine.createEngineWithProfile(
        ZegoEngineProfile(session.appId, ZegoScenario.StandardVoiceCall),
      );

      ZegoExpressEngine.onRoomTokenWillExpire =
          (String roomID, int remainTimeInSecond) {
        if (roomID == _roomId) unawaited(_refreshToken());
      };

      ZegoExpressEngine.onRoomStreamUpdate = (
        String roomID,
        ZegoUpdateType updateType,
        List<ZegoStream> streamList,
        Map<String, dynamic> extendedData,
      ) {
        if (roomID != _roomId) return;
        if (updateType == ZegoUpdateType.Add) {
          for (final stream in streamList) {
            if (stream.streamID == _publishStreamId) continue;
            if (stream.user.userID == _localUserId) continue;
            _playingRemoteStreams.add(stream.streamID);
            ZegoExpressEngine.instance.startPlayingStream(stream.streamID);
          }
        } else if (updateType == ZegoUpdateType.Delete) {
          for (final stream in streamList) {
            _playingRemoteStreams.remove(stream.streamID);
            ZegoExpressEngine.instance.stopPlayingStream(stream.streamID);
          }
        }
      };

      final login = await ZegoExpressEngine.instance.loginRoom(
        _roomId!,
        ZegoUser(_localUserId!, _driverDisplayName),
        config: ZegoRoomConfig(0, true, session.token),
      );

      if (login.errorCode != 0) {
        await _tearDownEngine(skipEndApi: true);
        setState(() {
          _busy = false;
          _statusText = 'Could not join call (code ${login.errorCode}).';
        });
        _startInFlight = false;
        return;
      }

      await ZegoExpressEngine.instance.enableCamera(false);
      await ZegoExpressEngine.instance.setAudioRouteToSpeaker(_speakerOn);
      await ZegoExpressEngine.instance.startPublishingStream(_publishStreamId!);

      if (!mounted) return;
      setState(() {
        _busy = false;
        _joined = true;
        _statusText = null;
      });
      _startInFlight = false;
    } catch (_) {
      await _tearDownEngine(
        reason: 'network_error',
        skipEndApi: _isIncomingFlow && !_acceptedIncoming,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusText = 'Call failed. Please try again.';
      });
      _startInFlight = false;
    }
  }

  Future<RtcZegoSessionData> _resolveSession() async {
    if (_isIncomingFlow) {
      final payload = widget.args.incomingPayload!;
      _callId = payload.callId;
      return RtcZegoSessionData(
        rideId: payload.rideId,
        roomId: payload.roomId,
        token: payload.token,
        appId: payload.appId,
        userId: payload.userId,
      );
    }

    final response = await AuthService.startCall(rideId: widget.args.rideId);
    final data = AuthService.extractCallStartData(response);
    if (data == null) {
      throw Exception(
        AuthService.extractErrorMessage(
          response,
          fallback: 'Could not start call.',
        ),
      );
    }

    _callId = data.callId;
    return data;
  }

  Future<void> _refreshToken() async {
    if (_roomId == null) return;

    final now = DateTime.now().toUtc();
    if (_lastRefreshAt != null &&
        now.difference(_lastRefreshAt!).inSeconds < 5) {
      return;
    }
    _lastRefreshAt = now;

    final response = await AuthService.refreshZegoToken(
      rideId: widget.args.rideId,
      roomId: _roomId!,
    );
    final session = AuthService.extractZegoSessionData(response);
    if (session == null) return;

    _tokenExpiresAt = session.tokenExpiresAt;
    await ZegoExpressEngine.instance.renewToken(_roomId!, session.token);
  }

  Future<void> _maybePreRefreshToken() async {
    if (_tokenExpiresAt == null || _roomId == null) return;
    final remaining =
        _tokenExpiresAt!.difference(DateTime.now().toUtc()).inSeconds;
    if (remaining <= 60) {
      await _refreshToken();
    }
  }

  Future<void> _tearDownEngine({
    String reason = 'ended_by_user',
    bool skipEndApi = false,
  }) async {
    ZegoExpressEngine.onRoomStreamUpdate = null;
    ZegoExpressEngine.onRoomTokenWillExpire = null;

    try {
      await ZegoExpressEngine.instance.stopPublishingStream();
    } catch (_) {}

    for (final streamId in List<String>.from(_playingRemoteStreams)) {
      try {
        await ZegoExpressEngine.instance.stopPlayingStream(streamId);
      } catch (_) {}
    }
    _playingRemoteStreams.clear();

    if (!skipEndApi) {
      final callIdForEnd = _callId ?? widget.args.incomingPayload?.callId;
      if (callIdForEnd != null && callIdForEnd.isNotEmpty) {
        final endResponse = await AuthService.endCall(
          callId: callIdForEnd,
          reason: reason,
        );
        if (AuthService.isNotFoundCallEndError(endResponse)) {
          await AuthService.endCall(rideId: widget.args.rideId, reason: reason);
        }
      } else {
        await AuthService.endCall(rideId: widget.args.rideId, reason: reason);
      }
    }

    try {
      if (_roomId != null) {
        await ZegoExpressEngine.instance.logoutRoom(_roomId);
      }
    } catch (_) {}

    try {
      await ZegoExpressEngine.destroyEngine();
    } catch (_) {}
  }

  Future<void> _onEndCall() async {
    setState(() => _busy = true);
    await _tearDownEngine(reason: 'ended_by_user');
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _toggleMute() async {
    if (!_joined) return;
    final next = !_muted;
    await ZegoExpressEngine.instance.muteMicrophone(next);
    setState(() => _muted = next);
    await _maybePreRefreshToken();
  }

  Future<void> _toggleSpeaker() async {
    if (!_joined) return;
    final next = !_speakerOn;
    await ZegoExpressEngine.instance.setAudioRouteToSpeaker(next);
    setState(() => _speakerOn = next);
  }

  Future<void> _acceptIncoming() async {
    if (!_isIncomingFlow) return;
    setState(() {
      _acceptedIncoming = true;
      _busy = true;
      _statusText = 'Connecting...';
    });
    await _startCall();
  }

  Future<void> _declineIncoming() async {
    final callId = _callId ?? widget.args.incomingPayload?.callId;
    if (callId != null && callId.isNotEmpty) {
      await AuthService.endCall(callId: callId, reason: 'declined');
    } else {
      await AuthService.endCall(rideId: widget.args.rideId, reason: 'declined');
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    final skipEnd =
        _isIncomingFlow && !_acceptedIncoming && !_joined;
    if (!skipEnd) {
      unawaited(_tearDownEngine(skipEndApi: false));
    } else {
      ZegoExpressEngine.onRoomStreamUpdate = null;
      ZegoExpressEngine.onRoomTokenWillExpire = null;
    }
    super.dispose();
  }

  String get _counterpartName {
    final name = widget.args.counterpartName.trim();
    return name.isEmpty ? 'Rider' : name;
  }

  String get _headerText {
    if (_isIncomingFlow && !_acceptedIncoming) return 'Incoming call';
    if (_busy && !_joined) return 'Calling $_counterpartName';
    if (_joined) return 'On call with $_counterpartName';
    return 'Calling $_counterpartName';
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final showIncomingActions = _isIncomingFlow && !_acceptedIncoming;

    return Scaffold(
      backgroundColor: dashboard.scaffold,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: r.maxContentWidth),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(height: r.gap(28)),
                      Text(
                        _headerText,
                        style: TextStyle(
                          fontFamily: AppFonts.satoshi,
                          fontSize: r.sp(16).clamp(15.0, 17.0),
                          fontWeight: FontWeight.w500,
                          color: dashboard.bodyText,
                        ),
                      ),
                      if (_busy)
                        Padding(
                          padding: EdgeInsets.only(top: r.gap(24)),
                          child: CircularProgressIndicator(
                            color: AppColors.loginButton,
                          ),
                        )
                      else if (_statusText != null)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            r.gap(24),
                            r.gap(16),
                            r.gap(24),
                            0,
                          ),
                          child: Text(
                            _statusText!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppFonts.satoshi,
                              fontSize: r.sp(14).clamp(13.0, 15.0),
                              color: dashboard.secondaryText,
                            ),
                          ),
                        ),
                      if (_showOpenSettings)
                        TextButton(
                          onPressed: openAppSettings,
                          child: const Text('Open Settings'),
                        ),
                      const Spacer(),
                      _CallProfileAvatar(
                        riderName: _counterpartName,
                        riderPhotoUrl: widget.args.riderPhotoUrl,
                        riderRating: widget.args.riderRating,
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
                if (showIncomingActions)
                  _IncomingCallActions(
                    onDecline: () => unawaited(_declineIncoming()),
                    onAccept: () => unawaited(_acceptIncoming()),
                  )
                else
                  _CallControlsPanel(
                    speakerOn: _speakerOn,
                    muted: _muted,
                    endEnabled: !_busy || _joined,
                    onSpeakerTap: () => unawaited(_toggleSpeaker()),
                    onMuteTap: () => unawaited(_toggleMute()),
                    onEndTap: () => unawaited(_onEndCall()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallProfileAvatar extends StatelessWidget {
  const _CallProfileAvatar({
    required this.riderName,
    this.riderPhotoUrl,
    this.riderRating,
  });

  final String riderName;
  final String? riderPhotoUrl;
  final double? riderRating;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final avatarSize = r.w(112).clamp(96.0, 128.0);
    final arcSize = avatarSize + r.gap(18);
    final rating = riderRating;

    return SizedBox(
      width: arcSize,
      height: arcSize + r.gap(12),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          SizedBox(
            width: arcSize,
            height: arcSize,
            child: CustomPaint(
              painter: ProfileArcPainter(
                color: AppColors.loginButton,
                strokeWidth: r.w(5).clamp(4.0, 6.0),
              ),
              child: Center(
                child: ClipOval(
                  child: ProfileAvatarImage(
                    size: avatarSize,
                    avatarUrl: riderPhotoUrl,
                    displayName: riderName,
                  ),
                ),
              ),
            ),
          ),
          if (rating != null)
            Positioned(
              bottom: 0,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.gap(10),
                  vertical: r.gap(5),
                ),
                decoration: BoxDecoration(
                  color: dashboard.surface,
                  borderRadius: BorderRadius.circular(r.gap(8)),
                  border: Border.all(color: dashboard.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: dashboard.panelShadow,
                      blurRadius: r.gap(6),
                      offset: Offset(0, r.gap(2)),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: r.iconSm,
                      color: AppColors.loginButton,
                    ),
                    SizedBox(width: r.gap(4)),
                    Text(
                      rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(12).clamp(11.0, 13.0),
                        fontWeight: FontWeight.w600,
                        color: dashboard.bodyText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IncomingCallActions extends StatelessWidget {
  const _IncomingCallActions({
    required this.onDecline,
    required this.onAccept,
  });

  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        r.gap(24),
        r.gap(28),
        r.gap(24),
        r.gap(24),
      ),
      decoration: BoxDecoration(
        color: dashboard.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(r.gap(24)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CallControlButton(
            label: 'Decline',
            icon: Icons.call_end_rounded,
            backgroundColor: AppColors.goOfflineButton,
            iconColor: Colors.white,
            elevated: true,
            onTap: onDecline,
          ),
          _CallControlButton(
            label: 'Accept',
            icon: Icons.call_rounded,
            backgroundColor: AppColors.loginButton,
            iconColor: Colors.white,
            elevated: true,
            onTap: onAccept,
          ),
        ],
      ),
    );
  }
}

class _CallControlsPanel extends StatelessWidget {
  const _CallControlsPanel({
    required this.speakerOn,
    required this.muted,
    required this.endEnabled,
    required this.onSpeakerTap,
    required this.onMuteTap,
    required this.onEndTap,
  });

  final bool speakerOn;
  final bool muted;
  final bool endEnabled;
  final VoidCallback onSpeakerTap;
  final VoidCallback onMuteTap;
  final VoidCallback onEndTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        r.gap(24),
        r.gap(28),
        r.gap(24),
        r.gap(24),
      ),
      decoration: BoxDecoration(
        color: dashboard.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(r.gap(24)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CallControlButton(
            label: 'Speaker',
            icon: Icons.volume_up_rounded,
            active: speakerOn,
            onTap: onSpeakerTap,
          ),
          _CallControlButton(
            label: 'Mute',
            icon: Icons.mic_off_rounded,
            active: muted,
            onTap: onMuteTap,
          ),
          _CallControlButton(
            label: 'End',
            icon: Icons.call_end_rounded,
            backgroundColor: AppColors.goOfflineButton,
            iconColor: Colors.white,
            elevated: true,
            onTap: endEnabled ? onEndTap : null,
          ),
        ],
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  const _CallControlButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.backgroundColor,
    this.iconColor,
    this.elevated = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final buttonSize = r.w(56).clamp(52.0, 60.0);
    final resolvedBackground = backgroundColor ?? dashboard.surface;
    final resolvedIconColor = iconColor ??
        (active ? AppColors.loginButton : dashboard.bodyText);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: resolvedBackground,
          shape: const CircleBorder(),
          elevation: elevated ? 2 : 0,
          shadowColor: dashboard.panelShadow,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: buttonSize,
              height: buttonSize,
              child: Icon(
                icon,
                size: r.iconMd,
                color: resolvedIconColor,
              ),
            ),
          ),
        ),
        SizedBox(height: r.gap(10)),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(12).clamp(11.0, 13.0),
            color: dashboard.secondaryText,
          ),
        ),
      ],
    );
  }
}
