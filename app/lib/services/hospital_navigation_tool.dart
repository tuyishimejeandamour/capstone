import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'hospital_repository.dart';

/// Representation of structured insurance rules for the Gemma system prompt.
class InsuranceCoverageBlock {
  final String providerName;
  final String networkKey;
  final double copayPercent;
  final bool requiresReferral;
  final String referralNotes;
  final String coverageDetails;

  InsuranceCoverageBlock({
    required this.providerName,
    required this.networkKey,
    required this.copayPercent,
    required this.requiresReferral,
    required this.referralNotes,
    required this.coverageDetails,
  });

  @override
  String toString() {
    return '''
Insurance Provider: $providerName
Network Key: $networkKey
Co-payment: ${copayPercent.toStringAsFixed(0)}%
Requires Referral: ${requiresReferral ? "YES" : "NO"}
Referral Notes: $referralNotes
Coverage Details: $coverageDetails''';
  }
}

/// Static database containing coverage rules for Rwandan insurance networks.
class InsuranceCoverageDatabase {
  static final Map<String, InsuranceCoverageBlock> providers = {
    'mutuelle': InsuranceCoverageBlock(
      providerName: 'Mutuelle de Santé (CBHI)',
      networkKey: 'mutuelle',
      copayPercent: 10.0,
      requiresReferral: true,
      referralNotes: 'Requires referral letter from a local health center (Centre de Santé) for district and national hospital coverage.',
      coverageDetails: 'Covers 90% of medical bills, consultations, and medications at public health facilities.',
    ),
    'rssb': InsuranceCoverageBlock(
      providerName: 'RSSB / RAMA',
      networkKey: 'rssb',
      copayPercent: 15.0,
      requiresReferral: false,
      referralNotes: 'No referral required. Direct access to certified public and private facilities.',
      coverageDetails: 'Covers 85% of medical bills, tests, consultations, and medications at certified public and private partner facilities.',
    ),
    'mmi': InsuranceCoverageBlock(
      providerName: 'Military Medical Insurance (MMI)',
      networkKey: 'mmi',
      copayPercent: 10.0,
      requiresReferral: false,
      referralNotes: 'Direct access to Rwanda Military Hospital and accredited military/civilian partner facilities.',
      coverageDetails: 'Covers 90% of medical bills for security personnel and their dependents at partner facilities.',
    ),
    'sanlam': InsuranceCoverageBlock(
      providerName: 'Sanlam Private Health Insurance',
      networkKey: 'sanlam',
      copayPercent: 15.0,
      requiresReferral: false,
      referralNotes: 'Direct access to private Legacy Clinics, King Faisal Hospital, and premium partners.',
      coverageDetails: 'Private insurance with direct billing for consultations, diagnostic tests, and outpatient care.',
    ),
    'britam': InsuranceCoverageBlock(
      providerName: 'Britam Private Insurance',
      networkKey: 'britam',
      copayPercent: 10.0,
      requiresReferral: false,
      referralNotes: 'Direct billing at partner private clinics and pharmacies.',
      coverageDetails: 'Direct coverage for private outpatient packages, specialty care, and pharmacy direct billing.',
    ),
    'uap': InsuranceCoverageBlock(
      providerName: 'UAP Old Mutual',
      networkKey: 'uap',
      copayPercent: 10.0,
      requiresReferral: false,
      referralNotes: 'Direct access to premium partner hospitals with pre-authorization for inpatient care.',
      coverageDetails: 'Premium private coverage across partner clinics (e.g. Legacy, KFH).',
    ),
    'radiant': InsuranceCoverageBlock(
      providerName: 'Radiant Insurance',
      networkKey: 'radiant',
      copayPercent: 15.0,
      requiresReferral: false,
      referralNotes: 'Accepted at major public and private health providers in Rwanda.',
      coverageDetails: 'Covers standard private and public packages, pharmacy bills, and emergency visits.',
    ),
  };

