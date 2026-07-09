import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/dashboard_theme.dart';
import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/app_strings_scope.dart';
import 'models/support_ticket.dart';
import 'support_ticket_detail_view.dart';

class SubmittedTicketsView extends StatefulWidget {
  const SubmittedTicketsView({super.key});

  @override
  State<SubmittedTicketsView> createState() => _SubmittedTicketsViewState();
}

class _SubmittedTicketsViewState extends State<SubmittedTicketsView> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final _tickets = <SupportTicket>[];

  var _isInitialLoading = true;
  var _isLoadingMore = false;
  var _hasMore = true;
  var _currentPage = 0;
  String? _errorMessage;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadTickets(reset: true));
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isInitialLoading || _isLoadingMore) {
      return;
    }
    if (!_hasMore) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      unawaited(_loadTickets());
    }
  }

  Future<void> _loadTickets({bool reset = false}) async {
    if (reset) {
      if (_isLoadingMore) return;
      setState(() {
        _isInitialLoading = true;
        _errorMessage = null;
        _hasMore = true;
        _currentPage = 0;
      });
    } else {
      if (_isInitialLoading || _isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    final nextPage = reset ? 1 : _currentPage + 1;
    final response = await AuthService.getMySupportTickets(
      page: nextPage,
      limit: _pageSize,
      status: _selectedStatus,
    );

    if (!mounted) return;

    if (response['success'] != true) {
      setState(() {
        _isInitialLoading = false;
        _isLoadingMore = false;
        _errorMessage = AuthService.extractErrorMessage(
          response,
          fallback: AppStrings.current().errLoadTickets,
        );
      });
      return;
    }

    final result = AuthService.extractMySupportTickets(response);
    if (result == null) {
      setState(() {
        _isInitialLoading = false;
        _isLoadingMore = false;
        _errorMessage = AppStrings.current().errReadTickets;
      });
      return;
    }

    setState(() {
      _isInitialLoading = false;
      _isLoadingMore = false;
      _errorMessage = null;
      _currentPage = result.page;
      _hasMore = result.hasMore;
      if (reset) {
        _tickets
          ..clear()
          ..addAll(result.tickets);
      } else {
        final existingIds = _tickets.map((ticket) => ticket.id).toSet();
        for (final ticket in result.tickets) {
          if (!existingIds.contains(ticket.id)) {
            _tickets.add(ticket);
          }
        }
      }
    });
  }

  Future<void> _onStatusSelected(String? status) async {
    if (_selectedStatus == status) return;
    setState(() => _selectedStatus = status);
    await _loadTickets(reset: true);
  }

  Future<void> _openAddTicket() async {
    final created = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.addSupportTicket,
    );

    if (!mounted || created != true) return;
    await _loadTickets(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final s = AppStringsScope.of(context);
    final horizontalPadding = r.gap(r.isTablet ? 32 : 20);

    return Scaffold(
      backgroundColor: dashboard.screenBackground,
      appBar: AppBar(
        backgroundColor: dashboard.screenBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: dashboard.primaryText,
            size: r.sp(18).clamp(16.0, 20.0),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  r.gap(12),
                ),
                child: Text(
                  s.submittedTickets,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(27).clamp(24.0, 30.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                    height: 1.15,
                  ),
                ),
              ),
              _StatusFilterBar(
                r: r,
                selectedStatus: _selectedStatus,
                onSelected: (status) => unawaited(_onStatusSelected(status)),
              ),
              SizedBox(height: r.gap(12)),
              Expanded(
                child: _buildBody(r, dashboard, s, horizontalPadding),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => unawaited(_openAddTicket()),
        backgroundColor: AppColors.loginButton,
        elevation: 4,
        shape: const CircleBorder(),
        child: Icon(
          Icons.add,
          color: Colors.white,
          size: r.sp(28).clamp(24.0, 32.0),
        ),
      ),
    );
  }

  Widget _buildBody(
    AppResponsive r,
    DashboardTheme dashboard,
    AppStrings s,
    double horizontalPadding,
  ) {
    if (_isInitialLoading) {
      return const _LazyTicketsList();
    }

    if (_errorMessage != null && _tickets.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(16).clamp(15.0, 18.0),
                color: dashboard.bodyText,
              ),
            ),
            SizedBox(height: r.gap(16)),
            TextButton(
              onPressed: () => unawaited(_loadTickets(reset: true)),
              child: Text(s.tryAgain),
            ),
          ],
        ),
      );
    }

    if (_tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Text(
            s.noSupportTicketsYet,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(16).clamp(15.0, 18.0),
              color: dashboard.mutedText,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.loginButton,
      onRefresh: () => _loadTickets(reset: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          0,
          horizontalPadding,
          r.gap(88),
        ),
        itemCount: _tickets.length + (_isLoadingMore || _hasMore ? 1 : 0),
        separatorBuilder: (context, index) {
          if (index >= _tickets.length - 1) {
            return const SizedBox.shrink();
          }
          return SizedBox(height: r.gap(10));
        },
        itemBuilder: (context, index) {
          if (index >= _tickets.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: r.gap(16)),
              child: Center(
                child: _isLoadingMore
                    ? CircularProgressIndicator(color: AppColors.loginButton)
                    : const SizedBox.shrink(),
              ),
            );
          }

          final ticket = _tickets[index];
          return _TicketListTile(
            r: r,
            ticket: ticket,
            onTap: () {
              Navigator.of(context).pushNamed(
                AppRoutes.supportTicketDetail,
                arguments: SupportTicketDetailArgs(
                  ticketId: ticket.id,
                  subject: ticket.displaySubject,
                  displayId: ticket.displayId,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({
    required this.r,
    required this.selectedStatus,
    required this.onSelected,
  });

  final AppResponsive r;
  final String? selectedStatus;
  final ValueChanged<String?> onSelected;

  static const _filterStatuses = <String?>[null, 'open', 'pending', 'resolved'];

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);
    final s = AppStringsScope.of(context);

    return SizedBox(
      height: r.gap(38).clamp(34.0, 42.0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: r.gap(r.isTablet ? 32 : 20)),
        itemCount: _filterStatuses.length,
        separatorBuilder: (_, _) => SizedBox(width: r.gap(8)),
        itemBuilder: (context, index) {
          final status = _filterStatuses[index];
          final label = s.ticketFilterLabel(status) ?? status ?? s.filterAll;
          final isSelected = selectedStatus == status;

          return FilterChip(
            label: Text(label),
            selected: isSelected,
            showCheckmark: false,
            labelStyle: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(14).clamp(13.0, 15.0),
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : dashboard.secondaryText,
            ),
            backgroundColor: dashboard.inputFill,
            selectedColor: AppColors.loginButton,
            side: BorderSide.none,
            onSelected: (_) => onSelected(status),
          );
        },
      ),
    );
  }
}

