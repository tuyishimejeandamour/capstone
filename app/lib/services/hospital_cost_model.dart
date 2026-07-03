/// Data models for structured hospital cost breakdowns.
///
/// These are built from [CuratedHospital] service price data and insurance
/// co-payment rules, then passed to the UI widgets for display.
library;

// ─── Service-level cost entry ──────────────────────────────────────────────

class ServiceCostEntry {
  final String serviceName;
  final int basePriceRwf;
  final int patientCopayRwf;
  final int insurancePaysRwf;

  /// True when the service is actively covered by insurance (patient pays < 100%).
  /// False when outpatient is excluded (e.g. Britam outpatient exclusion).
  final bool isCovered;

  /// Human-readable note about coverage (e.g. "Outpatient excluded by Britam").
  final String? coverageNote;

  const ServiceCostEntry({
    required this.serviceName,
    required this.basePriceRwf,
    required this.patientCopayRwf,
    required this.insurancePaysRwf,
    required this.isCovered,
    this.coverageNote,
  });

  Map<String, dynamic> toJson() => {
        'serviceName': serviceName,
        'basePriceRwf': basePriceRwf,
        'patientCopayRwf': patientCopayRwf,
        'insurancePaysRwf': insurancePaysRwf,
        'isCovered': isCovered,
        'coverageNote': coverageNote,
      };

  factory ServiceCostEntry.fromJson(Map<String, dynamic> json) =>
      ServiceCostEntry(
        serviceName: json['serviceName'] as String,
        basePriceRwf: json['basePriceRwf'] as int,
        patientCopayRwf: json['patientCopayRwf'] as int,
        insurancePaysRwf: json['insurancePaysRwf'] as int,
        isCovered: json['isCovered'] as bool,
        coverageNote: json['coverageNote'] as String?,
      );
}

// ─── Hospital-level cost card ──────────────────────────────────────────────

class HospitalCostCard {
  final String hospitalName;
  final String hospitalType;
  final double distanceKm;
  final bool isInNetwork;
  final String phone;
  final String email;

  /// Only services relevant to the detected condition.
  final List<ServiceCostEntry> services;

  /// Sum of patientCopayRwf across all relevant services.
  final int totalEstimatedCopayRwf;

  const HospitalCostCard({
    required this.hospitalName,
    required this.hospitalType,
    required this.distanceKm,
    required this.isInNetwork,
    required this.phone,
    required this.email,
    required this.services,
    required this.totalEstimatedCopayRwf,
  });

  Map<String, dynamic> toJson() => {
        'hospitalName': hospitalName,
        'hospitalType': hospitalType,
        'distanceKm': distanceKm,
        'isInNetwork': isInNetwork,
        'phone': phone,
        'email': email,
        'services': services.map((s) => s.toJson()).toList(),
        'totalEstimatedCopayRwf': totalEstimatedCopayRwf,
      };

  factory HospitalCostCard.fromJson(Map<String, dynamic> json) =>
      HospitalCostCard(
        hospitalName: json['hospitalName'] as String,
        hospitalType: json['hospitalType'] as String,
        distanceKm: (json['distanceKm'] as num).toDouble(),
        isInNetwork: json['isInNetwork'] as bool,
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        services: (json['services'] as List)
            .map((s) => ServiceCostEntry.fromJson(s as Map<String, dynamic>))
            .toList(),
        totalEstimatedCopayRwf: json['totalEstimatedCopayRwf'] as int,
      );
}

// ─── Summary across all recommended hospitals ─────────────────────────────

class HospitalCostSummary {
  final String insurance;
  final String? detectedCondition;
  final List<HospitalCostCard> hospitals;

  /// Hospital with the lowest total estimated copay.
  final String cheapestHospitalName;
  final int lowestCopayRwf;

  const HospitalCostSummary({
    required this.insurance,
    this.detectedCondition,
    required this.hospitals,
    required this.cheapestHospitalName,
    required this.lowestCopayRwf,
  });

  Map<String, dynamic> toJson() => {
        'insurance': insurance,
        'detectedCondition': detectedCondition,
        'hospitals': hospitals.map((h) => h.toJson()).toList(),
        'cheapestHospitalName': cheapestHospitalName,
        'lowestCopayRwf': lowestCopayRwf,
      };

  factory HospitalCostSummary.fromJson(Map<String, dynamic> json) =>
      HospitalCostSummary(
        insurance: json['insurance'] as String,
        detectedCondition: json['detectedCondition'] as String?,
        hospitals: (json['hospitals'] as List)
            .map((h) => HospitalCostCard.fromJson(h as Map<String, dynamic>))
            .toList(),
        cheapestHospitalName: json['cheapestHospitalName'] as String,
        lowestCopayRwf: json['lowestCopayRwf'] as int,
      );
}