  /// Looks up coverage info by name, returning a fallback block if unknown.
  static InsuranceCoverageBlock getBlock(String insurance) {
    final cleanInsurance = insurance.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    
    if (cleanInsurance.contains('mutuelle') || cleanInsurance.contains('cbhi')) {
      return providers['mutuelle']!;
    } else if (cleanInsurance.contains('rssb') || cleanInsurance.contains('rama')) {
      return providers['rssb']!;
    } else if (cleanInsurance.contains('mmi') || cleanInsurance.contains('military')) {
      return providers['mmi']!;
    } else if (cleanInsurance.contains('sanlam') || cleanInsurance.contains('soras')) {
      return providers['sanlam']!;
    } else if (cleanInsurance.contains('britam')) {
      return providers['britam']!;
    } else if (cleanInsurance.contains('uap') || cleanInsurance.contains('mutual')) {
      return providers['uap']!;
    } else if (cleanInsurance.contains('radiant')) {
      return providers['radiant']!;
    }

    return InsuranceCoverageBlock(
      providerName: insurance.isEmpty ? 'None' : insurance,
      networkKey: 'none',
      copayPercent: 100.0,
      requiresReferral: false,
      referralNotes: 'Full out-of-pocket payment required at all facilities.',
      coverageDetails: 'No insurance coverage. All services are billed 100% to the patient.',
    );
  }
}

/// Data model representing a Hospital, stored in SQLite and Firestore.
class HospitalModel {
  final String id;
  final String name;
  final String address;
  final String district;
  final String province;
  final double lat;
  final double lng;
  final String? phone;
  final String? type; // 'public', 'private'
  final List<String> acceptedInsurance;
  final List<String> specialties;
  final bool emergencyUnit;
  final String? openingHours;
  
  // Community data (aggregated from student submissions)
  final double averageRating;
  final int ratingCount;
  final int averageCostRwf;
  final Map<String, int> averageCostByInsurance;
  final int costSubmissionCount;
  final String lastUpdated;

  HospitalModel({
    required this.id,
    required this.name,
    required this.address,
    required this.district,
    required this.province,
    required this.lat,
    required this.lng,
    this.phone,
    this.type,
    required this.acceptedInsurance,
    required this.specialties,
    required this.emergencyUnit,
    this.openingHours,
    required this.averageRating,
    required this.ratingCount,
    required this.averageCostRwf,
    required this.averageCostByInsurance,
    required this.costSubmissionCount,
    required this.lastUpdated,
  });

