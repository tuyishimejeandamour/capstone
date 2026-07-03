/// Single source of truth for the curated list of recommended healthcare
/// facilities near Masoro, Kigali. All facilities accept Britam and UAP (Old Mutual).
///
/// This list is authoritative — the AI will ONLY recommend facilities from here.
library;

import 'hospital_cost_model.dart';

class MedicalService {
  final String name;
  final bool isInpatient;
  final String description;

  const MedicalService({
    required this.name,
    required this.isInpatient,
    required this.description,
  });
}

class CuratedHospital {
  final String name;
  final String type;
  final String sector; // district
  final double distanceKm; // approx. distance from Masoro
  final String phone;
  final String email;
  final bool worksBritam;
  final bool worksUAP;

  /// Map of medical service names to their base cash price (uninsured rate) in RWF.
  final Map<String, int> servicesPrices;

  /// Approximate coordinates for Masoro-area positioning.
  /// Used for distance sorting when GPS is available.
  final double lat;
  final double lng;

  const CuratedHospital({
    required this.name,
    required this.type,
    required this.sector,
    required this.distanceKm,
    required this.phone,
    required this.email,
    required this.worksBritam,
    required this.worksUAP,
    required this.servicesPrices,
    required this.lat,
    required this.lng,
  });

  bool get acceptsBritam => worksBritam;
  bool get acceptsUAP => worksUAP;

  /// Returns true if this facility accepts the given insurance plan.
  bool acceptsInsurance(String insurance) {
    final ins = insurance.toLowerCase();
    if (ins.contains('britam')) return worksBritam;
    if (ins.contains('uap') || ins.contains('mutual')) return worksUAP;
    return worksBritam || worksUAP;
  }

  /// Calculates the patient's out-of-pocket co-payment for a service.
  /// Sourced from dataset/rwanda_insurance_financial_policies.md.
  int calculateCopay(String serviceName, String insurance) {
    final price = servicesPrices[serviceName];
    if (price == null) return 0; // Service not offered

    final ins = insurance.toLowerCase();
    final service = CuratedHospitals.services.firstWhere(
      (s) => s.name == serviceName,
      orElse: () => const MedicalService(name: '', isInpatient: false, description: ''),
    );

    if (ins.contains('britam')) {
      // Britam: Inpatient overall is 0% co-pay (fully covered). Outpatient is fully excluded (100% copay).
      if (service.isInpatient) {
        return 0; // 0% Co-payment
      } else {
        return price; // Outpatient is excluded (100% copay)
      }
    } else if (ins.contains('uap') || ins.contains('mutual')) {
      // Old Mutual / UAP: 10% co-payment (90% covered) for all inpatient and outpatient services.
      return (price * 0.10).round();
    } else {
      // No Insurance / Out-of-pocket: 100% co-payment
      return price;
    }
  }

  /// Calculates the amount covered/paid by the insurance provider for a service.
  int calculateInsuranceContribution(String serviceName, String insurance) {
    final price = servicesPrices[serviceName];
    if (price == null) return 0;
    return price - calculateCopay(serviceName, insurance);
  }
}

/// Curated list of 10 recommended healthcare facilities near Masoro, Kigali.
/// All facilities accept both Britam and UAP (Old Mutual) insurance.
class CuratedHospitals {
  /// Authoritative list of standard services for comparison.
  static const List<MedicalService> services = [
    MedicalService(
      name: 'General Consultation',
      isInpatient: false,
      description: 'Standard Outpatient Consultation with a General Practitioner (GP).',
    ),
    MedicalService(
      name: 'Specialist Consultation',
      isInpatient: false,
      description: 'Consultation with a specialist (Dentist, Gynecologist, Psychiatrist, etc.).',
    ),
    MedicalService(
      name: 'Full Blood Count',
      isInpatient: false,
      description: 'Basic laboratory blood panel diagnostic test.',
    ),
    MedicalService(
      name: 'Dental Cleaning / Filling',
      isInpatient: false,
      description: 'Standard outpatient dental check, scaling, cleaning or cavity filling.',
    ),
    MedicalService(
      name: 'Abdominal/Obstetric Ultrasound',
      isInpatient: false,
      description: 'Imaging scan for pregnancy or abdominal organ evaluation.',
    ),
    MedicalService(
      name: 'Chest X-Ray',
      isInpatient: false,
      description: 'Diagnostic chest imaging for respiratory or cardiac symptoms.',
    ),
    MedicalService(
      name: 'Inpatient Admission',
      isInpatient: true,
      description: 'Inpatient room and board ward rate per day.',
    ),
    MedicalService(
      name: 'Standard Maternity Delivery',
      isInpatient: true,
      description: 'Normal delivery inpatient hospital care and obstetric support.',
    ),
  ];

