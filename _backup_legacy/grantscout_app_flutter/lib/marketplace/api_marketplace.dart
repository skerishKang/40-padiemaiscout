import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum ApiCategory {
  grantData('지원사업 데이터'),
  aiAnalysis('AI 분석'),
  notifications('알림'),
  integrations('연동'),
  analytics('분석'),
  automation('자동화'),
  security('보안'),
  utilities('유틸리티');

  const ApiCategory(this.displayName);
  final String displayName;
}

enum ApiPlan {
  free('무료'),
  basic('베이직'),
  pro('프로'),
  enterprise('엔터프라이즈');

  const ApiPlan(this.displayName);
  final String displayName;
}

enum ApiStatus {
  active('활성'),
  inactive('비활성'),
  deprecated('사용 중단'),
  beta('베타'),
  pending('검토 중');

  const ApiStatus(this.displayName);
  final String displayName;
}

class ApiProduct {
  final String id;
  final String name;
  final String description;
  final ApiCategory category;
  final String developerId;
  final String developerName;
  final String version;
  final ApiStatus status;
  final List<String> tags;
  final Map<String, ApiPricing> pricing;
  final List<String> endpoints;
  final String documentation;
  final String? imageUrl;
  final String? demoUrl;
  final double rating;
  final int reviewCount;
  final int downloadCount;
  final List<String> dependencies;
  final Map<String, dynamic> configuration;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const ApiProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.developerId,
    required this.developerName,
    required this.version,
    required this.status,
    this.tags = const [],
    required this.pricing,
    this.endpoints = const [],
    required this.documentation,
    this.imageUrl,
    this.demoUrl,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.downloadCount = 0,
    this.dependencies = const [],
    this.configuration = const {},
    required this.createdAt,
    required this.updatedAt,
  });
}

class ApiPricing {
  final ApiPlan plan;
  final double monthlyPrice;
  final double yearlyPrice;
  final Map<String, dynamic> limits;
  final List<String> features;

  const ApiPricing({
    required this.plan,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.limits,
    required this.features,
  });
}

class ApiSubscription {
  final String id;
  final String userId;
  final String productId;
  final String subscriptionId; // 결제 시스템 ID
  final ApiPlan plan;
  final Timestamp startDate;
  final Timestamp? endDate;
  final bool isActive;
  final Map<String, dynamic> usage;
  final Timestamp createdAt;

  const ApiSubscription({
    required this.id,
    required this.userId,
    required this.productId,
    required this.subscriptionId,
    required this.plan,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    this.usage = const {},
    required this.createdAt,
  });
}

class ApiReview {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final double rating;
  final String title;
  final String content;
  final List<String> pros;
  final List<String> cons;
  final bool isVerifiedPurchase;
  final Timestamp createdAt;
  final List<ReviewResponse> responses;

  const ApiReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.title,
    required this.content,
    this.pros = const [],
    this.cons = const [],
    this.isVerifiedPurchase = false,
    required this.createdAt,
    this.responses = const [],
  });
}

class ReviewResponse {
  final String id;
  final String reviewId;
  final String responderId;
  final String responderName;
  final String content;
  final Timestamp createdAt;

  const ReviewResponse({
    required this.id,
    required this.reviewId,
    required this.responderId,
    required this.responderName,
    required this.content,
    required this.createdAt,
  });
}

class ApiUsage {
  final String subscriptionId;
  final String endpoint;
  final int requests;
  final Timestamp timestamp;
  final Map<String, dynamic> metadata;

  const ApiUsage({
    required this.subscriptionId,
    required this.endpoint,
    required this.requests,
    required this.timestamp,
    this.metadata = const {},
  });
}

class ApiMarketplaceService {
  static final ApiMarketplaceService _instance = ApiMarketplaceService._internal();
  factory ApiMarketplaceService() => _instance;
  ApiMarketplaceService._internal();

