import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/hospital_cost_model.dart';

// Design tokens
const _kAccentColor = Color(0xFF3BE2B0);
const _kElevatedColor = Color(0xFF132A1A);
const _kBorderColor = Color(0xFF1E3525);
const _kGoldColor = Color(0xFFFFD580);

/// Premium card that provides intelligent smart insights about recommended hospitals,
/// comparing distance vs. cost to make a tailored recommendation.
class HospitalInsightWidget extends StatelessWidget {
  final HospitalCostSummary summary;

  const HospitalInsightWidget({super.key, required this.summary});

  String _formatRwf(int rwf) {
    if (rwf == 0) return 'Free';
    final formatted = rwf.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$formatted RWF';
  }

  @override
  Widget build(BuildContext context) {
    final hospitals = summary.hospitals;
    if (hospitals.isEmpty) return const SizedBox.shrink();

    // Find the closest hospital
    HospitalCostCard? closest;
    for (final h in hospitals) {
      if (closest == null || h.distanceKm < closest.distanceKm) {
        closest = h;
      }
    }

    // Find the cheapest hospital (lowestCopayRwf and cheapestHospitalName are also on summary)
    HospitalCostCard? cheapest;
    for (final h in hospitals) {
      if (cheapest == null || h.totalEstimatedCopayRwf < cheapest.totalEstimatedCopayRwf) {
        cheapest = h;
      }
    }

    if (closest == null || cheapest == null) return const SizedBox.shrink();

    final bool isSame = closest.hospitalName == cheapest.hospitalName;
    final String recommendationText;
    final IconData icon;

    if (isSame) {
      recommendationText =
          '${closest.hospitalName} is your best option. It is the closest facility (${closest.distanceKm.toStringAsFixed(1)} km away) and also offers the lowest estimated co-payment of ${_formatRwf(closest.totalEstimatedCopayRwf)}.';
      icon = Icons.verified_user_outlined;
    } else {
      recommendationText =
          'For the lowest cost, choose ${cheapest.hospitalName} (${_formatRwf(cheapest.totalEstimatedCopayRwf)}). If you need care quickly, ${closest.hospitalName} is the closest at ${closest.distanceKm.toStringAsFixed(1)} km.';
      icon = Icons.lightbulb_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      decoration: BoxDecoration(
        color: _kElevatedColor.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _kBorderColor,
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Accent Line
              Container(
                width: 4,
                color: _kAccentColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        icon,
                        color: isSame ? _kAccentColor : _kGoldColor,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isSame ? 'RECOMMENDED CHOICE' : 'SMART COMPARISON',
                              style: TextStyle(
                                color: isSame ? _kAccentColor : _kGoldColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              recommendationText,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 250.ms).slideY(
          begin: 0.08,
          end: 0.0,
          curve: Curves.easeOutCubic,
        );
  }
}
