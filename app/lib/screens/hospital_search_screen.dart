import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/curated_hospitals.dart';

// ─── Deep Forest Green Color Tokens ─────────────────────────────────────────
const _kBg = Color(0xFF081510);
const _kSurface = Color(0xFF0D1F14);
const _kElevated = Color(0xFF132A1A);
const _kAccent = Color(0xFF3BE2B0);
const _kViolet = Color(0xFF926BFF);
const _kBorder = Color(0xFF1E3525);
const _kTextPrimary = Color(0xFFFFFFFF);
const _kTextSecondary = Color(0xFF7BAF8A);
const _kError = Color(0xFFE56B6B);
const _kBlue = Color(0xFF60C6FF);

/// Hospital search & price comparison screen showing curated Masoro facilities.
/// Offers side-by-side pricing metrics for inpatient/outpatient services.
class HospitalSearchScreen extends StatefulWidget {
  final String studentInsurance;

  const HospitalSearchScreen({
    super.key,
    required this.studentInsurance,
  });

  @override
  State<HospitalSearchScreen> createState() => _HospitalSearchScreenState();
}

enum _SearchPhase { locating, results }

class _HospitalSearchScreenState extends State<HospitalSearchScreen>
    with SingleTickerProviderStateMixin {
  _SearchPhase _phase = _SearchPhase.locating;
  String _selectedService = 'General Consultation';

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startSearch();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startSearch() async {
    // Short location detection animation (1.8s)
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    setState(() {
      _phase = _SearchPhase.results;
    });
  }

  List<CuratedHospital> get _filteredHospitals {
    // Automatically filters for hospitals offering the service, sorted by cheapest co-payment.
    return CuratedHospitals.searchByServiceAndPrice(_selectedService, widget.studentInsurance);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kTextPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Medical Price Finder',
          style: TextStyle(
            color: _kTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kAccent.withValues(alpha: 0.25), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, color: _kAccent, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    widget.studentInsurance == 'None' ? 'No Plan' : widget.studentInsurance,
                    style: const TextStyle(color: _kAccent, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        child: _phase == _SearchPhase.locating ? _buildLocating() : _buildResults(),
      ),
    );
  }

  // ─── Location Detection Phase ─────────────────────────────────────────────
  Widget _buildLocating() {
    return Center(
      key: const ValueKey('locating'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (ctx, child) => Transform.scale(scale: _pulseAnim.value, child: child),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kAccent.withValues(alpha: 0.05),
                    border: Border.all(color: _kAccent.withValues(alpha: 0.12), width: 1.5),
                  ),
                ),
                Container(
                  width: 82, height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kAccent.withValues(alpha: 0.10),
                    border: Border.all(color: _kAccent.withValues(alpha: 0.28), width: 1.5),
                  ),
                ),
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kAccent.withValues(alpha: 0.18),
                  ),
                  child: const Icon(Icons.my_location_rounded, color: _kAccent, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Text('Detecting your location',
              style: TextStyle(color: _kTextPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Finding approved facility prices near Masoro...',
              style: TextStyle(color: _kTextSecondary, fontSize: 13)),
          const SizedBox(height: 36),
          _DotLoader(),
        ],
      ),
    );
  }

  // ─── Results Phase ─────────────────────────────────────────────────────────
  Widget _buildResults() {
    final list = _filteredHospitals;
    final currentService = CuratedHospitals.services.firstWhere((s) => s.name == _selectedService);

    return Column(
      key: const ValueKey('results'),
      children: [
        // Service Selection Carousel
        _buildServiceSelector(),

        // Service description header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _kSurface,
            border: Border(bottom: BorderSide(color: _kBorder, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentService.description,
                      style: const TextStyle(color: _kTextSecondary, fontSize: 11, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Showing ${list.length} facilities offering this service · sorted by cheapest co-payment',
                      style: const TextStyle(color: _kAccent, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: currentService.isInpatient ? _kViolet.withValues(alpha: 0.15) : _kBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: currentService.isInpatient ? _kViolet.withValues(alpha: 0.3) : _kBlue.withValues(alpha: 0.3), width: 0.5),
                ),
                child: Text(
                  currentService.isInpatient ? 'Inpatient' : 'Outpatient',
                  style: TextStyle(
                    color: currentService.isInpatient ? _kViolet : _kBlue,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Hospital Pricing Leaderboard
        Expanded(
          child: list.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    return _HospitalPriceCard(
                      hospital: list[i],
                      serviceName: _selectedService,
                      insurance: widget.studentInsurance,
                      rank: i + 1,
                    )
                        .animate()
                        .fade(delay: Duration(milliseconds: 50 * i), duration: 300.ms)
                        .slideY(
                          begin: 0.08,
                          end: 0.0,
                          delay: Duration(milliseconds: 50 * i),
                          duration: 300.ms,
                          curve: Curves.easeOutCubic,
                        );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildServiceSelector() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: _kBg,
        border: Border(bottom: BorderSide(color: _kBorder, width: 1)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: CuratedHospitals.services.length,
        itemBuilder: (context, index) {
          final service = CuratedHospitals.services[index];
          final isSelected = service.name == _selectedService;
          final color = service.isInpatient ? _kViolet : _kAccent;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedService = service.name;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.15) : _kSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : _kBorder,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      service.isInpatient ? Icons.king_bed_outlined : Icons.healing_outlined,
                      size: 14,
                      color: isSelected ? color : _kTextSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      service.name,
                      style: TextStyle(
                        color: isSelected ? color : _kTextSecondary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: _kTextSecondary.withValues(alpha: 0.5), size: 48),
          const SizedBox(height: 14),
          const Text(
            'No facilities offer this service yet.',
            style: TextStyle(color: _kTextSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─── Hospital Price Card ──────────────────────────────────────────────────────
class _HospitalPriceCard extends StatelessWidget {
  final CuratedHospital hospital;
  final String serviceName;
  final String insurance;
  final int rank;

  const _HospitalPriceCard({
    required this.hospital,
    required this.serviceName,
    required this.insurance,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final basePrice = hospital.servicesPrices[serviceName] ?? 0;
    final copay = hospital.calculateCopay(serviceName, insurance);
    final covered = hospital.calculateInsuranceContribution(serviceName, insurance);

    final isBritam = insurance.toLowerCase().contains('britam');
    final isUAP = insurance.toLowerCase().contains('uap') || insurance.toLowerCase().contains('mutual');
    final isUninsured = insurance == 'None';

    final isFreeCopay = copay == 0 && covered > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFreeCopay ? _kAccent.withValues(alpha: 0.45) : _kBorder,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Rank + Name + Distance
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rank number
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rank == 1 ? _kAccent.withValues(alpha: 0.18) : _kElevated,
                    border: Border.all(
                      color: rank == 1 ? _kAccent.withValues(alpha: 0.5) : _kBorder,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: rank == 1 ? _kAccent : _kTextSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hospital.name,
                        style: const TextStyle(
                          color: _kTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${hospital.sector} · ${hospital.distanceKm} km from Masoro',
                        style: const TextStyle(
                          color: _kTextSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Phone shortcut
                GestureDetector(
                  onTap: () => _showContactSheet(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _kElevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: _kBorder, width: 1),
                    ),
                    child: const Icon(Icons.phone_outlined, size: 14, color: _kAccent),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Financial comparison panel
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder, width: 1),
              ),
              child: Column(
                children: [
                  // Row 1: The Copayment (Highlighted)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'YOUR COPAYMENT:',
                        style: TextStyle(
                          color: _kTextSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isFreeCopay ? _kAccent.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isFreeCopay ? '0 RWF (100% COVERED)' : '${_formatPrice(copay)} RWF',
                          style: TextStyle(
                            color: isFreeCopay ? _kAccent : (isUninsured ? _kError : _kAccent),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: _kBorder, height: 1, thickness: 1),
                  ),
                  // Row 2: Cash price & Coverage details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CASH PRICE',
                            style: TextStyle(color: _kTextSecondary, fontSize: 9),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatPrice(basePrice)} RWF',
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            isUninsured ? 'UNINSURED' : 'INSURANCE PAYS',
                            style: const TextStyle(color: _kTextSecondary, fontSize: 9),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isUninsured ? '0%' : '${_formatPrice(covered)} RWF',
                            style: TextStyle(
                              color: isUninsured ? _kTextSecondary : _kTextSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Policy alert tag based on dataset/rwanda_insurance_financial_policies.md
            if (isBritam && !isFreeCopay) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 12, color: _kError),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Outpatient services are excluded under Britam coverage. 100% patient copay applies.',
                      style: TextStyle(color: _kError, fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ] else if (isBritam && isFreeCopay) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 12, color: _kAccent),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Inpatient care fully covered (0% copay) under Britam Rwanda Cover policy.',
                      style: TextStyle(color: _kAccent, fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ] else if (isUAP) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.verified_outlined, size: 12, color: _kAccent),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '10% co-payment applied. Covered at 90% by Old Mutual scheme.',
                      style: TextStyle(color: _kTextSecondary, fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatPrice(int amount) {
    final s = amount.toString();
    if (s.length > 3) {
      final buffer = StringBuffer();
      int count = 0;
      for (int i = s.length - 1; i >= 0; i--) {
        if (count == 3) {
          buffer.write(',');
          count = 0;
        }
        buffer.write(s[i]);
        count++;
      }
      return buffer.toString().split('').reversed.join('');
    }
    return s;
  }

  void _showContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: _kBorder, width: 1),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hospital.name,
                style: const TextStyle(color: _kTextPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(hospital.type,
                style: const TextStyle(color: _kTextSecondary, fontSize: 11)),
            const SizedBox(height: 20),
            _ContactRow(icon: Icons.call_rounded, color: _kAccent, label: 'Phone', value: hospital.phone),
            const SizedBox(height: 12),
            _ContactRow(icon: Icons.email_outlined, color: _kViolet, label: 'Email', value: hospital.email),
            const SizedBox(height: 12),
            _ContactRow(icon: Icons.location_on_rounded, color: _kTextSecondary, label: 'Location', value: '${hospital.sector} · ${hospital.distanceKm} km from Masoro'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _kTextSecondary, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
              Text(value, style: const TextStyle(color: _kTextPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Dot Loader ───────────────────────────────────────────────────────────────
class _DotLoader extends StatefulWidget {
  @override
  State<_DotLoader> createState() => _DotLoaderState();
}

class _DotLoaderState extends State<_DotLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i / 3.0;
          final t = (_ctrl.value - delay).clamp(0.0, 1.0);
          final opacity = math.sin(t * math.pi).clamp(0.2, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kAccent.withValues(alpha: opacity),
            ),
          );
        }),
      ),
    );
  }
}
