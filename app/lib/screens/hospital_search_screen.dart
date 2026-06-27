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

/// Hospital search screen showing only the 10 curated Masoro-area healthcare
/// facilities. Sorted by distance, filterable by type and insurance network.
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

enum _FilterTab { all, publicOnly, privateOnly, inNetwork }

class _HospitalSearchScreenState extends State<HospitalSearchScreen>
    with SingleTickerProviderStateMixin {
  _SearchPhase _phase = _SearchPhase.locating;
  _FilterTab _activeFilter = _FilterTab.all;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  List<CuratedHospital> _allHospitals = [];

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

    // Load curated hospitals sorted by distance from Masoro
    final hospitals = CuratedHospitals.sortedByDistance;

    setState(() {
      _allHospitals = hospitals;
      _phase = _SearchPhase.results;
    });
  }

  List<CuratedHospital> get _filtered {
    switch (_activeFilter) {
      case _FilterTab.all:
        return _allHospitals;
      case _FilterTab.publicOnly:
        return _allHospitals
            .where((h) => h.type.toLowerCase().contains('public') ||
                h.type.toLowerCase().contains('district') ||
                h.type.toLowerCase().contains('referral') ||
                h.type.toLowerCase().contains('teaching') ||
                h.type.toLowerCase().contains('national'))
            .toList();
      case _FilterTab.privateOnly:
        return _allHospitals
            .where((h) => h.type.toLowerCase().contains('private') ||
                h.type.toLowerCase().contains('premium') ||
                h.type.toLowerCase().contains('poly') ||
                h.type.toLowerCase().contains('specialized'))
            .toList();
      case _FilterTab.inNetwork:
        return _allHospitals.where((h) => h.acceptsInsurance(widget.studentInsurance)).toList();
    }
  }

  // Count helpers for filter tabs
  int get _publicCount => _allHospitals
      .where((h) =>
          h.type.toLowerCase().contains('public') ||
          h.type.toLowerCase().contains('district') ||
          h.type.toLowerCase().contains('referral') ||
          h.type.toLowerCase().contains('national'))
      .length;

  int get _privateCount => _allHospitals
      .where((h) =>
          h.type.toLowerCase().contains('private') ||
          h.type.toLowerCase().contains('premium') ||
          h.type.toLowerCase().contains('poly') ||
          h.type.toLowerCase().contains('specialized'))
      .length;

  int get _inNetworkCount =>
      _allHospitals.where((h) => h.acceptsInsurance(widget.studentInsurance)).length;

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
          'Nearby Hospitals',
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
          const Text('Finding approved facilities near Masoro...',
              style: TextStyle(color: _kTextSecondary, fontSize: 13)),
          const SizedBox(height: 36),
          _DotLoader(),
        ],
      ),
    );
  }

  // ─── Results Phase ─────────────────────────────────────────────────────────
  Widget _buildResults() {
    final list = _filtered;

    return Column(
      key: const ValueKey('results'),
      children: [
        // Location + count header
        _LocationHeader(total: _allHospitals.length),

        // Filter tabs
        _FilterStrip(
          active: _activeFilter,
          onChanged: (tab) => setState(() => _activeFilter = tab),
          allCount: _allHospitals.length,
          publicCount: _publicCount,
          privateCount: _privateCount,
          inNetworkCount: _inNetworkCount,
        ),

        // Hospital list
        Expanded(
          child: list.isEmpty
              ? _buildFilterEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    return _HospitalCard(
                      hospital: list[i],
                      rank: i + 1,
                      insurance: widget.studentInsurance,
                    )
                        .animate()
                        .fade(delay: Duration(milliseconds: 55 * i), duration: 340.ms)
                        .slideY(
                          begin: 0.10,
                          end: 0.0,
                          delay: Duration(milliseconds: 55 * i),
                          duration: 340.ms,
                          curve: Curves.easeOutCubic,
                        );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_list_off_rounded,
              color: _kTextSecondary.withValues(alpha: 0.45), size: 48),
          const SizedBox(height: 14),
          const Text('No facilities match this filter',
              style: TextStyle(color: _kTextSecondary, fontSize: 15)),
        ],
      ),
    );
  }
}

