
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/app/home_screen/controller/home_controller.dart';
import 'package:jippydriver_driver/app/home_screen/widgets/dashboard_metric_card.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Incentive config
// ─────────────────────────────────────────────────────────────────────────────
const int    _kBonusOrderTarget = 20;
//const double _kBonusAmount      = 300.0;

// =============================================================================
//  TodayDashboardSection
// =============================================================================
class TodayDashboardSection extends StatefulWidget {
  final DarkThemeProvider theme;
  final HomeController ctrl;

  const TodayDashboardSection({
    super.key,
    required this.theme,
    required this.ctrl,
  });

  @override
  State<TodayDashboardSection> createState() => _TodayDashboardSectionState();
}

class _TodayDashboardSectionState extends State<TodayDashboardSection> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.ensureTodayDashboardLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Today\'s Summary'.tr,
          style: TextStyle(
            color: widget.theme.getThem() ? AppThemeData.grey50 : AppThemeData.grey900,
            fontSize: 18,
            fontFamily: AppThemeData.semiBold,
          ),
        ),
        const SizedBox(height: 12),

        // ── Metric cards ──────────────────────────────────────────────────
        Obx(() {
          // final api           = widget.ctrl.todayDashboard.value;
          // final totalOrders   = api?.totalOrdersToday ?? _fallbackOrders(widget.ctrl);
          // final totalEarnings =
          //     (api?.totalEarningsToday ?? _fallbackEarnings(widget.ctrl)) +
          //         (totalOrders >= _kBonusOrderTarget ? _kBonusAmount : 0);


          final api = widget.ctrl.todayDashboard.value;

          final totalOrders =
              api?.totalOrdersToday ?? _fallbackOrders(widget.ctrl);

          final baseEarnings =
              api?.totalEarningsToday ?? _fallbackEarnings(widget.ctrl);

          //final totalEarnings =
             // baseEarnings //+ widget.ctrl.creditedBonus.value;


        //  print(
          //  "BASE=$baseEarnings BONUS=${widget.ctrl.creditedBonus.value} TOTAL=$totalEarnings",
          //);
          return Row(
            children: [
              Expanded(
                child: DashboardMetricCard(
                  title: 'Orders Today'.tr,
                  value: totalOrders.toString(),
                  icon: Icons.shopping_bag_outlined,
                  iconBgColor: AppThemeData.primary50,
                  iconColor: AppThemeData.primary500,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DashboardMetricCard(
                  title: 'Earnings Today'.tr,
                  value: Constant.amountShow(
                      amount: baseEarnings.toStringAsFixed(0)),
                  icon: Icons.currency_rupee_rounded,
                  iconBgColor: AppThemeData.success50,
                  iconColor: AppThemeData.success500,
                ),
              ),
            ],
          );
        }),

        const SizedBox(height: 14),

        // ── Incentive card ─────────────────────────────────────────────────
        Obx(() {
          print(
              "UI REBUILD -> BONUS=${widget.ctrl.creditedBonus.value}"
          );
          final api       = widget.ctrl.todayDashboard.value;
          final completed = api?.totalOrdersToday ?? _fallbackOrders(widget.ctrl);
          return _IncentiveCard(
            theme: widget.theme,
            completedOrders: completed,
            ctrl: widget.ctrl,
          );
        }),

        const SizedBox(height: 14),

        // ── Status panel ───────────────────────────────────────────────────
        _StatusPanel(theme: widget.theme, ctrl: widget.ctrl),

        const SizedBox(height: 8),
      ],
    );
  }
}

// =============================================================================
//  Incentive card
// =============================================================================
class _IncentiveCard extends StatefulWidget {
  final DarkThemeProvider theme;
  final int completedOrders;
  final HomeController ctrl;

  const _IncentiveCard({
    required this.theme,
    required this.completedOrders,
    required this.ctrl,
  });

  @override
  State<_IncentiveCard> createState() => _IncentiveCardState();
}

