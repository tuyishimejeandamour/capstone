/// Single source of truth for the curated list of recommended healthcare
/// facilities near Masoro, Kigali. All facilities accept Britam and UAP (Old Mutual).
///
/// This list is authoritative — the AI will ONLY recommend facilities from here.
library;

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

  /// Returns the financial co-payment policy and coverage rules for the given plan
  /// extracted from dataset/rwanda_insurance_financial_policies.md.
  static String getCopayInfo(String insurance) {
    final ins = insurance.toLowerCase();
    if (ins.contains('britam')) {
      return '  * **Inpatient Care**: 0% Co-payment (100% Covered up to overall family limit)\n'
             '  * **Outpatient Care**: Excluded (100% paid out-of-pocket by member)\n'
             '  * *Policy rules: Requires full annual premium payment upfront. Pre-existing, chronic, and psychiatric conditions must be declared and accepted in writing.*';
    } else if (ins.contains('uap') || ins.contains('mutual')) {
      return '  * **Inpatient Care**: 10% Co-payment (Old Mutual covers 90% up to limits)\n'
             '  * **Outpatient Care**: 10% Co-payment (limits depend on tier, e.g., Heza: 250K–450K RWF, Retail: 450K–1.12M RWF, Corporate: 375K–3.75M RWF)\n'
             '  * *Geographic cover: Rwanda local, East African Community (EAC), and India on medical referral.*';
    } else {
      return '  * **Inpatient Care**: 100% Patient Co-payment (Fully Out-of-pocket)\n'
             '  * **Outpatient Care**: 100% Patient Co-payment (Fully Out-of-pocket)';
    }
  }

  /// Formats a single hospital into a clean markdown card string.
  static String formatCard(CuratedHospital h, {int? rank, String? insurance, bool showInsuranceBadge = true}) {
    final rankPrefix = rank != null ? '### $rank. ' : '### ';
    final inNetwork = insurance != null && insurance != 'None' && h.acceptsInsurance(insurance);
    final networkBadge = showInsuranceBadge && insurance != null && insurance != 'None'
        ? (inNetwork ? '✅ **In-Network**' : '⚠️ Out-of-Network')
        : '';

    final buffer = StringBuffer();
    buffer.writeln('$rankPrefix${h.name}');
    buffer.writeln('🏷️ *${h.type}*');
    buffer.writeln('📍 **Location:** ${h.sector} — **${h.distanceKm} km from Masoro**');
    if (networkBadge.isNotEmpty) buffer.writeln('🛡️ **Insurance:** $networkBadge');
    
    // Inject custom copay rules from policies MD dataset
    if (insurance != null) {
      buffer.writeln('💵 **Financial Co-payment & Coverage Rules:**');
      buffer.writeln(getCopayInfo(insurance));
    }
    
    buffer.writeln('📞 **Phone:** ${h.phone}');
    buffer.writeln('📧 **Email:** ${h.email}');
    return buffer.toString();
  }

  /// Formats a complete ranked list of hospitals into a markdown response.
  static String formatList(
    List<CuratedHospital> hospitals, {
    String insurance = 'None',
    String? conditionContext,
    int maxShown = 3,
  }) {
    if (hospitals.isEmpty) {
      return '🏥 **No matching facilities found.**\n\n'
          'We recommend visiting **Caraes Ndera Hospital** (+250 788 827 364) '
          'or **Rwanda Military Hospital** (+250 252 586 420) for urgent care near Masoro.';
    }

    final buffer = StringBuffer();

    if (conditionContext != null) {
      buffer.writeln('🏥 **Recommended Facilities near Masoro for: "$conditionContext"**\n');
    } else {
      buffer.writeln('🏥 **Recommended Healthcare Facilities near Masoro**\n');
    }

    if (insurance != 'None') {
      buffer.writeln('Using your insurance plan: **$insurance** (all listed facilities accept Britam & UAP)\n');
    }

    final shown = hospitals.take(maxShown).toList();
    for (var i = 0; i < shown.length; i++) {
      buffer.writeln(formatCard(shown[i], rank: i + 1, insurance: insurance));
      buffer.writeln('---');
    }

    buffer.writeln('\n> 💡 *Always call ahead to confirm availability before visiting.*');
    return buffer.toString();
  }
}
