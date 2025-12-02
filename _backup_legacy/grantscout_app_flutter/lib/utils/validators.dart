class Validators {
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '이 항목은 필수입니다.';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '이메일을 입력해주세요.';
    }
    
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return '올바른 이메일 형식이 아닙니다.';
    }
    return null;
  }

  static String? establishmentDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '설립일을 입력해주세요.';
    }
    
    final pattern = RegExp(r'^\d{8}$');
    if (!pattern.hasMatch(value.trim())) {
      return 'YYYYMMDD 8자리로 입력해주세요.';
    }
    
    // 날짜 유효성 검증
    try {
      final dateStr = value.trim();
      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));
      
      final date = DateTime(year, month, day);
      final now = DateTime.now();
      
      if (date.isAfter(now)) {
        return '설립일은 현재 날짜보다 이전이어야 합니다.';
      }
      
      if (year < 1900) {
        return '올바른 설립일을 입력해주세요.';
      }
    } catch (e) {
      return '올바른 날짜 형식이 아닙니다.';
    }
    
    return null;
  }

  static String? employeeCount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '근로자 수를 입력해주세요.';
    }
    
    final count = int.tryParse(value.trim());
    if (count == null) {
      return '숫자만 입력해주세요.';
    }
    
    if (count <= 0) {
      return '1 이상의 숫자를 입력해주세요.';
    }
    
    if (count > 100000) {
      return '현실적인 근로자 수를 입력해주세요.';
    }
    
    return null;
  }

  static String? techKeywords(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '키워드를 하나 이상 입력해주세요.';
    }
    
    final keywords = value.split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    
    if (keywords.isEmpty) {
      return '키워드를 하나 이상 입력해주세요.';
    }
    
    if (keywords.length > 20) {
      return '키워드는 20개 이하로 입력해주세요.';
    }
    
    return null;
  }

  static String? phoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '전화번호를 입력해주세요.';
    }
    
    final phoneRegex = RegExp(r'^[0-9-+\s()]+$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return '올바른 전화번호 형식이 아닙니다.';
    }
    
    return null;
  }

  static String? businessRegistrationNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '사업자등록번호를 입력해주세요.';
    }
    
    final cleanValue = value.replaceAll('-', '');
    final pattern = RegExp(r'^\d{10}$');
    
    if (!pattern.hasMatch(cleanValue)) {
      return '올바른 사업자등록번호 형식이 아닙니다. (10자리 숫자)';
    }
    
    return null;
  }

  static String? minLength(String? value, int minLength) {
    if (value == null || value.trim().isEmpty) {
      return '이 항목은 필수입니다.';
    }
    
    if (value.trim().length < minLength) {
      return '$minLength자 이상 입력해주세요.';
    }
    
    return null;
  }

  static String? maxLength(String? value, int maxLength) {
    if (value != null && value.trim().length > maxLength) {
      return '$maxLength자 이하로 입력해주세요.';
    }
    
    return null;
  }

  static String Function(String?) combine(List<String? Function(String?)> validators) {
    return (String? value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result != null) {
          return result;
        }
      }
      return null;
    };
  }
}