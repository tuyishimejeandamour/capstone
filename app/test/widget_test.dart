import 'package:flutter_test/flutter_test.dart';
import 'package:ranga/services/clinic_insurance_tool.dart';
import 'package:ranga/services/tts_service.dart';

void main() {
  test('clinic insurance text is plain text without emoji', () {
    final text = ClinicInsuranceTool.getClinicHoursText();

    expect(text, contains('ALU Masoro Campus Wellness & Support Resources'));
    expect(text, isNot(contains('\u{1F3E5}')));
    expect(text, isNot(contains('\u{1F4CD}')));
    expect(text, isNot(contains('\u{1F9E0}')));
  });

  test('speech text sanitization removes emoji and markdown symbols', () {
    const input = '**Hospital**\n\u{1F3E5} Clinic details\n\u{1F4CD} Kigali';

    final cleaned = sanitizeTextForSpeech(input);

    expect(cleaned, contains('Hospital'));
    expect(cleaned, contains('Clinic details'));
    expect(cleaned, contains('Kigali'));
    expect(cleaned, isNot(contains('\u{1F3E5}')));
    expect(cleaned, isNot(contains('\u{1F4CD}')));
  });
}
