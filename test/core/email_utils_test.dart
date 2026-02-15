import 'package:flutter_test/flutter_test.dart';
import 'package:vbusf/core/utils/email_utils.dart';

void main() {
  // ─── isStudentEmail ──────────────────────────────────────────────────────────
  group('isStudentEmail', () {
    test('valid student emails', () {
      expect(EmailUtils.isStudentEmail('viya.23bce11351@vitbhopal.ac.in'), isTrue);
      expect(EmailUtils.isStudentEmail('john.21mca10001@vitbhopal.ac.in'), isTrue);
      // VIT Bhopal uses 3-letter program codes (BCE/MCA/MBA etc.)
      expect(EmailUtils.isStudentEmail('alice.22mba10042@vitbhopal.ac.in'), isTrue);
    });

    test('case-insensitive match', () {
      expect(EmailUtils.isStudentEmail('VIYA.23BCE11351@VITBHOPAL.AC.IN'), isTrue);
      expect(EmailUtils.isStudentEmail('Viya.23Bce11351@VitBhopal.Ac.In'), isTrue);
    });

    test('rejects faculty email', () {
      expect(EmailUtils.isStudentEmail('prof.sharma@vitbhopal.ac.in'), isFalse);
    });

    test('rejects conductor synthetic email', () {
      expect(EmailUtils.isStudentEmail('conductor_11@vbus.internal'), isFalse);
    });

    test('rejects external emails', () {
      expect(EmailUtils.isStudentEmail('student@gmail.com'),    isFalse);
      expect(EmailUtils.isStudentEmail('user@outlook.com'),     isFalse);
      expect(EmailUtils.isStudentEmail('23bce11351@gmail.com'), isFalse);
    });

    test('rejects malformed student patterns', () {
      // Missing name prefix
      expect(EmailUtils.isStudentEmail('23bce11351@vitbhopal.ac.in'),     isFalse);
      // Wrong reg format (4-digit suffix)
      expect(EmailUtils.isStudentEmail('viya.23bce1135@vitbhopal.ac.in'), isFalse);
      // Missing year digits
      expect(EmailUtils.isStudentEmail('viya.bce11351@vitbhopal.ac.in'),  isFalse);
    });
  });

  // ─── isFacultyEmail ───────────────────────────────────────────────────────────
  group('isFacultyEmail', () {
    test('valid faculty emails', () {
      expect(EmailUtils.isFacultyEmail('prof.sharma@vitbhopal.ac.in'),   isTrue);
      expect(EmailUtils.isFacultyEmail('director@vitbhopal.ac.in'),      isTrue);
      expect(EmailUtils.isFacultyEmail('hod.cse@vitbhopal.ac.in'),       isTrue);
    });

    test('rejects student email', () {
      expect(EmailUtils.isFacultyEmail('viya.23bce11351@vitbhopal.ac.in'), isFalse);
    });

    test('rejects non-university email', () {
      expect(EmailUtils.isFacultyEmail('faculty@gmail.com'), isFalse);
    });

    test('rejects conductor email', () {
      expect(EmailUtils.isFacultyEmail('conductor_11@vbus.internal'), isFalse);
    });
  });

  // ─── isValidUniversityEmail ───────────────────────────────────────────────────
  group('isValidUniversityEmail', () {
    test('accepts student and faculty vitbhopal emails', () {
      expect(EmailUtils.isValidUniversityEmail('viya.23bce11351@vitbhopal.ac.in'), isTrue);
      expect(EmailUtils.isValidUniversityEmail('prof.sharma@vitbhopal.ac.in'),     isTrue);
    });

    test('rejects non-university emails', () {
      expect(EmailUtils.isValidUniversityEmail('user@gmail.com'),            isFalse);
      expect(EmailUtils.isValidUniversityEmail('conductor_11@vbus.internal'), isFalse);
      expect(EmailUtils.isValidUniversityEmail(''),                           isFalse);
    });

    test('is case-insensitive', () {
      expect(EmailUtils.isValidUniversityEmail('PROF@VITBHOPAL.AC.IN'), isTrue);
    });

    test('rejects similar-looking but wrong domains', () {
      expect(EmailUtils.isValidUniversityEmail('user@vit.ac.in'),         isFalse);
      expect(EmailUtils.isValidUniversityEmail('user@vitbhopal.ac'),       isFalse);
      expect(EmailUtils.isValidUniversityEmail('user@notVitbhopal.ac.in'), isFalse);
    });
  });

  // ─── conductorEmail ───────────────────────────────────────────────────────────
  group('conductorEmail', () {
    test('lowercases username and appends domain', () {
      expect(EmailUtils.conductorEmail('Conductor_11'), 'conductor_11@vbus.internal');
      expect(EmailUtils.conductorEmail('CONDUCTOR_01'), 'conductor_01@vbus.internal');
      expect(EmailUtils.conductorEmail('conductor_05'), 'conductor_05@vbus.internal');
    });

    test('resulting email is not a university email', () {
      final email = EmailUtils.conductorEmail('Conductor_11');
      expect(EmailUtils.isValidUniversityEmail(email), isFalse);
      expect(EmailUtils.isStudentEmail(email),         isFalse);
      expect(EmailUtils.isFacultyEmail(email),         isFalse);
    });
  });
}