// ─── Location Header ─────────────────────────────────────────────────────────
class _LocationHeader extends StatelessWidget {
  final int total;
  const _LocationHeader({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(bottom: BorderSide(color: _kBorder, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded, color: _kAccent, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Masoro Area, Kigali',
                    style: TextStyle(
                        color: _kTextPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                Text('$total approved facilities · sorted by distance',
                    style: const TextStyle(
                        color: _kTextSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _kElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorder, width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: _kAccent, size: 12),
                SizedBox(width: 4),
                Text('Britam · UAP',
                    style: TextStyle(
                        color: _kAccent, fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Tab Strip ────────────────────────────────────────────────────────
class _FilterStrip extends StatelessWidget {
  final _FilterTab active;
  final ValueChanged<_FilterTab> onChanged;
  final int allCount, publicCount, privateCount, inNetworkCount;

  const _FilterStrip({
    required this.active,
    required this.onChanged,
    required this.allCount,
    required this.publicCount,
    required this.privateCount,
    required this.inNetworkCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _kBg,
        border: Border(bottom: BorderSide(color: _kBorder, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip('All', allCount, active == _FilterTab.all, () => onChanged(_FilterTab.all)),
            const SizedBox(width: 8),
            _buildChip('Public', publicCount, active == _FilterTab.publicOnly,
                () => onChanged(_FilterTab.publicOnly), color: _kBlue),
            const SizedBox(width: 8),
            _buildChip('Private', privateCount, active == _FilterTab.privateOnly,
                () => onChanged(_FilterTab.privateOnly), color: _kViolet),
            const SizedBox(width: 8),
            _buildChip('In-Network', inNetworkCount, active == _FilterTab.inNetwork,
                () => onChanged(_FilterTab.inNetwork)),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, int count, bool selected, VoidCallback onTap,
      {Color color = _kAccent}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.6) : _kBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: selected ? color : _kTextSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.2) : _kElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count',
                  style: TextStyle(
                      color: selected ? color : _kTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hospital Card ────────────────────────────────────────────────────────────
class _HospitalCard extends StatelessWidget {
  final CuratedHospital hospital;
  final int rank;
  final String insurance;

  const _HospitalCard({
    required this.hospital,
    required this.rank,
    required this.insurance,
  });

  bool get _isInNetwork => hospital.acceptsInsurance(insurance) && insurance != 'None';

  bool get _isPublic =>
      hospital.type.toLowerCase().contains('public') ||
      hospital.type.toLowerCase().contains('district') ||
      hospital.type.toLowerCase().contains('national') ||
      hospital.type.toLowerCase().contains('referral') ||
      hospital.type.toLowerCase().contains('teaching');

  Color get _typeColor => _isPublic ? _kBlue : _kViolet;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isInNetwork ? _kAccent.withValues(alpha: 0.35) : _kBorder,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Rank + Name ────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rank badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rank == 1 ? _kAccent.withValues(alpha: 0.18) : _kElevated,
                    border: Border.all(
                      color: rank == 1 ? _kAccent.withValues(alpha: 0.5) : _kBorder,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text('$rank',
                        style: TextStyle(
                            color: rank == 1 ? _kAccent : _kTextSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 11, color: _kTextSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              hospital.sector,
                              style: const TextStyle(
                                  color: _kTextSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Row 2: Stat chips ─────────────────────────────────────────
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _Chip(
                  icon: Icons.directions_walk_rounded,
                  label: '${hospital.distanceKm} km',
                  color: _kTextSecondary,
                ),
                _Chip(
                  icon: _isPublic ? Icons.account_balance_rounded : Icons.business_rounded,
                  label: _isPublic ? 'Public' : 'Private',
                  color: _typeColor,
                ),
                _Chip(
                  icon: Icons.verified_rounded,
                  label: 'Britam · UAP',
                  color: _kAccent,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Row 3: Facility type + Insurance badge ────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _kElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBorder, width: 1),
                    ),
                    child: Text(
                      hospital.type,
                      style: const TextStyle(
                          color: _kTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (insurance != 'None') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _isInNetwork
                          ? _kAccent.withValues(alpha: 0.08)
                          : _kError.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isInNetwork
                            ? _kAccent.withValues(alpha: 0.25)
                            : _kError.withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isInNetwork ? Icons.verified_outlined : Icons.info_outline_rounded,
                          size: 12,
                          color: _isInNetwork ? _kAccent : _kError,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isInNetwork ? 'In-Network' : 'Check Coverage',
                          style: TextStyle(
                              color: _isInNetwork ? _kAccent : _kError,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // ── Row 4: Contact + Navigate actions ─────────────────────────
            Row(
              children: [
                Expanded(
                  child: _Action(
                    icon: Icons.call_rounded,
                    label: 'Call',
                    color: _kAccent,
                    subtitle: hospital.phone,
                    onTap: () => _showContactSheet(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Action(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    color: _kViolet,
                    filled: true,
                    onTap: () => _showContactSheet(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
                style: const TextStyle(
                    color: _kTextPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(hospital.type,
                style: const TextStyle(color: _kTextSecondary, fontSize: 12)),
            const SizedBox(height: 20),
            _ContactRow(icon: Icons.call_rounded, color: _kAccent,
                label: 'Phone', value: hospital.phone),
            const SizedBox(height: 12),
            _ContactRow(icon: Icons.email_outlined, color: _kViolet,
                label: 'Email', value: hospital.email),
            const SizedBox(height: 12),
            _ContactRow(icon: Icons.location_on_rounded, color: _kTextSecondary,
                label: 'Location', value: '${hospital.sector} · ${hospital.distanceKm} km from Masoro'),
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
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: _kTextSecondary, fontSize: 10, fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
              Text(value,
                  style: const TextStyle(
                      color: _kTextPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Stat Chip ────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Card Action Button ───────────────────────────────────────────────────────
class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: filled ? color.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: filled ? 0.45 : 0.28),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
            if (subtitle != null)
              Text(subtitle!,
                  style: TextStyle(
                      color: color.withValues(alpha: 0.65),
                      fontSize: 9,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
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
