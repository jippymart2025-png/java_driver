import 'package:flutter/material.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';

class OrderBottomDrawer extends StatelessWidget {
  final bool visible;
  final Widget child;

  const OrderBottomDrawer({
    super.key,
    required this.visible,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: visible ? 1 : 0,
          child: RepaintBoundary(
            child: Material(
              elevation: 14,
              color: Colors.transparent,
              child: SafeArea(
                top: false,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppThemeData.grey50,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
