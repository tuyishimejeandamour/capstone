import 'package:flutter/material.dart';
import '../services/hospital_cost_model.dart';

// Design tokens
const _kBgColor = Color(0xFF081510);
const _kSurfaceColor = Color(0xFF0D1F14);
const _kElevatedColor = Color(0xFF132A1A);
const _kAccentColor = Color(0xFF3BE2B0);
const _kInsuranceBadgeColor = Color(0xFF56A6C8); // calm blue for insurance
const _kBorderColor = Color(0xFF1E3525);

/// Full-screen draggable bottom sheet showing per-hospital, per-service
/// cost breakdowns filtered to the detected health condition.
class CostBreakdownSheet extends StatelessWidget {
  final HospitalCostSummary summary;

  const CostBreakdownSheet({super.key, required this.summary});

  String _formatRwf(int rwf) {
    if (rwf <= 0) return 'Free';
    final formatted = rwf.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$formatted RWF';
  }

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    final insurance = summary.insurance;
    final condition = summary.detectedCondition;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _kSurfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _kAccentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: _kAccentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estimated Cost Breakdown',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'Based on published hospital rates',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Close button
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white38,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Insurance + condition badges
                    Wrap(
                      spacing: 8,
                      children: [
                        _Badge(
                          label: insurance == 'None' ? 'No Insurance' : insurance,
                          color: insurance == 'None'
                              ? const Color(0xFFFFD580)
                              : _kInsuranceBadgeColor,
                          icon: Icons.shield_outlined,
                        ),
                        if (condition != null)
                          _Badge(
                            label: condition,
                            color: _kAccentColor,
                            icon: Icons.medical_services_outlined,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Divider(color: _kBorderColor, height: 1),
                  ],
                ),
              ),

              // Scrollable hospital cards
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: summary.hospitals.length,
                  itemBuilder: (context, index) {
                    final card = summary.hospitals[index];
                    final isCheapest =
                        card.hospitalName == summary.cheapestHospitalName;
                    return _HospitalCostCard(
                      card: card,
                      insurance: insurance,
                      isCheapest: isCheapest,
                      formatRwf: _formatRwf,
                    );
                  },
                ),
              ),

              // Disclaimer footer
              Container(
                width: double.infinity,
                color: _kBgColor,
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  12 + MediaQuery.of(context).viewPadding.bottom,
                ),
                child: const Text(
                  'Prices are based on published rates and may vary. Always confirm costs directly with the facility before your visit.',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 10,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Individual Hospital Cost Card ──────────────────────────────────────────

class _HospitalCostCard extends StatefulWidget {
  final HospitalCostCard card;
  final String insurance;
  final bool isCheapest;
  final String Function(int) formatRwf;

  const _HospitalCostCard({
    required this.card,
    required this.insurance,
    required this.isCheapest,
    required this.formatRwf,
  });

  @override
  State<_HospitalCostCard> createState() => _HospitalCostCardState();
}

class _HospitalCostCardState extends State<_HospitalCostCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Auto-expand the cheapest card
    _expanded = widget.isCheapest;
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final isCheapest = widget.isCheapest;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kElevatedColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCheapest
              ? _kAccentColor.withValues(alpha: 0.35)
              : _kBorderColor,
          width: isCheapest ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        children: [
          // Card header (always visible)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Distance indicator
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCheapest
                          ? _kAccentColor.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          card.distanceKm.toStringAsFixed(1),
                          style: TextStyle(
                            color: isCheapest ? _kAccentColor : Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'km',
                          style: TextStyle(
                            color: isCheapest
                                ? _kAccentColor.withValues(alpha: 0.7)
                                : Colors.white30,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name + type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                card.hospitalName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCheapest) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _kAccentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'BEST VALUE',
                                  style: TextStyle(
                                    color: _kAccentColor,
                                    fontSize: 7,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.hospitalType,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Total cost + expand chevron
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.formatRwf(card.totalEstimatedCopayRwf),
                        style: TextStyle(
                          color: card.totalEstimatedCopayRwf == 0
                              ? _kAccentColor
                              : const Color(0xFFFFD580),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'your cost',
                        style: TextStyle(color: Colors.white30, fontSize: 9),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white38,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable service rows
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 13, color: _kAccentColor),
                      const SizedBox(width: 6),
                      Text(
                        card.phone,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Icon(Icons.mail_outline_rounded, size: 13, color: _kAccentColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          card.email,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: _kBorderColor.withValues(alpha: 0.5),
                  indent: 16,
                  endIndent: 16,
                ),
                _ServiceBreakdownList(
                  services: card.services,
                  formatRwf: widget.formatRwf,
                ),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── Service rows breakdown ──────────────────────────────────────────────────

class _ServiceBreakdownList extends StatelessWidget {
  final List<ServiceCostEntry> services;
  final String Function(int) formatRwf;

  const _ServiceBreakdownList({
    required this.services,
    required this.formatRwf,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _kBorderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Column headers
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                const Expanded(
                  flex: 5,
                  child: Text(
                    'SERVICE',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                _headerCell('BASE'),
                _headerCell('INSURER'),
                _headerCell('YOU PAY'),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: _kBorderColor.withValues(alpha: 0.5),
            indent: 16,
            endIndent: 16,
          ),

          ...services.map((s) => _ServiceRow(entry: s, formatRwf: formatRwf)),

          // Total row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                const Expanded(
                  flex: 5,
                  child: Text(
                    'TOTAL ESTIMATED',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    formatRwf(
                      services.fold(0, (sum, s) => sum + s.basePriceRwf),
                    ),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    formatRwf(
                      services.fold(0, (sum, s) => sum + s.insurancePaysRwf),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF3BE2B0),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    formatRwf(
                      services.fold(0, (sum, s) => sum + s.patientCopayRwf),
                    ),
                    style: const TextStyle(
                      color: Color(0xFFFFD580),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label) {
    return Expanded(
      flex: 3,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white24,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final ServiceCostEntry entry;
  final String Function(int) formatRwf;

  const _ServiceRow({required this.entry, required this.formatRwf});

  @override
  Widget build(BuildContext context) {
    final excluded = !entry.isCovered && entry.insurancePaysRwf == 0 &&
        entry.patientCopayRwf == entry.basePriceRwf;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service name
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.serviceName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (entry.coverageNote != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          entry.coverageNote!,
                          style: TextStyle(
                            color: excluded
                                ? const Color(0xFFFFD580).withValues(alpha: 0.8)
                                : _kAccentColor.withValues(alpha: 0.6),
                            fontSize: 9,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Base price (struck out if fully covered, dimmed if excluded)
              Expanded(
                flex: 3,
                child: Text(
                  formatRwf(entry.basePriceRwf),
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    decoration: entry.isCovered && entry.insurancePaysRwf > 0
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: Colors.white24,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),

              // Insurance pays
              Expanded(
                flex: 3,
                child: Text(
                  entry.insurancePaysRwf > 0
                      ? formatRwf(entry.insurancePaysRwf)
                      : '—',
                  style: TextStyle(
                    color: entry.insurancePaysRwf > 0
                        ? _kAccentColor.withValues(alpha: 0.85)
                        : Colors.white24,
                    fontSize: 10,
                    fontWeight: entry.insurancePaysRwf > 0
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),

              // Patient co-pay
              Expanded(
                flex: 3,
                child: Text(
                  entry.patientCopayRwf == 0
                      ? 'Free'
                      : formatRwf(entry.patientCopayRwf),
                  style: TextStyle(
                    color: entry.patientCopayRwf == 0
                        ? _kAccentColor
                        : const Color(0xFFFFD580),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Small badge pill ────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Badge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
