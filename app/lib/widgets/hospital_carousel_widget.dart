import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/hospital_cost_model.dart';
import 'cost_breakdown_sheet.dart';

// Design tokens
const _kAccentColor = Color(0xFF3BE2B0);
const _kElevatedColor = Color(0xFF132A1A);
const _kBorderColor = Color(0xFF1E3525);
const _kInsuranceBadgeColor = Color(0xFF56A6C8);

/// A premium horizontal carousel displaying recommended hospitals side-by-side.
///
/// Features clean, visual cards with distances, insurance status, and estimated copays
/// right at the bottom. Tapping any card pops up the comprehensive bottom sheet.
class HospitalCarouselWidget extends StatelessWidget {
  final HospitalCostSummary summary;

  const HospitalCarouselWidget({super.key, required this.summary});

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

    return Container(
      height: 155,
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: hospitals.length,
        itemBuilder: (context, index) {
          final h = hospitals[index];
          final isCheapest = h.hospitalName == summary.cheapestHospitalName;

          return Container(
            width: 250,
            margin: const EdgeInsets.only(right: 12, bottom: 4, top: 4),
            decoration: BoxDecoration(
              color: _kElevatedColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCheapest
                    ? _kAccentColor.withValues(alpha: 0.45)
                    : _kBorderColor,
                width: isCheapest ? 1.4 : 1.0,
              ),
              boxShadow: isCheapest
                  ? [
                      BoxShadow(
                        color: _kAccentColor.withValues(alpha: 0.08),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CostBreakdownSheet(summary: summary),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Header: Name & Type
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  h.hospitalName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCheapest)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _kAccentColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'BEST',
                                    style: TextStyle(
                                      color: _kAccentColor,
                                      fontSize: 7,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            h.hospitalType,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),

                      // Middle: Badges
                      Row(
                        children: [
                          _smallBadge(
                            label: '${h.distanceKm.toStringAsFixed(1)} km',
                            color: Colors.white.withValues(alpha: 0.5),
                            icon: Icons.location_on_outlined,
                          ),
                          const SizedBox(width: 8),
                          _smallBadge(
                            label: h.isInNetwork ? 'In-Network' : 'Out-of-Network',
                            color: h.isInNetwork
                                ? _kInsuranceBadgeColor
                                : const Color(0xFFE56B6B),
                            icon: Icons.shield_outlined,
                          ),
                        ],
                      ),

                      // Bottom: Estimated Copay Price
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ESTIMATED COPAY',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _formatRwf(h.totalEstimatedCopayRwf),
                                style: TextStyle(
                                  color: h.totalEstimatedCopayRwf == 0
                                      ? _kAccentColor
                                      : const Color(0xFFFFD580),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: _kAccentColor.withValues(alpha: 0.6),
                            size: 12,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 350.ms, delay: (index * 80).ms).slideX(
                begin: 0.1,
                end: 0.0,
                curve: Curves.easeOutCubic,
              );
        },
      ),
    );
  }

  Widget _smallBadge({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 9),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