class _IncentiveCardState extends State<_IncentiveCard>
      with SingleTickerProviderStateMixin {
  late AnimationController _wheelCtrl;
  bool   _creditingBonus = false;
  bool   _bonusCredited  = false;
  String _creditStatus   = '';

  String get _todayDateKey =>
      DateTime.now().toLocal().toIso8601String().split('T').first;

  String get _dailyBonusPrefKey =>
      'driver_daily_bonus_claimed_date_${Constant.userModel?.id ?? 'unknown'}';

  double get bonusAmount =>
      widget.ctrl.todayDashboard.value?.driverIncentiveBonus ?? 0.0;

  @override
  void initState() {
    super.initState();
    _wheelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _restoreDailyBonusLock();
    _syncWheel();
  }

  @override
  void didUpdateWidget(_IncentiveCard old) {
    super.didUpdateWidget(old);
    _syncWheel();
  }

  void _syncWheel() {
    final moving = widget.completedOrders > 0 &&
        widget.completedOrders < _kBonusOrderTarget;
    if (moving && !_wheelCtrl.isAnimating) {
      _wheelCtrl.repeat();
    } else if (!moving) {
      _wheelCtrl.stop();
    }
  }

  @override
  void dispose() {
    _wheelCtrl.dispose();
    super.dispose();
  }

  // ── Wallet credit ─────────────────────────────────────────────────────────
  // FIX 1: All setState calls guarded with `mounted` — prevents
  //         "setState called after dispose" crash after async gaps.

  Future<void> _creditBonusToWallet() async {
    print("Credit button clicked");
    final bonusAmount =
        widget.ctrl.todayDashboard.value?.driverIncentiveBonus ?? 0.0;
    print("API Bonus Amount = $bonusAmount");

    if (_creditingBonus || _bonusCredited) return;
    if (!mounted) return;
    setState(() {
      _creditingBonus = true;
      _creditStatus   = 'Calling wallet API...';

    });

    try {
      final res = await http.post(
        Uri.parse('${Constant.baseUrl}driver-sql/delivery-amount/update'),
        headers: {'Content-Type': 'application/json',
            "Accept": "application/json", // ✅ MUST
          },

        // body: jsonEncode({
        //   'user_id': Constant.userModel?.id,
        //   //'amount'   : _kBonusAmount,
        //   'amount' : widget.ctrl.todayDashboard.value?.driverIncentiveBonus ?? 0.0,
        //   'bonus' : 1
        // }),
        body: jsonEncode({
          'user_id': Constant.userModel?.id,
          'amount': bonusAmount,
          'bonus': 1,
        }),
      ).timeout(const Duration(seconds: 10)); // FIX 2: timeout — no infinite hang

      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 409) {
        final alreadyClaimedToday = res.statusCode == 409;
        await _persistDailyBonusLock();
        if (!mounted) return;

        if (!alreadyClaimedToday) {
          print("BONUS BEFORE = ${widget.ctrl.creditedBonus.value}");
          // print("Bonus Amount = $bonusAmount");
          // print("Before = ${widget.ctrl.creditedBonus.value}");
          widget.ctrl.creditedBonus.value += bonusAmount;
         //print("After = ${widget.ctrl.creditedBonus.value}");
          print("BONUS AFTER = ${widget.ctrl.creditedBonus.value}");
          print("AFTER CREDIT -> ${widget.ctrl.creditedBonus.value}");
        }
        setState(() {
          _bonusCredited  = true;
          _creditingBonus = false;
          // _creditStatus = alreadyClaimedToday
          //     ? 'Today bonus already claimed.'.tr
          //     //: '₹${_kBonusAmount.toInt()} credited to your wallet!';
          //     : '₹${bonusAmount.toInt()} credited to your wallet!';
          _creditStatus = alreadyClaimedToday
              ? 'Today bonus already claimed.'.tr
              : '₹${bonusAmount.toInt()} credited to your wallet!';
        });
        return;
      }
      setState(() {
        _creditingBonus = false;
        _creditStatus = 'Unable to credit bonus right now. Please try again.'.tr;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _creditingBonus = false;
        _creditStatus = 'Network issue while crediting bonus. Please retry.'.tr;
      });
    }

  }
  Future<void> _restoreDailyBonusLock() async {
    final prefs = await SharedPreferences.getInstance();

    final claimedDate = prefs.getString(_dailyBonusPrefKey) ?? '';

    print("CLAIMED DATE = $claimedDate");
    print("TODAY DATE = $_todayDateKey");

    if (!mounted || claimedDate != _todayDateKey) {
      return;
    }

    final savedBonus =
        prefs.getDouble('${_dailyBonusPrefKey}_amount') ?? 0.0;

    widget.ctrl.creditedBonus.value = savedBonus;

    print("RESTORED BONUS = $savedBonus");

    setState(() {
      _bonusCredited = true;
      _creditStatus = 'Today bonus already claimed.'.tr;
    });
  }

  Future<void> _persistDailyBonusLock() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _dailyBonusPrefKey,
      _todayDateKey,
    );

    await prefs.setDouble(
      '${_dailyBonusPrefKey}_amount',
      widget.ctrl.todayDashboard.value?.driverIncentiveBonus ?? 0.0,
    );
  }
  // Future<void> _anthropicFallback() async {
  //   if (!mounted) return;
  //   setState(() => _creditStatus = 'Verifying with AI...');
  //
  //   try {
  //     final res = await http.post(
  //       Uri.parse('https://api.anthropic.com/v1/messages'),
  //       headers: {
  //         'Content-Type'     : 'application/json',
  //         'anthropic-version': '2023-06-01',
  //       },
  //       body: jsonEncode({
  //         'model'     : 'claude-sonnet-4-20250514',
  //         'max_tokens': 80,
  //         'messages'  : [
  //           {
  //             'role'   : 'user',
  //             'content': 'Driver ${Constant.userModel?.id} completed '
  //                 '$_kBonusOrderTarget orders. '
  //                 'Confirm ₹${_kBonusAmount.toInt()} bonus credit. '
  //                 'JSON only: {"status":"ok","message":"<one sentence>"}',
  //           }
  //         ],
  //       }),
  //     ).timeout(const Duration(seconds: 10)); // FIX 2: timeout
  //
  //     String msg = '₹${_kBonusAmount.toInt()} bonus credited!';
  //     if (res.statusCode == 200) {
  //       final data = jsonDecode(res.body) as Map<String, dynamic>;
  //       final txt  = (data['content'] as List).first['text'] as String;
  //       try {
  //         final j = jsonDecode(
  //             txt.replaceAll(RegExp(r'```json|```'), '').trim())
  //         as Map<String, dynamic>;
  //         msg = (j['message'] as String?) ?? msg;
  //       } catch (_) {}
  //     }
  //
  //     if (!mounted) return;
  //     setState(() {
  //       _bonusCredited  = true;
  //       _creditingBonus = false;
  //       _creditStatus   = msg;
  //     });
  //   } catch (_) {
  //     if (!mounted) return;
  //     setState(() {
  //       _bonusCredited  = true;
  //       _creditingBonus = false;
  //       _creditStatus   = '₹${_kBonusAmount.toInt()} queued — will sync shortly.';
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final done     = widget.completedOrders >= _kBonusOrderTarget;
    final need     = (_kBonusOrderTarget - widget.completedOrders)
        .clamp(0, _kBonusOrderTarget);
    final progress = (widget.completedOrders / _kBonusOrderTarget)
        .clamp(0.0, 1.0);
    final fillColor = done ? AppThemeData.success500 : AppThemeData.warning500;
    final cardBg    = widget.theme.getThem()
        ? AppThemeData.grey900
        : AppThemeData.grey50;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            // FIX 3: withValues replaces deprecated withOpacity
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ──────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Delivery Bonus'.tr,
                      style: TextStyle(
                        color: widget.theme.getThem()
                            ? AppThemeData.grey50
                            : AppThemeData.grey900,
                        fontSize: 15,
                        fontFamily: AppThemeData.semiBold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Complete $_kBonusOrderTarget orders → earn '
                          //'${Constant.amountShow(amount: _kBonusAmount.toStringAsFixed(0))} bonus'.tr,
                          '${Constant.amountShow(amount: bonusAmount.toStringAsFixed(0))} bonus'.tr,
                      style: TextStyle(
                        color: widget.theme.getThem()
                            ? AppThemeData.grey300
                            : AppThemeData.grey600,
                        fontSize: 12,
                        fontFamily: AppThemeData.regular,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusBadge(done: done, theme: widget.theme),
            ],
          ),

          const SizedBox(height: 14),

          // ── Road scene ──────────────────────────────────────────────────
          _RoadScene(
            completedOrders: widget.completedOrders,
            progress: progress,
            wheelCtrl: _wheelCtrl,
            theme: widget.theme,
            bonusAmount: bonusAmount,
          ),

          const SizedBox(height: 10),

          // ── Step dots ───────────────────────────────────────────────────
          _StepDots(
            total: _kBonusOrderTarget,
            completed: widget.completedOrders,
            theme: widget.theme,
            bonusAmount: bonusAmount,

          ),

          const SizedBox(height: 10),

          // ── Progress bar ────────────────────────────────────────────────
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, val, __) => ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: val,
                minHeight: 9,
                backgroundColor: widget.theme.getThem()
                    ? AppThemeData.grey700
                    : AppThemeData.grey200,
                valueColor: AlwaysStoppedAnimation<Color>(fillColor),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.completedOrders} / $_kBonusOrderTarget ${'orders'.tr}',
                style: TextStyle(
                  color: widget.theme.getThem()
                      ? AppThemeData.grey400
                      : AppThemeData.grey600,
                  fontSize: 12,
                  fontFamily: AppThemeData.regular,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: fillColor,
                  fontSize: 12,
                  fontFamily: AppThemeData.semiBold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: widget.theme.getThem()
                ? AppThemeData.grey700
                : AppThemeData.grey200,
          ),
          const SizedBox(height: 12),

          // ── Footer ──────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonus on completion'.tr,
                    style: TextStyle(
                      color: widget.theme.getThem()
                          ? AppThemeData.grey400
                          : AppThemeData.grey600,
                      fontSize: 12,
                      fontFamily: AppThemeData.regular,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    //'+ ${Constant.amountShow(amount: _kBonusAmount.toStringAsFixed(0))}',
                    '+ ${Constant.amountShow(amount: bonusAmount.toStringAsFixed(0))}',
                    style: const TextStyle(
                      color: AppThemeData.success600,
                      fontSize: 20,
                      fontFamily: AppThemeData.semiBold,
                    ),
                  ),
                ],
              ),
              done
                  ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppThemeData.success50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppThemeData.success500, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Bonus unlocked!'.tr,
                      style: const TextStyle(
                        color: AppThemeData.success600,
                        fontSize: 13,
                        fontFamily: AppThemeData.semiBold,
                      ),
                    ),
                  ],
                ),
              )
                  : Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8EC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Still need'.tr,
                      style: TextStyle(
                        color: widget.theme.getThem()
                            ? AppThemeData.grey400
                            : AppThemeData.grey600,
                        fontSize: 11,
                        fontFamily: AppThemeData.regular,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$need ${'more'.tr}',
                      style: const TextStyle(
                        color: AppThemeData.warning600,
                        fontSize: 15,
                        fontFamily: AppThemeData.semiBold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Wallet credit panel ─────────────────────────────────────────
          if (done) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: widget.theme.getThem()
                  ? AppThemeData.grey700
                  : AppThemeData.grey200,
            ),
            const SizedBox(height: 12),
            _WalletCreditPanel(
              theme: widget.theme,
              credited: _bonusCredited,
              crediting: _creditingBonus,
              statusMsg: _creditStatus,
              onCredit: _creditBonusToWallet,
              bonusAmount: bonusAmount,

            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
//  Road scene
// =============================================================================
class _RoadScene extends StatelessWidget {
  final int completedOrders;
  final double progress;
  final AnimationController wheelCtrl;
  final DarkThemeProvider theme;
  final double bonusAmount;

  const _RoadScene({
    required this.completedOrders,
    required this.progress,
    required this.wheelCtrl,
    required this.theme,
    required this.bonusAmount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final W     = box.maxWidth;
      const left  = 18.0;
      const right = 10.0;
      final track = W - left - right;
      final bikeLeft =
      (left + progress * track - 23.0).clamp(0.0, W - 46.0);

      return SizedBox(
        height: 78,
        child: Stack(
          clipBehavior: Clip.none,
          children: [

            // ── Road strip ────────────────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 22,
                decoration: BoxDecoration(
                  color: theme.getThem()
                      ? AppThemeData.grey800
                      : AppThemeData.grey100,
                  border: Border(
                    top: BorderSide(
                      color: theme.getThem()
                          ? AppThemeData.grey700
                          : AppThemeData.grey300,
                    ),
                  ),
                ),
                child: const _ScrollingDashes(),
              ),
            ),

            // ── Milestone flags 1–9 ───────────────────────────────────────
            ...List.generate(_kBonusOrderTarget, (i) {
              final step    = i + 1;
              final flagX   = left + (step / _kBonusOrderTarget) * track;
              final isDone  = completedOrders >= step;
              final isNext  = completedOrders == step - 1;
              final isBonus = step == _kBonusOrderTarget;
              final poleH   = isBonus ? 30.0 : 20.0;
              final dotSize = isBonus ? 9.0 : 7.0;

              final dotColor = isDone
                  ? AppThemeData.success500
                  : isNext ? AppThemeData.warning400 : Colors.transparent;
              final dotBorder = isDone
                  ? AppThemeData.success500
                  : isNext
                  ? AppThemeData.warning400
                  : theme.getThem()
                  ? AppThemeData.grey600
                  : AppThemeData.grey300;

              return Positioned(
                bottom: 22,
                left: flagX - dotSize / 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isBonus)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppThemeData.success50
                              : const Color(0xFFFFF8EC),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          //'₹${_kBonusAmount.toInt()}',
                          '₹${bonusAmount.toInt()}',
                          style: TextStyle(
                            color: isDone
                                ? AppThemeData.success600
                                : AppThemeData.warning600,
                            fontSize: 7,
                            fontFamily: AppThemeData.semiBold,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 10),
                    Container(
                      width: 1,
                      height: poleH,
                      color: theme.getThem()
                          ? AppThemeData.grey600
                          : AppThemeData.grey300,
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                        border: Border.all(color: dotBorder, width: 1.5),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // ── Bike rider ────────────────────────────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 750),
              curve: Curves.easeOutCubic,
              bottom: 20,
              left: bikeLeft,
              child: _LogoBikeRider(wheelCtrl: wheelCtrl),
            ),
          ],
        ),
      );
    });
  }
}

// =============================================================================
//  Scrolling road dashes
//  FIX 4: OverflowBox breaks the constraint chain so the Row measures its
//          natural width without a layout overflow error.
//          ClipRect above it handles all visual clipping.
// =============================================================================
class _ScrollingDashes extends StatefulWidget {
  const _ScrollingDashes();

  @override
  State<_ScrollingDashes> createState() => _ScrollingDashesState();
}

class _ScrollingDashesState extends State<_ScrollingDashes>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: Transform.translate(
            offset: Offset(-_c.value * 40, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                22,
                    (_) => Container(
                  width: 22,
                  height: 4,
                  margin: const EdgeInsets.only(left: 18, top: 9),
                  decoration: BoxDecoration(
                    color: AppThemeData.warning400.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  Logo bike rider
// =============================================================================
class _LogoBikeRider extends StatelessWidget {
  final AnimationController wheelCtrl;
  const _LogoBikeRider({required this.wheelCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: wheelCtrl,
      builder: (_, __) => SizedBox(
        width: 46,
        height: 52,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              left: 4,
              child: Image.asset(
                'assets/images/driver_logo.png',
                width: 44,
                height: 70,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  Step dots — FIX 5: Expanded + crossAxisAlignment.center kills overflow
// =============================================================================
class _StepDots extends StatelessWidget {
  final int total;
  final int completed;
  final DarkThemeProvider theme;
  final double bonusAmount;


  const _StepDots({
    required this.total,
    required this.completed,
    required this.theme,
    required this.bonusAmount,

  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(total, (i) {
        final step    = i + 1;
        final isDone  = completed >= step;
        final isNext  = completed == step - 1;
        final isBonus = step == total;

        final Color bg = isDone
            ? AppThemeData.success500
            : isNext ? AppThemeData.warning400 : Colors.transparent;
        final Color border = isDone
            ? AppThemeData.success500
            : isNext
            ? AppThemeData.warning400
            : theme.getThem()
            ? AppThemeData.grey600
            : AppThemeData.grey300;
        final Color textColor = (isDone || isNext)
            ? Colors.white
            : theme.getThem() ? AppThemeData.grey400 : AppThemeData.grey500;

        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: border, width: 1.5),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 12)
                      : Text(
                    step.toString(),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 9,
                      fontFamily: AppThemeData.semiBold,
                    ),
                  ),
                ),
              ),
              if (isBonus) ...[
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppThemeData.success50
                          : const Color(0xFFFFF8EC),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      //'₹${_kBonusAmount.toInt()}',
                      //'₹${_kBonusAmount.toInt()}',
                      '₹${bonusAmount.toInt()}',
                      style: TextStyle(
                        color: isDone
                            ? AppThemeData.success600
                            : AppThemeData.warning600,
                        fontSize: 7,
                        fontFamily: AppThemeData.semiBold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

// =============================================================================
//  Status badge
// =============================================================================
class _StatusBadge extends StatelessWidget {
  final bool done;
  final DarkThemeProvider theme;
  const _StatusBadge({required this.done, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: done ? AppThemeData.success50 : const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        done ? 'Completed ✓'.tr : 'In Progress'.tr,
        style: TextStyle(
          color: done ? AppThemeData.success600 : AppThemeData.warning600,
          fontSize: 11,
          fontFamily: AppThemeData.semiBold,
        ),
      ),
    );
  }
}

// =============================================================================
//  Wallet credit panel
// =============================================================================
class _WalletCreditPanel extends StatelessWidget {
  final DarkThemeProvider theme;
  final bool credited;
  final bool crediting;
  final String statusMsg;
  final VoidCallback onCredit;
  final double bonusAmount;



  const _WalletCreditPanel({
    required this.theme,
    required this.credited,
    required this.crediting,
    required this.statusMsg,
    required this.onCredit,    required this.bonusAmount,

  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: credited
            ? AppThemeData.success50
            : theme.getThem()
            ? AppThemeData.grey800
            : AppThemeData.grey100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                credited
                    ? Icons.account_balance_wallet_rounded
                    : Icons.account_balance_wallet_outlined,
                color: credited
                    ? AppThemeData.success500
                    : AppThemeData.primary500,
                size: 18,
              ),
              const SizedBox(width: 8),
              // FIX 6: Expanded prevents text overflowing on small screens
              Expanded(
                child: Text(
                  credited
                      ? 'Bonus Credited to Wallet'.tr
                      : 'Credit Bonus to Wallet'.tr,
                  style: TextStyle(
                    color: theme.getThem()
                        ? AppThemeData.grey100
                        : AppThemeData.grey900,
                    fontSize: 14,
                    fontFamily: AppThemeData.semiBold,
                  ),
                ),
              ),
            ],
          ),
          if (statusMsg.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              statusMsg,
              style: TextStyle(
                color: credited
                    ? AppThemeData.success600
                    : theme.getThem()
                    ? AppThemeData.grey300
                    : AppThemeData.grey600,
                fontSize: 12,
                fontFamily: AppThemeData.regular,
              ),
            ),
          ],
          if (!credited) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: crediting ? null : onCredit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeData.success500,
                  disabledBackgroundColor:
                  AppThemeData.success500.withValues(alpha: 0.45),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                icon: crediting
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : const Icon(Icons.arrow_upward_rounded, size: 16),
                label: Text(
                  crediting
                      ? 'Processing...'.tr
                     // : 'Credit ${Constant.amountShow(amount: _kBonusAmount.toStringAsFixed(0))} to Wallet'
                  // : 'Credit ${Constant.amountShow(amount: bonusAmount.toStringAsFixed(0))} to Wallet'
                      : 'Credit ${Constant.amountShow(amount: bonusAmount.toStringAsFixed(0))} to Wallet'
                      .tr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: AppThemeData.semiBold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
//  Status panel
// =============================================================================
class _StatusPanel extends StatelessWidget {
  final DarkThemeProvider theme;
  final HomeController ctrl;

  const _StatusPanel({required this.theme, required this.ctrl});

  @override
  Widget build(BuildContext context) {

    return Obx(() {
      final api       = ctrl.todayDashboard.value;

      final bonusAmount =
          api?.driverIncentiveBonus ?? 0.0;
      final orders    = api?.totalOrdersToday ?? _fallbackOrders(ctrl);
      final bonusDone = orders >= _kBonusOrderTarget;
      final hasActive = (ctrl.currentOrder.value.id ?? '').isNotEmpty &&
          ctrl.currentOrder.value.driverID == Constant.userModel?.id;

      String title, subtitle;
      Color dotColor, panelColor;

      if (bonusDone) {
        title      = 'Bonus unlocked! Great work.'.tr;
        //subtitle   = '${Constant.amountShow(amount: _kBonusAmount.toStringAsFixed(0))} added to your earnings today.'.tr;
        final bonusAmount =
            api?.driverIncentiveBonus ?? 0.0;

        subtitle =
            //'${Constant.amountShow(amount: bonusAmount.toStringAsFixed(0))} ready to credit to wallet.'.tr;
        // 'Credit ${Constant.amountShow(amount: (widget.ctrl.todayDashboard.value?.driverIncentiveBonus ?? 0.0).toStringAsFixed(0))} to Wallet'
        // dotColor   = AppThemeData.success500;
        subtitle =
            '${Constant.amountShow(amount: bonusAmount.toStringAsFixed(0))} ready to credit to wallet.'.tr;

        dotColor = AppThemeData.success500;
        panelColor = AppThemeData.success50;
      } else if (hasActive) {
        title      = 'Active delivery in progress'.tr;
        subtitle   = 'Map and navigation are available during delivery.'.tr;
        dotColor   = AppThemeData.primary500;
        panelColor = AppThemeData.primary50;
      } else {
        final need = _kBonusOrderTarget - orders;
        title    = 'Waiting for new orders'.tr;
        subtitle = need > 0
            ? '$need more deliveries to unlock your '
            //'${Constant.amountShow(amount: _kBonusAmount.toStringAsFixed(0))} bonus!'.tr
            '${Constant.amountShow(amount: bonusAmount.toStringAsFixed(0))} bonus!'.tr
            : 'New delivery requests appear as a bottom drawer.'.tr;
        dotColor   = AppThemeData.grey400;
        panelColor =
        theme.getThem() ? AppThemeData.grey800 : AppThemeData.grey100;
      }

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(top: 4),
              width: 10,
              height: 10,
              decoration:
              BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        color: theme.getThem()
                            ? AppThemeData.grey100
                            : AppThemeData.grey900,
                        fontSize: 14,
                        fontFamily: AppThemeData.semiBold,
                      )),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                        color: theme.getThem()
                            ? AppThemeData.grey300
                            : AppThemeData.grey600,
                        fontSize: 13,
                        fontFamily: AppThemeData.regular,
                      )),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// =============================================================================
//  Fallback helpers
// =============================================================================
int _fallbackOrders(HomeController ctrl) {
  final inProg = ctrl.driverModel.value.inProgressOrderID?.length ?? 0;
  final req    = ctrl.driverModel.value.orderRequestData?.length ?? 0;
  return inProg + req;
}

double _fallbackEarnings(HomeController ctrl) {
  final tip = double.tryParse(
      ctrl.currentOrder.value.tipAmount?.toString() ?? '0') ??
      0.0;
  return ctrl.totalCalculatedCharge.value + ctrl.surgeFee.value + tip;
}