  /// Factory constructor to parse SQLite cache format.
  factory HospitalModel.fromSQLiteMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {
          return val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
      }
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    Map<String, int> parseMap(dynamic val) {
      if (val == null) return {};
      if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is Map) {
            return decoded.map((k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0));
          }
        } catch (_) {}
      }
      if (val is Map) {
        return val.map((k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0));
      }
      return {};
    }

    return HospitalModel(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String,
      district: map['district'] as String,
      province: map['province'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      phone: map['phone'] as String?,
      type: map['type'] as String?,
      acceptedInsurance: parseList(map['accepted_insurance'] ?? map['acceptedInsurance']),
      specialties: parseList(map['specialties']),
      emergencyUnit: (map['emergency_unit'] ?? map['emergencyUnit']) == 1 || (map['emergency_unit'] ?? map['emergencyUnit']) == true,
      openingHours: (map['opening_hours'] ?? map['openingHours']) as String?,
      averageRating: ((map['average_rating'] ?? map['averageRating'] ?? 0.0) as num).toDouble(),
      ratingCount: (map['rating_count'] ?? map['ratingCount'] ?? 0) as int,
      averageCostRwf: (map['average_cost_rwf'] ?? map['averageCostRwf'] ?? 0) as int,
      averageCostByInsurance: parseMap(map['average_cost_by_insurance'] ?? map['averageCostByInsurance']),
      costSubmissionCount: (map['cost_submission_count'] ?? map['costSubmissionCount'] ?? 0) as int,
      lastUpdated: (map['last_updated'] ?? map['lastUpdated'] ?? '') as String,
    );
  }

  /// Converts model back to a map suitable for SQLite insertion.
  Map<String, dynamic> toSQLiteMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'district': district,
      'province': province,
      'lat': lat,
      'lng': lng,
      'phone': phone,
      'type': type,
      'accepted_insurance': jsonEncode(acceptedInsurance),
      'specialties': jsonEncode(specialties),
      'emergency_unit': emergencyUnit ? 1 : 0,
      'opening_hours': openingHours,
      'average_rating': averageRating,
      'rating_count': ratingCount,
      'average_cost_rwf': averageCostRwf,
      'average_cost_by_insurance': jsonEncode(averageCostByInsurance),
      'cost_submission_count': costSubmissionCount,
      'last_updated': lastUpdated,
    };
  }

  /// Factory constructor to parse Firestore documents.
  factory HospitalModel.fromFirestore(String id, Map<String, dynamic> data) {
    final community = data['communityData'] as Map<String, dynamic>? ?? {};
    
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    Map<String, int> parseMap(dynamic val) {
      if (val == null) return {};
      if (val is Map) {
        return val.map((k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0));
      }
      return {};
    }

    return HospitalModel(
      id: id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      district: data['district'] as String? ?? '',
      province: data['province'] as String? ?? '',
      lat: (data['lat'] as num? ?? 0.0).toDouble(),
      lng: (data['lng'] as num? ?? 0.0).toDouble(),
      phone: data['phone'] as String?,
      type: data['type'] as String?,
      acceptedInsurance: parseList(data['acceptedInsurance']),
      specialties: parseList(data['specialties']),
      emergencyUnit: data['emergencyUnit'] == true,
      openingHours: data['openingHours'] as String?,
      averageRating: ((community['averageRating'] ?? 0.0) as num).toDouble(),
      ratingCount: (community['ratingCount'] ?? 0) as int,
      averageCostRwf: (community['averageCostRwf'] ?? 0) as int,
      averageCostByInsurance: parseMap(community['averageCostByInsurance']),
      costSubmissionCount: (community['costSubmissionCount'] ?? 0) as int,
      lastUpdated: data['lastUpdated'] as String? ?? '',
    );
  }
}

/// Represents the intermediate result of a hospital lookup containing distance metrics.
class HospitalResult {
  final HospitalModel hospital;
  final double distanceKm;
  final bool isInNetwork;

  HospitalResult({
    required this.hospital,
    required this.distanceKm,
    required this.isInNetwork,
  });
}

/// Represents a scored and ranked hospital recommendation with estimation notes.
class RankedHospitalResult {
  final HospitalResult result;
  final double score;
  final int estimatedCopayRwf;
  final String scoreExplanation;

  RankedHospitalResult({
    required this.result,
    required this.score,
    required this.estimatedCopayRwf,
    required this.scoreExplanation,
  });
}

/// Implements offline-capable hospital navigation tools.
class HospitalNavigationTool {
  
  // --- Function 0: getInsuranceCoverageBlock ---
  static InsuranceCoverageBlock getInsuranceCoverageBlock(String insurance) {
    return InsuranceCoverageDatabase.getBlock(insurance);
  }

