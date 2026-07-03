import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/hospital_cost_model.dart';
import 'cost_breakdown_sheet.dart';

// Design tokens (matching the app's deep forest green theme)
const _kAccentColor = Color(0xFF3BE2B0);
const _kElevatedColor = Color(0xFF132A1A);

/// A tappable cost estimate chip shown below AI hospital recommendation bubbles.
///
/// Displays the lowest estimated patient co-payment across recommended hospitals.
/// Tapping opens [CostBreakdownSheet] with a full per-hospital, per-service breakdown.
class CostEstimateWidget extends StatefulWidget {
  final HospitalCostSummary summary;

  const CostEstimateWidget({super.key, required this.summary});

  @override
  State<CostEstimateWidget> createState() => _CostEstimateWidgetState();
}

class _CostEstimateWidgetState extends State<CostEstimateWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  String _formatRwf(int rwf) {
    if (rwf == 0) return 'Free (covered)';
    final formatted = rwf.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$formatted RWF';
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final hasData = summary.hospitals.isNotEmpty;
    final lowestCopay = summary.lowestCopayRwf;
    final cheapestName = summary.cheapestHospitalName;
    final insurance = summary.insurance;

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowOpacity = 0.15 + (_glowController.value * 0.20);
        return GestureDetector(
          onTap: hasData
              ? () => _openBreakdownSheet(context)
              : null,
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            decoration: BoxDecoration(
              color: _kElevatedColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _kAccentColor.withValues(alpha: glowOpacity + 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _kAccentColor.withValues(alpha: glowOpacity),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Icon badge
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kAccentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: _kAccentColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Estimated Cost',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Insurance badge
                      if (insurance != 'None')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _kAccentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            insurance,
                            style: const TextStyle(
                              color: _kAccentColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (hasData) ...[
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'From ',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: _formatRwf(lowestCopay),
                            style: TextStyle(
                              color: lowestCopay == 0
                                  ? _kAccentColor
                                  : const Color(0xFFFFD580),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: ' at $cheapestName',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    Text(
                      'No price data available for this query.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),

            // Tap arrow
            if (hasData)
              Icon(
                Icons.chevron_right_rounded,
                color: _kAccentColor.withValues(alpha: 0.7),
                size: 20,
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(
          begin: 0.1,
          end: 0.0,
          curve: Curves.easeOutCubic,
        );
  }

  void _openBreakdownSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CostBreakdownSheet(summary: widget.summary),
    );
  }
}
