class UserProfile {
  final String companyName;
  final String businessType; // Industry
  final String establishmentDate;
  final int employeeCount;
  final String locationRegion;
  final List<String> techKeywords;
  final double annualRevenue; // Added: Annual Revenue (Unit: 10,000 KRW)
  final String size; // Added: Company Size (Startup, SME, etc.)
  final DateTime? lastUpdated;

  const UserProfile({
    required this.companyName,
    required this.businessType,
    required this.establishmentDate,
    required this.employeeCount,
    required this.locationRegion,
    required this.techKeywords,
    this.annualRevenue = 0.0,
    this.size = '',
    this.lastUpdated,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      companyName: map['companyName'] ?? '',
      businessType: map['businessType'] ?? '',
      establishmentDate: map['establishmentDate'] ?? '',
      employeeCount: map['employeeCount'] ?? 0,
      locationRegion: map['locationRegion'] ?? '',
      techKeywords: List<String>.from(map['techKeywords'] ?? []),
      annualRevenue: (map['annualRevenue'] ?? 0).toDouble(),
      size: map['size'] ?? '',
      lastUpdated: map['lastUpdated']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'businessType': businessType,
      'establishmentDate': establishmentDate,
      'employeeCount': employeeCount,
      'locationRegion': locationRegion,
      'techKeywords': techKeywords,
      'annualRevenue': annualRevenue,
      'size': size,
      'lastUpdated': lastUpdated,
    };
  }

  UserProfile copyWith({
    String? companyName,
    String? businessType,
    String? establishmentDate,
    int? employeeCount,
    String? locationRegion,
    List<String>? techKeywords,
    double? annualRevenue,
    String? size,
    DateTime? lastUpdated,
  }) {
    return UserProfile(
      companyName: companyName ?? this.companyName,
      businessType: businessType ?? this.businessType,
      establishmentDate: establishmentDate ?? this.establishmentDate,
      employeeCount: employeeCount ?? this.employeeCount,
      locationRegion: locationRegion ?? this.locationRegion,
      techKeywords: techKeywords ?? this.techKeywords,
      annualRevenue: annualRevenue ?? this.annualRevenue,
      size: size ?? this.size,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  bool get isValid {
    return companyName.isNotEmpty &&
           businessType.isNotEmpty &&
           establishmentDate.isNotEmpty &&
           employeeCount > 0 &&
           locationRegion.isNotEmpty &&
           techKeywords.isNotEmpty;
  }

  @override
  String toString() {
    return 'UserProfile(companyName: $companyName, businessType: $businessType, employeeCount: $employeeCount, revenue: $annualRevenue)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
           other.companyName == companyName &&
           other.businessType == businessType &&
           other.establishmentDate == establishmentDate &&
           other.employeeCount == employeeCount &&
           other.locationRegion == locationRegion &&
           other.annualRevenue == annualRevenue &&
           other.size == size;
  }

  @override
  int get hashCode {
    return companyName.hashCode ^
           businessType.hashCode ^
           establishmentDate.hashCode ^
           employeeCount.hashCode ^
           locationRegion.hashCode ^
           annualRevenue.hashCode ^
           size.hashCode;
  }
}