  // --- Function 1: getCurrentLocation ---
  static Future<Map<String, double>> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services disabled. Using Kigali fallback.");
        return {'lat': -1.9441, 'lng': 30.0619}; // Kigali center fallback
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("Location permission denied. Using Kigali fallback.");
          return {'lat': -1.9441, 'lng': 30.0619};
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint("Location permission permanently denied. Using Kigali fallback.");
        return {'lat': -1.9441, 'lng': 30.0619};
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );
      return {'lat': position.latitude, 'lng': position.longitude};
    } catch (e) {
      debugPrint("Error getting GPS location: $e. Using Kigali fallback.");
      return {'lat': -1.9441, 'lng': 30.0619};
    }
  }

  // --- Function 2: getNearbyHospitals ---
  static Future<List<HospitalResult>> getNearbyHospitals(
    double lat,
    double lng,
    double radiusKm,
    InsuranceCoverageBlock coverageBlock,
  ) async {
    final hospitals = await HospitalRepository.instance.getCachedHospitals();
    final results = <HospitalResult>[];

    for (final h in hospitals) {
      final dist = calculateDistance(lat, lng, h.lat, h.lng);
      if (radiusKm <= 0 || dist <= radiusKm) {
        final isInNetwork = h.acceptedInsurance.contains(coverageBlock.networkKey);
        results.add(HospitalResult(
          hospital: h,
          distanceKm: dist,
          isInNetwork: isInNetwork,
        ));
      }
    }

    // Sort: in-network first, then by distance
    results.sort((a, b) {
      if (a.isInNetwork != b.isInNetwork) {
        return a.isInNetwork ? -1 : 1;
      }
      return a.distanceKm.compareTo(b.distanceKm);
    });

    return results;
  }

  // --- Function 3: searchHospitalsByCondition ---
  static Future<List<HospitalResult>> searchHospitalsByCondition(
    String condition,
    InsuranceCoverageBlock coverageBlock, {
    double? lat,
    double? lng,
  }) async {
    final hospitals = await HospitalRepository.instance.getCachedHospitals();
    final targetSpecialties = mapConditionToSpecialties(condition);
    final isEmergencySearch = condition.toLowerCase().contains('emergency') || 
                              condition.toLowerCase().contains('accident') || 
                              condition.toLowerCase().contains('injury');
    
    final results = <HospitalResult>[];

    // Reference location for distance calculations
    final referenceLat = lat ?? -1.9441;
    final referenceLng = lng ?? 30.0619;

    for (final h in hospitals) {
      bool matches = false;
      
      if (isEmergencySearch && h.emergencyUnit) {
        matches = true;
      } else {
        for (final spec in h.specialties) {
          if (targetSpecialties.contains(spec.toLowerCase())) {
            matches = true;
            break;
          }
        }
      }

      if (matches) {
        final dist = calculateDistance(referenceLat, referenceLng, h.lat, h.lng);
        final isInNetwork = h.acceptedInsurance.contains(coverageBlock.networkKey);
        results.add(HospitalResult(
          hospital: h,
          distanceKm: dist,
          isInNetwork: isInNetwork,
        ));
      }
    }

    // Sort: in-network first, then by distance
    results.sort((a, b) {
      if (a.isInNetwork != b.isInNetwork) {
        return a.isInNetwork ? -1 : 1;
      }
      return a.distanceKm.compareTo(b.distanceKm);
    });

    return results;
  }

  // --- Function 4: rankHospitalsByPriorityAndCost ---
  static List<RankedHospitalResult> rankHospitalsByPriorityAndCost(
    List<HospitalResult> hospitalResults,
    InsuranceCoverageBlock coverageBlock,
  ) {
    final rankedResults = <RankedHospitalResult>[];

    for (final res in hospitalResults) {
      final h = res.hospital;
      
      // Calculate effective co-pay percentage (100% out of network)
      final double effectiveCopayPercent = res.isInNetwork ? coverageBlock.copayPercent : 100.0;
      
      // Determine baseline cost: prioritizes community data per insurance, then general community cost, then default
      final communityInsuranceCost = h.averageCostByInsurance[coverageBlock.networkKey];
      final baselineCost = communityInsuranceCost ?? (h.averageCostRwf > 0 ? h.averageCostRwf : 15000);
      final estimatedCopay = (baselineCost * (effectiveCopayPercent / 100.0)).round();

      // Score components:
      // 1. Copay Score (0-50 pts) - lower copay is better. Scale: 0 RWF = 50 pts, 30,000+ RWF = 0 pts.
      final copayScore = 50.0 * (1.0 - (estimatedCopay / 30000.0)).clamp(0.0, 50.0);

      // 2. Distance Score (0-30 pts) - closer is better. Scale: 0 km = 30 pts, 15+ km = 0 pts.
      final distanceScore = 30.0 * (1.0 - (res.distanceKm / 15.0)).clamp(0.0, 30.0);

      // 3. Network & Emergency Bonus (up to 30 pts)
      double bonusScore = 0.0;
      if (h.emergencyUnit) bonusScore += 10.0;
      if (res.isInNetwork) bonusScore += 20.0;

      // 4. Rating Bonus (0-10 pts) - averageRating is 0-5. Scale: rating * 2. Default to 3.0.
      final rating = h.ratingCount > 0 ? h.averageRating : 3.0;
      final ratingScore = rating * 2.0;

      final totalScore = copayScore + distanceScore + bonusScore + ratingScore;
      
      final explanation = 'Score: ${totalScore.toStringAsFixed(1)}/110. '
          '(${copayScore.toStringAsFixed(1)} copay, '
          '${distanceScore.toStringAsFixed(1)} distance, '
          '${bonusScore.toStringAsFixed(1)} network/emergency, '
          '${ratingScore.toStringAsFixed(1)} rating). '
          'Est. Copay: $estimatedCopay RWF (${effectiveCopayPercent.toStringAsFixed(0)}% of $baselineCost RWF)';

      rankedResults.add(RankedHospitalResult(
        result: res,
        score: totalScore,
        estimatedCopayRwf: estimatedCopay,
        scoreExplanation: explanation,
      ));
    }

    // Sort by final score descending
    rankedResults.sort((a, b) => b.score.compareTo(a.score));

    return rankedResults;
  }

  // --- Helper Methods ---

  /// Computes distance between two coordinate pairs using the Haversine formula.
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth's radius in km
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  /// Maps condition keyword strings to specialty arrays.
  static List<String> mapConditionToSpecialties(String condition) {
    final cond = condition.toLowerCase();
    final specialties = <String>[];

    if (cond.contains('chest') || cond.contains('heart') || cond.contains('cardio') || cond.contains('breath')) {
      specialties.add('cardiology');
    }
    if (cond.contains('eye') || cond.contains('vision') || cond.contains('see') || cond.contains('blind')) {
      specialties.add('ophthalmology');
    }
    if (cond.contains('bone') || cond.contains('fracture') || cond.contains('joint') || cond.contains('muscle') || cond.contains('break')) {
      specialties.add('surgery');
      specialties.add('orthopedics');
    }
    if (cond.contains('mental') || cond.contains('depression') || cond.contains('anxiety') || cond.contains('stress') || cond.contains('counsel') || cond.contains('mind')) {
      specialties.add('counseling');
      specialties.add('psychiatry');
      specialties.add('mental health');
    }
    if (cond.contains('teeth') || cond.contains('tooth') || cond.contains('dental') || cond.contains('mouth')) {
      specialties.add('dentistry');
      specialties.add('dental');
    }
    if (cond.contains('child') || cond.contains('kid') || cond.contains('baby') || cond.contains('pediatr')) {
      specialties.add('pediatrics');
    }
    if (cond.contains('pregnancy') || cond.contains('pregnant') || cond.contains('gyn') || cond.contains('matern') || cond.contains('birth') || cond.contains('obstetr')) {
      specialties.add('obstetrics');
      specialties.add('gynecology');
    }
    if (cond.contains('skin') || cond.contains('rash') || cond.contains('dermat')) {
      specialties.add('dermatology');
    }
    if (cond.contains('emergency') || cond.contains('accident') || cond.contains('injury') || cond.contains('severe') || cond.contains('bleeding')) {
      specialties.add('emergency');
    }
    
    specialties.add('general medicine');
    return specialties;
  }

  /// Generates a randomized, verification code matching RNG-XXXX pattern.
  static String generateVerificationCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I confusion
    final rand = Random.secure();
    final code = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'RNG-$code'; // e.g. RNG-4F2X
  }
}
