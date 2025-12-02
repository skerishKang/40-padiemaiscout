import 'package:flutter_test/flutter_test.dart';
import 'package:grantscout_app/utils/validators.dart';

void main() {
  group('Validators', () {
    group('required', () {
      test('should return error for null value', () {
        expect(Validators.required(null), '이 항목은 필수입니다.');
      });

      test('should return error for empty string', () {
        expect(Validators.required(''), '이 항목은 필수입니다.');
      });

      test('should return error for whitespace only', () {
        expect(Validators.required('   '), '이 항목은 필수입니다.');
      });

      test('should return null for valid string', () {
        expect(Validators.required('valid input'), null);
      });
    });

    group('email', () {
      test('should return error for null value', () {
        expect(Validators.email(null), '이메일을 입력해주세요.');
      });

      test('should return error for empty string', () {
        expect(Validators.email(''), '이메일을 입력해주세요.');
      });

      test('should return error for invalid email', () {
        expect(Validators.email('invalid-email'), '올바른 이메일 형식이 아닙니다.');
        expect(Validators.email('test@'), '올바른 이메일 형식이 아닙니다.');
        expect(Validators.email('@test.com'), '올바른 이메일 형식이 아닙니다.');
      });

      test('should return null for valid email', () {
        expect(Validators.email('test@example.com'), null);
        expect(Validators.email('user.name@domain.co.kr'), null);
      });
    });

    group('establishmentDate', () {
      test('should return error for null value', () {
        expect(Validators.establishmentDate(null), '설립일을 입력해주세요.');
      });

      test('should return error for empty string', () {
        expect(Validators.establishmentDate(''), '설립일을 입력해주세요.');
      });

      test('should return error for invalid format', () {
        expect(Validators.establishmentDate('2023-01-01'), 'YYYYMMDD 8자리로 입력해주세요.');
        expect(Validators.establishmentDate('230101'), 'YYYYMMDD 8자리로 입력해주세요.');
        expect(Validators.establishmentDate('abcd1234'), 'YYYYMMDD 8자리로 입력해주세요.');
      });

      test('should return error for future date', () {
        final futureDate = DateTime.now().add(Duration(days: 365));
        final futureDateStr = '${futureDate.year}${futureDate.month.toString().padLeft(2, '0')}${futureDate.day.toString().padLeft(2, '0')}';
        expect(Validators.establishmentDate(futureDateStr), '설립일은 현재 날짜보다 이전이어야 합니다.');
      });

      test('should return error for very old date', () {
        expect(Validators.establishmentDate('18991231'), '올바른 설립일을 입력해주세요.');
      });

      test('should return null for valid date', () {
        expect(Validators.establishmentDate('20230101'), null);
        expect(Validators.establishmentDate('19501215'), null);
      });
    });

    group('employeeCount', () {
      test('should return error for null value', () {
        expect(Validators.employeeCount(null), '근로자 수를 입력해주세요.');
      });

      test('should return error for empty string', () {
        expect(Validators.employeeCount(''), '근로자 수를 입력해주세요.');
      });

      test('should return error for non-numeric value', () {
        expect(Validators.employeeCount('abc'), '숫자만 입력해주세요.');
        expect(Validators.employeeCount('10.5'), '숫자만 입력해주세요.');
      });

      test('should return error for zero or negative value', () {
        expect(Validators.employeeCount('0'), '1 이상의 숫자를 입력해주세요.');
        expect(Validators.employeeCount('-5'), '1 이상의 숫자를 입력해주세요.');
      });

      test('should return error for unrealistic value', () {
        expect(Validators.employeeCount('100001'), '현실적인 근로자 수를 입력해주세요.');
      });

      test('should return null for valid value', () {
        expect(Validators.employeeCount('1'), null);
        expect(Validators.employeeCount('50'), null);
        expect(Validators.employeeCount('1000'), null);
      });
    });

    group('techKeywords', () {
      test('should return error for null value', () {
        expect(Validators.techKeywords(null), '키워드를 하나 이상 입력해주세요.');
      });

      test('should return error for empty string', () {
        expect(Validators.techKeywords(''), '키워드를 하나 이상 입력해주세요.');
      });

      test('should return error for only commas', () {
        expect(Validators.techKeywords(',,,'), '키워드를 하나 이상 입력해주세요.');
      });

      test('should return error for too many keywords', () {
        final tooManyKeywords = List.generate(21, (index) => 'keyword$index').join(', ');
        expect(Validators.techKeywords(tooManyKeywords), '키워드는 20개 이하로 입력해주세요.');
      });

      test('should return null for valid keywords', () {
        expect(Validators.techKeywords('AI'), null);
        expect(Validators.techKeywords('AI, Flutter, Firebase'), null);
        expect(Validators.techKeywords('  AI  ,  Flutter  ,  Firebase  '), null); // with whitespace
      });
    });

    group('minLength', () {
      test('should return error for null value', () {
        expect(Validators.minLength(null, 5), '이 항목은 필수입니다.');
      });

      test('should return error for short string', () {
        expect(Validators.minLength('abc', 5), '5자 이상 입력해주세요.');
      });

      test('should return null for valid length', () {
        expect(Validators.minLength('abcde', 5), null);
        expect(Validators.minLength('abcdef', 5), null);
      });
    });

    group('maxLength', () {
      test('should return null for null value', () {
        expect(Validators.maxLength(null, 10), null);
      });

      test('should return error for long string', () {
        expect(Validators.maxLength('abcdefghijk', 10), '10자 이하로 입력해주세요.');
      });

      test('should return null for valid length', () {
        expect(Validators.maxLength('abcde', 10), null);
        expect(Validators.maxLength('abcdefghij', 10), null);
      });
    });

    group('combine', () {
      test('should validate with multiple validators', () {
        final validator = Validators.combine([
          Validators.required,
          (value) => Validators.minLength(value, 3),
        ]);

        expect(validator(null), '이 항목은 필수입니다.');
        expect(validator(''), '이 항목은 필수입니다.');
        expect(validator('ab'), '3자 이상 입력해주세요.');
        expect(validator('abc'), null);
      });
    });
  });
}