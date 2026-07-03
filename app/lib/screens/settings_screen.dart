import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/hospital_repository.dart';

// Design tokens matching the app's deep forest green theme
const _kBgColor = Color(0xFF081510);
const _kElevatedColor = Color(0xFF132A1A);
const _kAccentColor = Color(0xFF3BE2B0);
const _kBorderColor = Color(0xFF1E3525);

/// Full settings screen for student profile, insurance plan, and app preferences.
/// Navigated to from the sidebar drawer.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _historyController = TextEditingController();
  String _insurance = 'None';
  String _contractSummary = '';
  bool _loading = true;
  bool _showSaved = false;
  bool _showMetrics = false;
  bool _isSyncing = false;
  String _syncStatus = '';
  String _lastSyncTime = '';

  static const List<Map<String, String>> _insuranceOptions = [
    {'value': 'None', 'label': 'No Insurance / Out-of-pocket'},
    {'value': 'Britam', 'label': 'Britam Insurance'},
    {'value': 'UAP', 'label': 'Old Mutual / UAP'},
    {'value': 'Mutuelle', 'label': 'Mutuelle de Santé (CBHI)'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _historyController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final dbHelper = DatabaseHelper.instance;
    final name = await dbHelper.getProfileValue('student_name', defaultValue: 'Student');
    final insurance = await dbHelper.getProfileValue('insurance', defaultValue: 'None');
    final history = await dbHelper.getProfileValue('history_summary', defaultValue: '');
    final contract = await dbHelper.getProfileValue('insurance_contract_summary', defaultValue: '');
    final showMetrics = (await dbHelper.getProfileValue('show_performance_metrics', defaultValue: 'false')) == 'true';

    // Retrieve last sync timestamp
    final db = await dbHelper.database;
    final meta = await db.query(
      'hospital_sync_meta',
      where: 'meta_key = ?',
      whereArgs: ['last_sync_timestamp'],
    );
    String lastSync = '';
    if (meta.isNotEmpty) {
      lastSync = meta.first['meta_value'] as String? ?? '';
    }

    final validValues = _insuranceOptions.map((e) => e['value']!).toSet();

    if (mounted) {
      setState(() {
        _nameController.text = name;
        _insurance = validValues.contains(insurance) ? insurance : 'None';
        _historyController.text = history;
        _contractSummary = contract;
        _showMetrics = showMetrics;
        _lastSyncTime = lastSync;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final db = DatabaseHelper.instance;
    final name = _nameController.text.trim();
    await db.setProfileValue('student_name', name.isNotEmpty ? name : 'Student');
    await db.setProfileValue('insurance', _insurance);
    await db.setProfileValue('history_summary', _historyController.text.trim());

    if (mounted) {
      setState(() => _showSaved = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showSaved = false);
      });
    }
  }

  Future<void> _saveMetrics(bool val) async {
    final db = DatabaseHelper.instance;
    await db.setProfileValue('show_performance_metrics', val ? 'true' : 'false');
    if (mounted) {
      setState(() => _showSaved = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showSaved = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccentColor))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                // ── Profile ──────────────────────────────────────────
                _SectionLabel(label: 'PROFILE'),
                const SizedBox(height: 12),

                _buildField(
                  controller: _nameController,
                  hint: 'e.g. Jean Paul',
                  icon: Icons.person_outline_rounded,
                  onChanged: (_) => _save(),
                ),
                const SizedBox(height: 14),

                _buildInsurancePicker(),
                const SizedBox(height: 30),

                // ── Medical Context ───────────────────────────────────
                _SectionLabel(label: 'MEDICAL HISTORY NOTES'),
                const SizedBox(height: 4),
                Text(
                  'Helps the AI personalise hospital guidance for your situation.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                _buildField(
                  controller: _historyController,
                  hint: 'Known conditions, allergies, wellness goals…',
                  icon: Icons.medical_information_outlined,
                  maxLines: 4,
                  onChanged: (_) => _save(),
                ),
                const SizedBox(height: 30),

                // ── Contract Summary (read-only) ───────────────────────
                if (_contractSummary.isNotEmpty) ...[
                  _SectionLabel(label: 'INSURANCE CONTRACT SUMMARY'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kElevatedColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorderColor, width: 1),
                    ),
                    child: Text(
                      _contractSummary,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],

                // ── Performance Metrics ──────────────────────────────
                _SectionLabel(label: 'PERFORMANCE METRICS'),
                const SizedBox(height: 12),
                _buildToggleTile(
                  icon: Icons.speed_rounded,
                  title: 'Show Generation Stats',
                  subtitle: 'Display tokens per second and response generation time under AI bubbles.',
                  value: _showMetrics,
                  onChanged: (val) {
                    setState(() => _showMetrics = val);
                    _saveMetrics(val);
                  },
                ),
                const SizedBox(height: 30),

                // ── Database Sync ─────────────────────────────────────
                _SectionLabel(label: 'DATABASE SYNC'),
                const SizedBox(height: 12),
                _buildSyncTile(),
                const SizedBox(height: 30),

                // ── App Info ──────────────────────────────────────────
                _SectionLabel(label: 'APP INFO'),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.psychology_outlined,
                  title: 'AI Model',
                  value: 'Gemma 4 E2B — Running fully on-device',
                ),
                const SizedBox(height: 8),
                _buildInfoTile(
                  icon: Icons.wifi_off_rounded,
                  title: 'Network Mode',
                  value: '100% Offline — No data sent to any server',
                ),
                const SizedBox(height: 8),
                _buildInfoTile(
                  icon: Icons.location_on_outlined,
                  title: 'Coverage Area',
                  value: 'Masoro & surrounding Kigali districts',
                ),
                const SizedBox(height: 8),
                _buildInfoTile(
                  icon: Icons.local_hospital_outlined,
                  title: 'Curated Facilities',
                  value: '10 verified hospitals & clinics near Masoro',
                ),
                const SizedBox(height: 40),

                // ── Saved pill ────────────────────────────────────────
                AnimatedOpacity(
                  opacity: _showSaved ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _kAccentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _kAccentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: _kAccentColor,
                            size: 15,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'Settings saved',
                            style: TextStyle(
                              color: _kAccentColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kElevatedColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: _kAccentColor.withValues(alpha: 0.65), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: _kAccentColor,
            activeTrackColor: _kAccentColor.withValues(alpha: 0.2),
            inactiveThumbColor: Colors.white30,
            inactiveTrackColor: Colors.white12,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String isoString) {
    if (isoString == 'Never' || isoString.isEmpty) return 'Never';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final month = months[date.month - 1];
      final period = date.hour >= 12 ? 'PM' : 'AM';
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      return '$month ${date.day}, ${date.year} $hour:$minute $period';
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _handleManualSync() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = 'Checking connection and starting sync...';
    });

    try {
      await HospitalRepository.instance.syncFromFirestore();
      
      final db = await DatabaseHelper.instance.database;
      final meta = await db.query(
        'hospital_sync_meta',
        where: 'meta_key = ?',
        whereArgs: ['last_sync_timestamp'],
      );
      String lastSync = 'Never';
      if (meta.isNotEmpty) {
        lastSync = meta.first['meta_value'] as String? ?? '';
      }

      if (mounted) {
        setState(() {
          _lastSyncTime = lastSync;
          _isSyncing = false;
          _syncStatus = 'Database successfully updated!';
        });
        
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              if (_syncStatus == 'Database successfully updated!') {
                _syncStatus = '';
              }
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncStatus = 'Sync failed: $e';
        });
      }
    }
  }

  Widget _buildSyncTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kElevatedColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sync_rounded,
                color: _kAccentColor.withValues(alpha: 0.65),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sync Hospital Directory',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Download latest hospital availability, specialties and costs from Firebase.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last Synchronised:',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateTime(_lastSyncTime),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _isSyncing ? null : _handleManualSync,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccentColor,
                  foregroundColor: _kBgColor,
                  disabledBackgroundColor: _kAccentColor.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  elevation: 0,
                ),
                child: _isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _kBgColor,
                        ),
                      )
                    : const Text(
                        'Sync Now',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
          if (_syncStatus.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _syncStatus,
              style: TextStyle(
                color: _syncStatus.contains('failed') || _syncStatus.contains('offline')
                    ? Colors.orangeAccent
                    : _kAccentColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _kBgColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: const Text(
        'Settings',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _kElevatedColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderColor, width: 1),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
        cursorColor: _kAccentColor,
        textCapitalization: maxLines == 1
            ? TextCapitalization.words
            : TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 13,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              icon,
              color: _kAccentColor.withValues(alpha: 0.65),
              size: 20,
            ),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 48, minHeight: 48),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildInsurancePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _kElevatedColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.shield_outlined,
            color: _kAccentColor.withValues(alpha: 0.65),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _insurance,
                dropdownColor: _kElevatedColor,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _kAccentColor,
                ),
                isExpanded: true,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _insurance = val);
                    _save();
                  }
                },
                items: _insuranceOptions
                    .map(
                      (opt) => DropdownMenuItem<String>(
                        value: opt['value'],
                        child: Text(opt['label']!),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: _kElevatedColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorderColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: _kAccentColor.withValues(alpha: 0.55), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _kAccentColor,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
      ),
    );
  }
}