class _TicketListTile extends StatelessWidget {
  const _TicketListTile({
    required this.r,
    required this.ticket,
    required this.onTap,
  });

  final AppResponsive r;
  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);
    final s = AppStringsScope.of(context);
    final statusStyle = _statusStyle(ticket.status, s);

    return Material(
      color: dashboard.inputFill,
      borderRadius: BorderRadius.circular(r.gap(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.gap(12)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.gap(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: r.w(44).clamp(40.0, 48.0),
                    height: r.w(44).clamp(40.0, 48.0),
                    decoration: BoxDecoration(
                      color: AppColors.loginButton.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(r.gap(10)),
                    ),
                    child: Icon(
                      Icons.confirmation_number_outlined,
                      size: r.iconSm,
                      color: AppColors.loginButton,
                    ),
                  ),
                  SizedBox(width: r.gap(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.displayId,
                          style: TextStyle(
                            fontFamily: AppFonts.satoshi,
                            fontSize: r.sp(13).clamp(12.0, 14.0),
                            fontWeight: FontWeight.w600,
                            color: dashboard.secondaryText,
                          ),
                        ),
                        SizedBox(height: r.gap(4)),
                        Text(
                          ticket.displaySubject,
                          style: TextStyle(
                            fontFamily: AppFonts.satoshi,
                            fontSize: r.sp(16).clamp(15.0, 18.0),
                            fontWeight: FontWeight.w700,
                            color: dashboard.primaryText,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.gap(10),
                      vertical: r.gap(4),
                    ),
                    decoration: BoxDecoration(
                      color: statusStyle.backgroundColor,
                      borderRadius: BorderRadius.circular(r.gap(6)),
                    ),
                    child: Text(
                      statusStyle.label,
                      style: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(12).clamp(11.0, 13.0),
                        fontWeight: FontWeight.w600,
                        color: statusStyle.textColor,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.gap(10)),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  ticket.submittedOnDisplay,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(13).clamp(12.0, 14.0),
                    color: dashboard.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _TicketStatusStyle _statusStyle(SupportTicketStatus status, AppStrings s) {
    return switch (status) {
      SupportTicketStatus.open => _TicketStatusStyle(
          label: s.filterOpen,
          backgroundColor: const Color(0x1FE3AA00),
          textColor: const Color(0xFFB88600),
        ),
      SupportTicketStatus.pending => _TicketStatusStyle(
          label: s.filterPending,
          backgroundColor: const Color(0x1F2563EB),
          textColor: const Color(0xFF2563EB),
        ),
      SupportTicketStatus.resolved => _TicketStatusStyle(
          label: s.filterResolved,
          backgroundColor: const Color(0x1F22C55E),
          textColor: const Color(0xFF16A34A),
        ),
      SupportTicketStatus.unknown => _TicketStatusStyle(
          label: s.ticketStatusUnknown,
          backgroundColor: const Color(0x1F6B7280),
          textColor: const Color(0xFF6B7280),
        ),
    };
  }
}

class _TicketStatusStyle {
  const _TicketStatusStyle({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
}

class _LazyTicketsList extends StatefulWidget {
  const _LazyTicketsList();

  @override
  State<_LazyTicketsList> createState() => _LazyTicketsListState();
}

class _LazyTicketsListState extends State<_LazyTicketsList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final horizontalPadding = r.gap(r.isTablet ? 32 : 20);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.35 + (_pulseController.value * 0.35);

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            r.gap(88),
          ),
          itemCount: 5,
          separatorBuilder: (_, _) => SizedBox(height: r.gap(10)),
          itemBuilder: (context, index) {
            return Container(
              padding: EdgeInsets.all(r.gap(14)),
              decoration: BoxDecoration(
                color: dashboard.inputFill,
                borderRadius: BorderRadius.circular(r.gap(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _LazyBlock(
                        opacity: opacity,
                        color: dashboard.secondaryText,
                        height: r.w(44).clamp(40.0, 48.0),
                        width: r.w(44).clamp(40.0, 48.0),
                        borderRadius: r.gap(10),
                      ),
                      SizedBox(width: r.gap(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LazyBlock(
                              opacity: opacity,
                              color: dashboard.secondaryText,
                              height: r.sp(13).clamp(12.0, 14.0),
                              width: r.w(72).clamp(60.0, 84.0),
                            ),
                            SizedBox(height: r.gap(8)),
                            _LazyBlock(
                              opacity: opacity,
                              color: dashboard.primaryText,
                              height: r.sp(16).clamp(15.0, 18.0),
                              width: double.infinity,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.gap(12)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _LazyBlock(
                      opacity: opacity,
                      color: dashboard.secondaryText,
                      height: r.sp(13).clamp(12.0, 14.0),
                      width: r.w(140).clamp(120.0, 160.0),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _LazyBlock extends StatelessWidget {
  const _LazyBlock({
    required this.opacity,
    required this.color,
    required this.height,
    required this.width,
    this.borderRadius = 6,
  });

  final double opacity;
  final Color color;
  final double height;
  final double width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