  static const List<CuratedHospital> all = [
    CuratedHospital(
      name: 'Nora Dental Clinic',
      type: 'Specialized Dental Clinic',
      sector: 'Ndera (Gasabo)',
      distanceKm: 1.5,
      phone: '+250 788 843 901',
      email: 'info@auca.ac.rw',
      worksBritam: true,
      worksUAP: true,
      servicesPrices: {
        'Specialist Consultation': 15000,
        'Dental Cleaning / Filling': 30000,
      },
      lat: -1.9197,
      lng: 30.1423,
    ),
    CuratedHospital(
      name: 'Caraes Ndera Neuropsychiatric Hospital',
      type: 'Referral / Teaching Hospital',
      sector: 'Ndera (Gasabo)',
      distanceKm: 2.5,
      phone: '+250 788 827 364',
      email: 'ndera.hospital@moh.gov.rw',
      worksBritam: true,
      worksUAP: true,
      servicesPrices: {
        'General Consultation': 5000,
        'Specialist Consultation': 12000,
        'Inpatient Admission': 20000,
      },
      lat: -1.9215,
      lng: 30.1440,
    ),
    CuratedHospital(
      name: 'Legacy Clinics & Diagnostics',
      type: 'Premium Multi-Specialty Clinic',
      sector: 'Nyarugunga (Kicukiro)',
      distanceKm: 4.0,
      phone: '+250 788 122 100',
      email: 'info@legacyclinics.rw',
      worksBritam: true,
      worksUAP: true,
      servicesPrices: {
        'General Consultation': 18000,
        'Specialist Consultation': 28000,
        'Full Blood Count': 12000,
        'Abdominal/Obstetric Ultrasound': 30000,
        'Chest X-Ray': 22000,
      },
      lat: -1.9600,
      lng: 30.1100,
    ),
    CuratedHospital(
      name: 'Bella Vitae Medical Clinic',
      type: 'Private General Clinic',
      sector: 'Nyarugunga (Kicukiro)',
      distanceKm: 4.5,
      phone: '+250 788 605 491',
      email: 'bellavitaeclinic@gmail.com',
      worksBritam: true,
      worksUAP: true,
      servicesPrices: {
        'General Consultation': 10000,
        'Full Blood Count': 8000,
        'Abdominal/Obstetric Ultrasound': 20000,
      },
      lat: -1.9610,
      lng: 30.1090,
    ),
    CuratedHospital(
      name: 'Rwanda Military Hospital (RMH)',
      type: 'National Referral Hospital',
      sector: 'Kanombe (Kicukiro)',
      distanceKm: 4.5,
      phone: '+250 252 586 420',
      email: 'info@rwandamilitaryhospital.rw',
      worksBritam: true,
      worksUAP: true,
      servicesPrices: {
        'General Consultation': 8000,
        'Specialist Consultation': 18000,
        'Full Blood Count': 6000,
        'Abdominal/Obstetric Ultrasound': 18000,
        'Chest X-Ray': 15000,
        'Inpatient Admission': 35000,
      },
      lat: -1.9680,
      lng: 30.1380,
    ),
    CuratedHospital(
      name: 'Alliance Arena Clinic',
      type: 'Private General Clinic',
      sector: 'Rusororo (Gasabo)',
      distanceKm: 5.5,
      phone: '+250 788 897 734',
      email: 'alliancearenaclinic@gmail.com',
      worksBritam: true,
      worksUAP: true,
      servicesPrices: {
        'General Consultation': 7000,
        'Full Blood Count': 5000,
        'Abdominal/Obstetric Ultrasound': 15000,
      },
      lat: -1.9050,
      lng: 30.1350,
    ),
    CuratedHospital(
      name: 'Kigali Medical Center (KMC)',
      type: 'Private Polyclinic',
      sector: 'Kimironko (Gasabo)',
      distanceKm: 6.0,
      phone: '+250 725 084 378',
      email: 'kmc.polyclinic@yahoo.com',
      worksBritam: true,
      worksUAP: true,
      servicesPrices: {
        'General Consultation': 12000,
        'Specialist Consultation': 22000,
        'Full Blood Count': 9000,
        'Abdominal/Obstetric Ultrasound': 25000,
      },
      lat: -1.9310,
      lng: 30.1180,
    ),
    CuratedHospital(
      name: 'Ubuzima Polyclinic',
      type: 'Private Polyclinic',
      sector: 'Kimironko (Gasabo)',
      distanceKm: 6.0,
      phone: '+250 788 540 557',
      email: 'ubuzimaclinic@gmail.com',
      worksBritam: true,
      worksUAP: true,
      servicesPrices: {
        'General Consultation': 10000,
        'Specialist Consultation': 20000,
        'Full Blood Count': 8000,
        'Abdominal/Obstetric Ultrasound': 22000,
      },
      lat: -1.9295,
      lng: 30.1175,
    ),
    CuratedHospital(
      name: 'Solace Medical Clinic',
      type: 'Private Clinic & Maternity',
      sector: 'Rusororo (Gasabo)',
      distanceKm: 6.5,
      phone: '+250 788 744 989',
      email: 'info@solaceministries.org',
      worksBritam: true,
      worksUAP: true,
      servicesPrices: {
        'General Consultation': 12000,
        'Specialist Consultation': 25000,
        'Abdominal/Obstetric Ultrasound': 25000,
        'Standard Maternity Delivery': 150000,
      },
      lat: -1.9060,
      lng: 30.1370,
    ),
    CuratedHospital(
      name: 'Masaka District Hospital',
      type: 'Public District Hospital',
      sector: 'Masaka (Kicukiro)',
      distanceKm: 7.0,
      phone: '+250 728 878 194',
      email: 'masaka.hospital@moh.gov.rw',
      worksBritam: true,
      worksUAP: true,
      servicesPrices: {
        'General Consultation': 3000,
        'Specialist Consultation': 8000,
        'Full Blood Count': 2500,
        'Abdominal/Obstetric Ultrasound': 7000,
        'Chest X-Ray': 8000,
        'Inpatient Admission': 10000,
      },
      lat: -1.9920,
      lng: 30.1020,
    ),
  ];