  // API 제품 검색
  Future<List<ApiProduct>> searchProducts({
    String? query,
    ApiCategory? category,
    ApiStatus? status,
    List<String>? tags,
    String? sortBy,
    bool ascending = false,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      Query firestoreQuery = FirebaseFirestore.instance.collection('api_products');

      // 필터 적용
      if (category != null) {
        firestoreQuery = firestoreQuery.where('category', isEqualTo: category.name);
      }

      if (status != null) {
        firestoreQuery = firestoreQuery.where('status', isEqualTo: status.name);
      }

      if (tags != null && tags.isNotEmpty) {
        firestoreQuery = firestoreQuery.where('tags', arrayContainsAny: tags);
      }

      // 정렬
      switch (sortBy) {
        case 'rating':
          firestoreQuery = firestoreQuery.orderBy('rating', descending: !ascending);
          break;
        case 'downloads':
          firestoreQuery = firestoreQuery.orderBy('downloadCount', descending: !ascending);
          break;
        case 'created':
          firestoreQuery = firestoreQuery.orderBy('createdAt', descending: !ascending);
          break;
        case 'updated':
          firestoreQuery = firestoreQuery.orderBy('updatedAt', descending: !ascending);
          break;
        default:
          firestoreQuery = firestoreQuery.orderBy('rating', descending: true);
      }

      final snapshot = await firestoreQuery.limit(limit).offset(offset).get();

      final products = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ApiProduct(
          id: doc.id,
          name: data['name'] ?? '',
          description: data['description'] ?? '',
          category: ApiCategory.values.firstWhere(
            (c) => c.name == data['category'],
            orElse: () => ApiCategory.utilities,
          ),
          developerId: data['developerId'] ?? '',
          developerName: data['developerName'] ?? '',
          version: data['version'] ?? '1.0.0',
          status: ApiStatus.values.firstWhere(
            (s) => s.name == data['status'],
            orElse: () => ApiStatus.active,
          ),
          tags: List<String>.from(data['tags'] ?? []),
          pricing: Map<String, ApiPricing>.from(
            (data['pricing'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(
                key,
                ApiPricing(
                  plan: ApiPlan.values.firstWhere(
                    (p) => p.name == value['plan'],
                    orElse: () => ApiPlan.free,
                  ),
                  monthlyPrice: (value['monthlyPrice'] as num?)?.toDouble() ?? 0.0,
                  yearlyPrice: (value['yearlyPrice'] as num?)?.toDouble() ?? 0.0,
                  limits: value['limits'] as Map<String, dynamic>? ?? {},
                  features: List<String>.from(value['features'] ?? []),
                ),
              ),
            ) ?? {},
          ),
          endpoints: List<String>.from(data['endpoints'] ?? []),
          documentation: data['documentation'] ?? '',
          imageUrl: data['imageUrl'],
          demoUrl: data['demoUrl'],
          rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
          reviewCount: data['reviewCount'] ?? 0,
          downloadCount: data['downloadCount'] ?? 0,
          dependencies: List<String>.from(data['dependencies'] ?? []),
          configuration: data['configuration'] as Map<String, dynamic>? ?? {},
          createdAt: data['createdAt'] as Timestamp,
          updatedAt: data['updatedAt'] as Timestamp,
        );
      }).toList();

      // 텍스트 검색 필터링
      if (query != null && query.isNotEmpty) {
        final filteredProducts = products.where((product) {
          final searchText = '${product.name} ${product.description} ${product.tags.join(' ')}'.toLowerCase();
          return searchText.contains(query.toLowerCase());
        }).toList();

        return filteredProducts;
      }

      return products;
    } catch (e) {
      throw MarketplaceException('Failed to search products: $e');
    }
  }

  // API 제품 상세 조회
  Future<ApiProduct?> getProduct(String productId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('api_products')
          .doc(productId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;

      return ApiProduct(
        id: doc.id,
        name: data['name'] ?? '',
        description: data['description'] ?? '',
        category: ApiCategory.values.firstWhere(
          (c) => c.name == data['category'],
          orElse: () => ApiCategory.utilities,
        ),
        developerId: data['developerId'] ?? '',
        developerName: data['developerName'] ?? '',
        version: data['version'] ?? '1.0.0',
        status: ApiStatus.values.firstWhere(
          (s) => s.name == data['status'],
          orElse: () => ApiStatus.active,
        ),
        tags: List<String>.from(data['tags'] ?? []),
        pricing: Map<String, ApiPricing>.from(
          (data['pricing'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              ApiPricing(
                plan: ApiPlan.values.firstWhere(
                  (p) => p.name == value['plan'],
                  orElse: () => ApiPlan.free,
                ),
                monthlyPrice: (value['monthlyPrice'] as num?)?.toDouble() ?? 0.0,
                yearlyPrice: (value['yearlyPrice'] as num?)?.toDouble() ?? 0.0,
                limits: value['limits'] as Map<String, dynamic>? ?? {},
                features: List<String>.from(value['features'] ?? []),
              ),
            ),
          ) ?? {},
        ),
        endpoints: List<String>.from(data['endpoints'] ?? []),
        documentation: data['documentation'] ?? '',
        imageUrl: data['imageUrl'],
        demoUrl: data['demoUrl'],
        rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: data['reviewCount'] ?? 0,
        downloadCount: data['downloadCount'] ?? 0,
        dependencies: List<String>.from(data['dependencies'] ?? []),
        configuration: data['configuration'] as Map<String, dynamic>? ?? {},
        createdAt: data['createdAt'] as Timestamp,
        updatedAt: data['updatedAt'] as Timestamp,
      );
    } catch (e) {
      throw MarketplaceException('Failed to get product: $e');
    }
  }

  // API 구독
  Future<String> subscribe({
    required String userId,
    required String productId,
    required ApiPlan plan,
    String? paymentMethodId,
  }) async {
    try {
      // 제품 정보 조회
      final product = await getProduct(productId);
      if (product == null) {
        throw MarketplaceException('Product not found');
      }

      // 기존 구독 확인
      final existingSubscription = await getActiveSubscription(userId, productId);
      if (existingSubscription != null) {
        throw MarketplaceException('Already subscribed to this product');
      }

      // 결제 처리 (여기서는 Mock 처리)
      final subscriptionId = await _processPayment(
        userId: userId,
        productId: productId,
        plan: plan,
        paymentMethodId: paymentMethodId,
      );

      // 구독 정보 저장
      final subscriptionDoc = await FirebaseFirestore.instance
          .collection('api_subscriptions')
          .add({
        'userId': userId,
        'productId': productId,
        'subscriptionId': subscriptionId,
        'plan': plan.name,
        'startDate': Timestamp.now(),
        'endDate': _calculateEndDate(plan),
        'isActive': true,
        'usage': {},
        'createdAt': Timestamp.now(),
      });

      // 다운로드 수 증가
      await _incrementDownloadCount(productId);

      // 구독 알림
      await _sendSubscriptionNotification(userId, product, plan);

      return subscriptionDoc.id;
    } catch (e) {
      throw MarketplaceException('Failed to subscribe: $e');
    }
  }

  // 구독 취소
  Future<void> cancelSubscription(String userId, String subscriptionId) async {
    try {
      final subscriptionDoc = await FirebaseFirestore.instance
          .collection('api_subscriptions')
          .doc(subscriptionId)
          .get();

      if (!subscriptionDoc.exists) {
        throw MarketplaceException('Subscription not found');
      }

      final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
      if (subscriptionData['userId'] != userId) {
        throw MarketplaceException('Unauthorized');
      }

      // 구독 비활성화
      await subscriptionDoc.reference.update({
        'isActive': false,
        'cancelledAt': Timestamp.now(),
      });

      // 결제 취소 처리
      await _cancelPayment(subscriptionData['subscriptionId'] as String);

      // 취소 알림
      await _sendCancellationNotification(userId, subscriptionData['productId'] as String);
    } catch (e) {
      throw MarketplaceException('Failed to cancel subscription: $e');
    }
  }

  // 구독 정보 조회
  Future<ApiSubscription?> getActiveSubscription(String userId, String productId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('api_subscriptions')
          .where('userId', isEqualTo: userId)
          .where('productId', isEqualTo: productId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data() as Map<String, dynamic>;

      return ApiSubscription(
        id: snapshot.docs.first.id,
        userId: data['userId'] ?? '',
        productId: data['productId'] ?? '',
        subscriptionId: data['subscriptionId'] ?? '',
        plan: ApiPlan.values.firstWhere(
          (p) => p.name == data['plan'],
          orElse: () => ApiPlan.free,
        ),
        startDate: data['startDate'] as Timestamp,
        endDate: data['endDate'] as Timestamp?,
        isActive: data['isActive'] ?? false,
        usage: data['usage'] as Map<String, dynamic>? ?? {},
        createdAt: data['createdAt'] as Timestamp,
      );
    } catch (e) {
      throw MarketplaceException('Failed to get subscription: $e');
    }
  }

  // 사용자 구독 목록
  Future<List<ApiSubscription>> getUserSubscriptions(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('api_subscriptions')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        return ApiSubscription(
          id: doc.id,
          userId: data['userId'] ?? '',
          productId: data['productId'] ?? '',
          subscriptionId: data['subscriptionId'] ?? '',
          plan: ApiPlan.values.firstWhere(
            (p) => p.name == data['plan'],
            orElse: () => ApiPlan.free,
          ),
          startDate: data['startDate'] as Timestamp,
          endDate: data['endDate'] as Timestamp?,
          isActive: data['isActive'] ?? false,
          usage: data['usage'] as Map<String, dynamic>? ?? {},
          createdAt: data['createdAt'] as Timestamp,
        );
      }).toList();
    } catch (e) {
      throw MarketplaceException('Failed to get user subscriptions: $e');
    }
  }

  // 리뷰 작성
  Future<String> writeReview({
    required String productId,
    required String userId,
    required String userName,
    required double rating,
    required String title,
    required String content,
    List<String> pros = const [],
    List<String> cons = const [],
  }) async {
    try {
      // 구독 확인
      final subscription = await getActiveSubscription(userId, productId);
      final isVerifiedPurchase = subscription != null;

      final reviewDoc = await FirebaseFirestore.instance
          .collection('api_reviews')
          .add({
        'productId': productId,
        'userId': userId,
        'userName': userName,
        'rating': rating,
        'title': title,
        'content': content,
        'pros': pros,
        'cons': cons,
        'isVerifiedPurchase': isVerifiedPurchase,
        'createdAt': Timestamp.now(),
        'responses': [],
      });

      // 제품 평점 업데이트
      await _updateProductRating(productId);

      return reviewDoc.id;
    } catch (e) {
      throw MarketplaceException('Failed to write review: $e');
    }
  }

  // API 사용량 기록
  Future<void> recordUsage({
    required String subscriptionId,
    required String endpoint,
    required int requests,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('api_usage')
          .add({
        'subscriptionId': subscriptionId,
        'endpoint': endpoint,
        'requests': requests,
        'timestamp': Timestamp.now(),
        'metadata': metadata ?? {},
      });

      // 사용량 제한 확인
      await _checkUsageLimits(subscriptionId);
    } catch (e) {
      throw MarketplaceException('Failed to record usage: $e');
    }
  }

  // 개발자 대시보드
  Future<Map<String, dynamic>> getDeveloperDashboard(String developerId) async {
    try {
      // 제품 통계
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('api_products')
          .where('developerId', isEqualTo: developerId)
          .get();

      final products = productsSnapshot.docs.length;
      int totalDownloads = 0;
      double totalRevenue = 0.0;

      for (final doc in productsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalDownloads += data['downloadCount'] ?? 0;
      }

      // 구독 통계
      final subscriptionsSnapshot = await FirebaseFirestore.instance
          .collection('api_subscriptions')
          .where('productId', whereIn: productsSnapshot.docs.map((doc) => doc.id).toList())
          .where('isActive', isEqualTo: true)
          .get();

      final activeSubscriptions = subscriptionsSnapshot.docs.length;

      // 수익 계산
      for (final doc in subscriptionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // 여기서는 실제 수익 계산 로직 필요
      }

      return {
        'products': products,
        'totalDownloads': totalDownloads,
        'activeSubscriptions': activeSubscriptions,
        'totalRevenue': totalRevenue,
        'recentActivity': await _getDeveloperActivity(developerId),
      };
    } catch (e) {
      throw MarketplaceException('Failed to get developer dashboard: $e');
    }
  }

  // --- Private Helper Methods ---

  Future<String> _processPayment({
    required String userId,
    required String productId,
    required ApiPlan plan,
    String? paymentMethodId,
  }) async {
    // 결제 처리 로직 (Stripe, 결제 시스템 연동)
    // 여기서는 Mock ID 반환
    return 'payment_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _cancelPayment(String subscriptionId) async {
    // 결제 취소 로직
  }

  Timestamp _calculateEndDate(ApiPlan plan) {
    final now = Timestamp.now();
    switch (plan) {
      case ApiPlan.free:
        return Timestamp.fromDate(now.toDate().add(const Duration(days: 365 * 100)));
      case ApiPlan.basic:
        return Timestamp.fromDate(now.toDate().add(const Duration(days: 30)));
      case ApiPlan.pro:
        return Timestamp.fromDate(now.toDate().add(const Duration(days: 30)));
      case ApiPlan.enterprise:
        return Timestamp.fromDate(now.toDate().add(const Duration(days: 365)));
    }
  }

  Future<void> _incrementDownloadCount(String productId) async {
    await FirebaseFirestore.instance
        .collection('api_products')
        .doc(productId)
        .update({
      'downloadCount': FieldValue.increment(1),
    });
  }

  Future<void> _updateProductRating(String productId) async {
    final reviewsSnapshot = await FirebaseFirestore.instance
        .collection('api_reviews')
        .where('productId', isEqualTo: productId)
        .get();

    if (reviewsSnapshot.docs.isEmpty) return;

    double totalRating = 0.0;
    for (final doc in reviewsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalRating += data['rating'] as double;
    }

    final averageRating = totalRating / reviewsSnapshot.docs.length;

    await FirebaseFirestore.instance
        .collection('api_products')
        .doc(productId)
        .update({
      'rating': averageRating,
      'reviewCount': reviewsSnapshot.docs.length,
    });
  }

  Future<void> _checkUsageLimits(String subscriptionId) async {
    // 사용량 제한 확인 로직
  }

  Future<void> _sendSubscriptionNotification(String userId, ApiProduct product, ApiPlan plan) async {
    // 구독 알림 로직
  }

  Future<void> _sendCancellationNotification(String userId, String productId) async {
    // 취소 알림 로직
  }

  Future<List<dynamic>> _getDeveloperActivity(String developerId) async {
    // 개발자 활동 로직
    return [];
  }

  // 추천 시스템
  Future<List<ApiProduct>> getRecommendations(String userId, {int limit = 10}) async {
    try {
      // 사용자 구독 정보 조회
      final subscriptions = await getUserSubscriptions(userId);
      final subscribedCategories = <ApiCategory>{};

      for (final subscription in subscriptions) {
        final product = await getProduct(subscription.productId);
        if (product != null) {
          subscribedCategories.add(product.category);
        }
      }

      // 관련 제품 추천
      final recommendedProducts = <ApiProduct>[];

      for (final category in subscribedCategories) {
        final categoryProducts = await searchProducts(
          category: category,
          sortBy: 'rating',
          limit: 5,
        );

        // 이미 구독한 제품 제외
        for (final product in categoryProducts) {
          final isSubscribed = subscriptions.any((sub) => sub.productId == product.id);
          if (!isSubscribed) {
            recommendedProducts.add(product);
          }
        }
      }

      // 인기 제품 추가
      final popularProducts = await searchProducts(
        sortBy: 'downloads',
        limit: 5,
      );

      for (final product in popularProducts) {
        final isSubscribed = subscriptions.any((sub) => sub.productId == product.id);
        final alreadyRecommended = recommendedProducts.any((p) => p.id == product.id);

        if (!isSubscribed && !alreadyRecommended) {
          recommendedProducts.add(product);
        }
      }

      // 랜덤하게 섞고 제한
      recommendedProducts.shuffle();
      return recommendedProducts.take(limit).toList();
    } catch (e) {
      throw MarketplaceException('Failed to get recommendations: $e');
    }
  }
}

class MarketplaceException implements Exception {
  final String message;
  MarketplaceException(this.message);

  @override
  String toString() => 'MarketplaceException: $message';
}