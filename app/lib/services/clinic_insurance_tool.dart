class ClinicInsuranceTool {
  static const Map<String, dynamic> wellnessInfo = {
    'name': 'ALU Masoro Campus Wellness & Support Resources',
    'location':
        'ALU Masoro Campus, Kigali, Rwanda (Health & Wellness Office, Ground Floor)',
    'alu_support':
        'ALU Wellness Coordinator: Dedicated mental health support and counseling. Walk-in or email studentwellness@alueducation.com.',
    'wellness_hours':
        'Monday - Friday: 9:00 AM - 5:00 PM',
    'nearest_health_centers':
        '- Ndera Health Center (CS Ndera): Local public clinic for primary care | ~1.5 km | +250 788 888 888\n'
        '- Kabuga Health Center: Public clinic | ~5.0 km\n'
        '- Masoro Community Pharmacy: 24/7 nearest pharmacy | Masoro Commercial Center | +250 788 999 999',
    'crisis_line': 'Rwanda National Emergency Line (24/7): 112 / Suicide Prevention: 114',
    'next_steps':
        'Note that ALU does not have an active on-campus clinic. For minor health concerns, visit the ALU Wellness Office or the nearest Ndera Health Center. For emergencies, call 112 or visit Rwanda Military Hospital (RMH) ER.',
  };

  static const Map<String, Map<String, String>> insuranceNetworks = {
    'mutuelle': {
      'hospital': 'Kibagabaga District Hospital (via Local Health Center referral)',
      'distance': 'Gasabo, Kigali',
      'address': 'Kibagabaga Road, Gasabo',
      'notes':
          'Mutuelle de Santé (CBHI) covers 90% of medical costs at public health centers and district hospitals. Requires referral from a local health center for hospital care.',
    },
    'rssb': {
      'hospital': 'King Faisal Hospital (KFH) & CHUK',
      'distance': 'Kacyiru / Nyarugenge, Kigali',
      'address': 'Kacyiru (KFH) / Nyarugenge (CHUK)',
      'notes':
          'RSSB / RAMA covers 85% of medical bills at certified public and private facilities. The patient pays a 15% co-payment.',
    },
    'mmi': {
      'hospital': 'Rwanda Military Hospital (RMH)',
      'distance': 'Kanombe, Kigali',
      'address': 'Kanombe Road, Kanombe',
      'notes':
          'MMI covers 90% of costs for security personnel and their families at RMH and partner clinics. The patient pays a 10% co-payment.',
    },
    'sanlam': {
      'hospital': 'Legacy Clinics & King Faisal Hospital',
      'distance': 'Kimihurura / Kacyiru, Kigali',
      'address': 'Legacy Clinics (KK 507 St) / KFH (Kacyiru)',
      'notes':
          'Sanlam Private Health Insurance is accepted for consultations, tests, and outpatient care. Typical co-pay is 10-20% depending on policy.',
    },
    'britam': {
      'hospital': 'Polyclinique du Plateau & Legacy Clinics',
      'distance': 'Nyarugenge / Kimihurura, Kigali',
      'address': 'Nyarugenge (Plateau) / Legacy (Kimihurura)',
      'notes':
          'Britam private packages are fully accepted at selected private clinics and pharmacies with direct billing.',
    },
    'uap': {
      'hospital': 'King Faisal Hospital & Legacy Clinics',
      'distance': 'Kacyiru / Kimihurura, Kigali',
      'address': 'KFH (Kacyiru) / Legacy (Kimihurura)',
      'notes':
          'UAP Old Mutual student and family medical schemes are accepted at premium partner hospitals with a 10% co-pay.',
    },
    'radiant': {
      'hospital': 'Croix Rouge Clinic & Kibagabaga Hospital',
      'distance': 'Nyarugenge / Gasabo, Kigali',
      'address': 'Nyarugenge (Croix Rouge) / Kibagabaga',
      'notes':
          'Radiant Medical packages are accepted across major public and private health providers in Kigali.',
    },
  };

  /// Returns ALU Wellness and local Masoro support details as a formatted text block.
  static String getClinicHoursText() {
    return '🏥 **${wellnessInfo['name']}**\n'
        '📍 **Office:** ${wellnessInfo['location']}\n'
        '⏰ **Office Hours:** ${wellnessInfo['wellness_hours']}\n'
        '🧠 **ALU Wellness & Counseling:** ${wellnessInfo['alu_support']}\n\n'
        '💊 **Nearest Local Care & Pharmacy:**\n${wellnessInfo['nearest_health_centers']}\n\n'
        '🚨 **24/7 Emergency Hotlines:** ${wellnessInfo['crisis_line']}\n'
        '📝 **Important Note & Next Steps:** ${wellnessInfo['next_steps']}';
  }

  /// Finds and formats hospital recommendations based on the student's insurance plan.
  static String getHospitalRecommendation(String insurance) {
    final cleanInsurance = insurance.toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '',
    );

    // Look for matching network
    String matchedKey = '';
    if (cleanInsurance.contains('mutuelle') || cleanInsurance.contains('cbhi')) {
      matchedKey = 'mutuelle';
    } else if (cleanInsurance.contains('rssb') || cleanInsurance.contains('rama')) {
      matchedKey = 'rssb';
    } else if (cleanInsurance.contains('mmi') || cleanInsurance.contains('military')) {
      matchedKey = 'mmi';
    } else if (cleanInsurance.contains('sanlam') || cleanInsurance.contains('soras')) {
      matchedKey = 'sanlam';
    } else if (cleanInsurance.contains('britam')) {
      matchedKey = 'britam';
    } else if (cleanInsurance.contains('uap') || cleanInsurance.contains('mutual')) {
      matchedKey = 'uap';
    } else if (cleanInsurance.contains('radiant')) {
      matchedKey = 'radiant';
    }

    if (matchedKey.isNotEmpty && insuranceNetworks.containsKey(matchedKey)) {
      final network = insuranceNetworks[matchedKey]!;
      return '🏥 **Recommended Hospital (In-Network for $insurance):**\n'
          '🏨 **Hospital:** ${network['hospital']}\n'
          '📍 **Address:** ${network['address']} (${network['distance']})\n'
          '📝 **Coverage Notes:** ${network['notes']}';
    }

    return '🏥 **Hospital Recommendation:**\n'
        'Because your insurance provider is listed as **"$insurance"** or is not in our direct database, we recommend visiting:\n'
        '🏨 **CHUK (University Teaching Hospital of Kigali)** (📍 Nyarugenge, Kigali) or **Kibagabaga Hospital** (📍 Gasabo) for consultations.\n'
        'For emergency cases, please visit the nearest district hospital or call **112** (emergency line in Rwanda).';
  }
}