  /// Returns all hospitals sorted by distance from Masoro (nearest first).
  static List<CuratedHospital> get sortedByDistance {
    final sorted = List<CuratedHospital>.from(all);
    sorted.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return sorted;
  }

  /// Returns hospitals offering the given service, sorted by cheapest co-payment.
  static List<CuratedHospital> searchByServiceAndPrice(String serviceName, String insurance) {
    final matches = all.where((h) => h.servicesPrices.containsKey(serviceName)).toList();
    matches.sort((a, b) {
      final aCopay = a.calculateCopay(serviceName, insurance);
      final bCopay = b.calculateCopay(serviceName, insurance);
      return aCopay.compareTo(bCopay);
    });
    return matches;
  }

  /// Returns hospitals filtered by insurance plan, sorted by distance.
  static List<CuratedHospital> forInsurance(String insurance) {
    final filtered = all.where((h) => h.acceptsInsurance(insurance)).toList();
    filtered.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return filtered;
  }

  /// Returns hospitals that match a medical specialty/type keyword.
  static List<CuratedHospital> forCondition(String condition) {
    final cond = condition.toLowerCase();
    
    // Explicit Dental check
    if (cond.contains('dental') || cond.contains('teeth') || cond.contains('tooth') || cond.contains('mouth')) {
      return all
          .where((h) => h.name.toLowerCase().contains('nora') || h.type.toLowerCase().contains('dental'))
          .toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
    
    // Explicit Mental / Psychiatric check
    if (cond.contains('mental') || cond.contains('psych') || cond.contains('depression') ||
        cond.contains('anxiety') || cond.contains('stress') || cond.contains('counsel') || cond.contains('brain')) {
      return all
          .where((h) => h.name.toLowerCase().contains('caraes') || h.type.toLowerCase().contains('neuropsychiatric'))
          .toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
    
    // Explicit Maternity / Gynecological check
    if (cond.contains('matern') || cond.contains('pregnan') || cond.contains('birth') ||
        cond.contains('gynec') || cond.contains('obstet')) {
      return all
          .where((h) => h.name.toLowerCase().contains('solace') || h.type.toLowerCase().contains('maternity'))
          .toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }

    // General medical complaints (like headache, fever, stomach pain, checkup, etc.)
    // Exclude specialized (dental, mental health) facilities.
    return all.where((h) {
      final name = h.name.toLowerCase();
      final type = h.type.toLowerCase();
      
      // Exclude specialized clinics for general health complaints
      if (name.contains('nora') || type.contains('dental')) return false;
      if (name.contains('caraes') || type.contains('neuropsychiatric')) return false;
      
      return true;
    }).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  }

  /// Returns the financial co-payment policy and coverage rules for the given plan.
  static String getCopayInfo(String insurance) {
    final ins = insurance.toLowerCase();
    if (ins.contains('uap') || ins.contains('mutual')) {
      return '  * **Inpatient Care:** 10% Co-payment (Old Mutual covers 90%)\n'
             '  * **Outpatient Care:** 10% Co-payment — limits depend on plan tier';
    } else if (ins.contains('radiant')) {
      return '  * **Inpatient Care:** 15% Co-payment (Radiant covers 85%)\n'
             '  * **Outpatient Care:** 15% Co-payment — check your policy annual limits';
    } else if (ins.contains('mutuelle') || ins.contains('cbhi')) {
      return '  * **Inpatient Care:** 10% Co-payment (CBHI covers 90%)\n'
             '  * **Outpatient Care:** 10% Co-payment at referral hospitals; flat 200 RWF at health centers';
    } else {
      return '  * **Inpatient Care:** 100% out-of-pocket (no insurance)\n'
             '  * **Outpatient Care:** 100% out-of-pocket (no insurance)';
    }
  }

  /// Maps a detected condition keyword to the relevant service names.
  static List<String> conditionToRelevantServices(String? condition) {
    if (condition == null) return ['General Consultation'];
    final c = condition.toLowerCase();

    if (c.contains('dental') || c.contains('teeth') || c.contains('tooth') || c.contains('mouth')) {
      return ['Specialist Consultation', 'Dental Cleaning / Filling'];
    }
    if (c.contains('mental') || c.contains('psych') || c.contains('depression') ||
        c.contains('anxiety') || c.contains('stress') || c.contains('counsel')) {
      return ['General Consultation', 'Specialist Consultation', 'Inpatient Admission'];
    }
    if (c.contains('matern') || c.contains('pregnan') || c.contains('birth') ||
        c.contains('gynec') || c.contains('obstet')) {
      return ['Specialist Consultation', 'Abdominal/Obstetric Ultrasound', 'Standard Maternity Delivery'];
    }
    if (c.contains('chest') || c.contains('heart') || c.contains('cardio') || c.contains('breath')) {
      return ['General Consultation', 'Chest X-Ray', 'Specialist Consultation'];
    }
    if (c.contains('bone') || c.contains('fracture') || c.contains('joint') || c.contains('muscle')) {
      return ['General Consultation', 'Specialist Consultation'];
    }
    if (c.contains('eye') || c.contains('vision') || c.contains('skin') || c.contains('rash')) {
      return ['General Consultation', 'Specialist Consultation'];
    }
    if (c.contains('child') || c.contains('kid') || c.contains('pediatr')) {
      return ['General Consultation', 'Specialist Consultation'];
    }
    if (c.contains('accident') || c.contains('injury') || c.contains('bleeding') || c.contains('wound')) {
      return ['General Consultation', 'Inpatient Admission'];
    }
    if (c.contains('lab') || c.contains('diagnost') || c.contains('scan') ||
        c.contains('test') || c.contains('x-ray')) {
      return ['Full Blood Count', 'Chest X-Ray', 'Abdominal/Obstetric Ultrasound'];
    }
    // General: pain, fever, sick, headache, stomach, etc.
    return ['General Consultation', 'Full Blood Count'];
  }

  /// Builds a [HospitalCostSummary] from a list of hospitals, filtered to
  /// services relevant to [condition]. Used by the cost estimate UI widget.
  static HospitalCostSummary buildCostSummary(
    List<CuratedHospital> hospitals, {
    required String insurance,
    String? condition,
    int maxShown = 3,
  }) {
    final relevantServices = conditionToRelevantServices(condition);
    final ins = insurance.toLowerCase();

    final cards = <HospitalCostCard>[];

    for (final h in hospitals.take(maxShown)) {
      final entries = <ServiceCostEntry>[];
      int totalCopay = 0;

      for (final serviceName in relevantServices) {
        final basePrice = h.servicesPrices[serviceName];
        if (basePrice == null) continue; // hospital doesn't offer this service
        // Determine if this is an inpatient service
        final serviceObj = services.firstWhere(
          (s) => s.name == serviceName,
          orElse: () => const MedicalService(name: '', isInpatient: false, description: ''),
        );

        final int copay;
        final bool covered;
        String? coverageNote;

        if (ins.contains('britam')) {
          if (serviceObj.isInpatient) {
            copay = 0;
            covered = true;
            coverageNote = 'Britam covers inpatient (0% copay)';
          } else {
            copay = basePrice;
            covered = false;
            coverageNote = 'Outpatient excluded by Britam — full cost applies';
          }
        } else if (ins.contains('uap') || ins.contains('mutual')) {
          copay = (basePrice * 0.10).round();
          covered = true;
          coverageNote = 'Old Mutual pays 90%';
        } else if (ins.contains('mutuelle') || ins.contains('cbhi')) {
          copay = (basePrice * 0.10).round();
          covered = true;
          coverageNote = 'Mutuelle de Santé covers 90%';
        } else {
          copay = basePrice;
          covered = false;
          coverageNote = 'No insurance — full cost applies';
        }

        totalCopay += copay;
        entries.add(ServiceCostEntry(
          serviceName: serviceName,
          basePriceRwf: basePrice,
          patientCopayRwf: copay,
          insurancePaysRwf: basePrice - copay,
          isCovered: covered,
          coverageNote: coverageNote,
        ));
      }

      if (entries.isNotEmpty) {
        cards.add(HospitalCostCard(
          hospitalName: h.name,
          hospitalType: h.type,
          distanceKm: h.distanceKm,
          isInNetwork: h.acceptsInsurance(insurance),
          phone: h.phone,
          email: h.email,
          services: entries,
          totalEstimatedCopayRwf: totalCopay,
        ));
      }
    }

    // Sort cards by total estimated copay (cheapest first)
    final sorted = [...cards]..sort((a, b) => a.totalEstimatedCopayRwf.compareTo(b.totalEstimatedCopayRwf));

    return HospitalCostSummary(
      insurance: insurance,
      detectedCondition: condition,
      hospitals: cards, // keep original ranking order in the list
      cheapestHospitalName: sorted.isNotEmpty ? sorted.first.hospitalName : '',
      lowestCopayRwf: sorted.isNotEmpty ? sorted.first.totalEstimatedCopayRwf : 0,
    );
  }

  /// Formats an RWF integer into a comma-separated string (e.g. 12,000).
  static String _formatPrice(int rwf) {
    return rwf.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  /// Builds a markdown price-breakdown section for condition-relevant services.
  static String _buildPriceSection(
    CuratedHospital h,
    String insurance,
    String? condition,
  ) {
    final relevantServices = conditionToRelevantServices(condition);
    final ins = insurance.toLowerCase();
    final lines = <String>[];

    for (final serviceName in relevantServices) {
      final price = h.servicesPrices[serviceName];
      if (price == null) continue;

      final serviceObj = services.firstWhere(
        (s) => s.name == serviceName,
        orElse: () =>
            const MedicalService(name: '', isInpatient: false, description: ''),
      );
      final perDay = serviceObj.isInpatient ? '/day' : '';
      final baseStr = '${_formatPrice(price)} RWF$perDay';

      if (ins.contains('britam')) {
        if (serviceObj.isInpatient) {
          lines.add(
            '- $serviceName (base: $baseStr) — **Free** *(inpatient, fully covered)*',
          );
        } else {
          lines.add(
            '- $serviceName (base: $baseStr) — **${_formatPrice(price)} RWF** *(outpatient excluded)*',
          );
        }
      } else if (ins.contains('uap') || ins.contains('mutual')) {
        final copay = (price * 0.10).round();
        lines.add(
          '- $serviceName (base: $baseStr) — **${_formatPrice(copay)} RWF** *(10% copay)*',
        );
      } else if (ins.contains('mutuelle') || ins.contains('cbhi')) {
        final copay = (price * 0.10).round();
        lines.add(
          '- $serviceName (base: $baseStr) — **${_formatPrice(copay)} RWF** *(10% copay)*',
        );
      } else {
        lines.add('- $serviceName — **$baseStr**');
      }
    }

    if (lines.isEmpty) return '';
    final header = insurance == 'None'
        ? '**Service Prices (cash rates):**'
        : '**Your Estimated Cost ($insurance):**';
    return '$header\n${lines.join('\n')}';
  }

  /// Formats a single hospital into a clean markdown card (no emojis).
  /// Pass [condition] to show only services relevant to the health query.
  static String formatCard(
    CuratedHospital h, {
    int? rank,
    String? insurance,
    String? condition,
    bool showInsuranceBadge = true,
  }) {
    final rankPrefix = rank != null ? '### $rank. ' : '### ';
    final inNetwork =
        insurance != null && insurance != 'None' && h.acceptsInsurance(insurance);
    final networkStatus =
        showInsuranceBadge && insurance != null && insurance != 'None'
            ? (inNetwork ? '**In-Network**' : 'Out-of-Network')
            : '';

    final buffer = StringBuffer();
    buffer.writeln('$rankPrefix${h.name}');
    buffer.writeln('*${h.type}* · ${h.sector} · ${h.distanceKm} km from Masoro');
    if (networkStatus.isNotEmpty) buffer.writeln('**Insurance:** $networkStatus');

    // Coverage rules (compact)
    if (insurance != null) {
      buffer.writeln('**Coverage:**');
      buffer.writeln(getCopayInfo(insurance));
    }

    // Condition-relevant service prices
    if (insurance != null) {
      final priceSection = _buildPriceSection(h, insurance, condition);
      if (priceSection.isNotEmpty) {
        buffer.writeln();
        buffer.writeln(priceSection);
      }
    }

    buffer.writeln();
    buffer.writeln('**Phone:** ${h.phone} · **Email:** ${h.email}');
    return buffer.toString();
  }

  /// Formats a complete ranked list of hospitals into a clean markdown response.
  static String formatList(
    List<CuratedHospital> hospitals, {
    String insurance = 'None',
    String? conditionContext,
    int maxShown = 3,
  }) {
    if (hospitals.isEmpty) {
      return 'No matching facilities found near Masoro.\n\n'
          'We recommend contacting **Caraes Ndera Hospital** (+250 788 827 364) '
          'or **Rwanda Military Hospital** (+250 252 586 420) for urgent care.';
    }

    final buffer = StringBuffer();

    if (conditionContext != null) {
      buffer.writeln('I found the following recommended facilities near Masoro for **$conditionContext**:');
    } else {
      buffer.writeln('Here are the recommended healthcare facilities near Masoro:');
    }

    return buffer.toString();
  }
}
