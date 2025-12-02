import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

enum SearchType {
  grants('지원사업'),
  files('파일'),
  projects('프로젝트'),
  reports('보고서'),
  users('사용자'),
  all('전체');

  const SearchType(this.displayName);
  final String displayName;
}

enum SearchOperator {
  contains('포함'),
  equals('일치'),
  startsWith('시작'),
  endsWith('종료'),
  greaterThan('초과'),
  lessThan('미만'),
  between('사이'),
  inList('목록에 포함'),
  notInList('목록에 미포함');

  const SearchOperator(this.displayName);
  final String displayName;
}

class SearchQuery {
  final String keyword;
  final SearchType type;
  final List<SearchFilter> filters;
  final List<String> fields;
  final String sortBy;
  final bool sortAscending;
  final int limit;
  final int offset;
  final Map<String, dynamic> metadata;

  const SearchQuery({
    required this.keyword,
    this.type = SearchType.all,
    this.filters = const [],
    this.fields = const [],
    this.sortBy = 'relevance',
    this.sortAscending = false,
    this.limit = 20,
    this.offset = 0,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'keyword': keyword,
      'type': type.name,
      'filters': filters.map((f) => f.toMap()).toList(),
      'fields': fields,
      'sortBy': sortBy,
      'sortAscending': sortAscending,
      'limit': limit,
      'offset': offset,
      'metadata': metadata,
    };
  }
}

class SearchFilter {
  final String field;
  final SearchOperator operator;
  final dynamic value;
  final dynamic value2; // between 연산자용 두 번째 값

  const SearchFilter({
    required this.field,
    required this.operator,
    required this.value,
    this.value2,
  });

  Map<String, dynamic> toMap() {
    return {
      'field': field,
      'operator': operator.name,
      'value': value,
      'value2': value2,
    };
  }
}

class SearchResult {
  final String id;
  final SearchType type;
  final String title;
  final String? description;
  final Map<String, dynamic> data;
  final double relevanceScore;
  final Map<String, dynamic> highlights;
  final Map<String, dynamic> metadata;

  const SearchResult({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.data,
    required this.relevanceScore,
    this.highlights = const {},
    this.metadata = const {},
  });
}

class SearchSuggestion {
  final String text;
  final SearchType type;
  final int frequency;
  final Map<String, dynamic> metadata;

  const SearchSuggestion({
    required this.text,
    required this.type,
    required this.frequency,
    this.metadata = const {},
  });
}

class AdvancedSearchService {
  static final AdvancedSearchService _instance = AdvancedSearchService._internal();
  factory AdvancedSearchService() => _instance;
  AdvancedSearchService._internal();

  // 고급 검색 실행
  Future<SearchResponse> search(SearchQuery query) async {
    try {
      final startTime = DateTime.now();

      // 검색 로그 기록
      await _logSearchQuery(query);

      // 각 타입별 검색 실행
      final results = <SearchResult>[];
      final searchTypes = query.type == SearchType.all
          ? SearchType.values.where((t) => t != SearchType.all)
          : [query.type];

      for (final type in searchTypes) {
        final typeResults = await _searchByType(type, query);
        results.addAll(typeResults);
      }

      // 결과 정렬 및 페이징
      final sortedResults = _sortResults(results, query);
      final paginatedResults = _paginateResults(sortedResults, query);

      // 관련도 점수 재계산
      final finalResults = await _recalculateRelevance(paginatedResults, query);

      // 검색 통계 업데이트
      await _updateSearchStatistics(query, finalResults.length);

      final duration = DateTime.now().difference(startTime);

      return SearchResponse(
        query: query,
        results: finalResults,
        total: sortedResults.length,
        took: duration.inMilliseconds,
        suggestions: await _getSearchSuggestions(query.keyword),
        facets: await _calculateFacets(results),
        metadata: {
          'searchId': _generateSearchId(),
          'timestamp': Timestamp.now(),
        },
      );
    } catch (e) {
      throw SearchException('Search failed: $e');
    }
  }

  // 자동완성 제안
  Future<List<SearchSuggestion>> getAutoCompleteSuggestions(String partial, {SearchType? type}) async {
    try {
      if (partial.length < 2) return [];

      final suggestions = <SearchSuggestion>[];

      // 인기 검색어 제안
      final popularSuggestions = await _getPopularSuggestions(partial, type);
      suggestions.addAll(popularSuggestions);

      // 최근 검색어 제안
      final recentSuggestions = await _getRecentSuggestions(partial, type);
      suggestions.addAll(recentSuggestions);

      // 개인화 제안
      final personalizedSuggestions = await _getPersonalizedSuggestions(partial, type);
      suggestions.addAll(personalizedSuggestions);

      // 중복 제거 및 정렬
      final uniqueSuggestions = _removeDuplicateSuggestions(suggestions);
      uniqueSuggestions.sort((a, b) => b.frequency.compareTo(a.frequency));

      return uniqueSuggestions.take(10).toList();
    } catch (e) {
      return [];
    }
  }

  // 저장된 검색
  Future<void> saveSearch(String userId, SearchQuery query, String name) async {
    try {
      final savedSearch = {
        'userId': userId,
        'name': name,
        'query': query.toMap(),
        'createdAt': Timestamp.now(),
        'lastUsed': Timestamp.now(),
        'useCount': 0,
      };

      await FirebaseFirestore.instance
          .collection('saved_searches')
          .add(savedSearch);
    } catch (e) {
      throw SearchException('Failed to save search: $e');
    }
  }

  // 저장된 검색 목록
  Future<List<Map<String, dynamic>>> getSavedSearches(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('saved_searches')
          .where('userId', isEqualTo: userId)
          .orderBy('lastUsed', descending: true)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // 상세 검색 (특정 도큐먼트 내 검색)
  Future<List<Map<String, dynamic>>> deepSearch({
    required String documentId,
    required String collection,
    required String keyword,
    List<String> fields = const [],
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(documentId)
          .get();

      if (!doc.exists) return [];

      final data = doc.data() as Map<String, dynamic>;
      final searchFields = fields.isEmpty ? _getAllSearchableFields(data) : fields;

      final matches = <Map<String, dynamic>>[];

      for (final field in searchFields) {
        final value = _getNestedValue(data, field);
        if (value != null && value.toString().toLowerCase().contains(keyword.toLowerCase())) {
          matches.add({
            'field': field,
            'value': value.toString(),
            'highlights': _highlightText(value.toString(), keyword),
          });
        }
      }

      return matches;
    } catch (e) {
      throw SearchException('Deep search failed: $e');
    }
  }

  // 유사도 검색
  Future<List<SearchResult>> findSimilarDocuments({
    required String documentId,
    required String collection,
    double threshold = 0.7,
    int limit = 10,
  }) async {
    try {
      // 기준 문서 조회
      final baseDoc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(documentId)
          .get();

      if (!baseDoc.exists) return [];

      final baseData = baseDoc.data() as Map<String, dynamic>;
      final baseVector = await _generateDocumentVector(baseData);

      // 다른 문서들과 유사도 비교
      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where(FieldPath.documentId, isNotEqualTo: documentId)
          .limit(50)
          .get();

      final similarDocs = <SearchResult>[];

      for (final doc in snapshot.docs) {
        final docData = doc.data() as Map<String, dynamic>;
        final docVector = await _generateDocumentVector(docData);

        final similarity = _calculateCosineSimilarity(baseVector, docVector);

        if (similarity >= threshold) {
          similarDocs.add(SearchResult(
            id: doc.id,
            type: _getSearchTypeFromCollection(collection),
            title: docData['title'] ?? 'Untitled',
            description: docData['description'],
            data: docData,
            relevanceScore: similarity,
            metadata: {'similarity': similarity},
          ));
        }
      }

      // 유사도순 정렬
      similarDocs.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      return similarDocs.take(limit).toList();
    } catch (e) {
      throw SearchException('Similarity search failed: $e');
    }
  }

  // --- Private Helper Methods ---

  Future<List<SearchResult>> _searchByType(SearchType type, SearchQuery query) async {
    switch (type) {
      case SearchType.grants:
        return await _searchGrants(query);
      case SearchType.files:
        return await _searchFiles(query);
      case SearchType.projects:
        return await _searchProjects(query);
      case SearchType.reports:
        return await _searchReports(query);
      case SearchType.users:
        return await _searchUsers(query);
      case SearchType.all:
        return [];
    }
  }

  Future<List<SearchResult>> _searchGrants(SearchQuery query) async {
    final collection = FirebaseFirestore.instance.collection('grants');
    Query firestoreQuery = collection;

    // 필터 적용
    for (final filter in query.filters) {
      firestoreQuery = _applyFilter(firestoreQuery, filter);
    }

    // 텍스트 검색 (Firestore에서는 제한적이므로 클라이언트 측에서 필터링)
    final snapshot = await firestoreQuery.limit(100).get();

    final results = <SearchResult>[];

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final relevanceScore = _calculateRelevanceScore(data, query);

      if (relevanceScore > 0) {
        results.add(SearchResult(
          id: doc.id,
          type: SearchType.grants,
          title: data['title'] ?? '',
          description: data['description'],
          data: data,
          relevanceScore: relevanceScore,
          highlights: _generateHighlights(data, query.keyword),
        ));
      }
    }

    return results;
  }

  Future<List<SearchResult>> _searchFiles(SearchQuery query) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('files')
        .limit(100)
        .get();

    final results = <SearchResult>[];

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final relevanceScore = _calculateRelevanceScore(data, query);

      if (relevanceScore > 0) {
        results.add(SearchResult(
          id: doc.id,
          type: SearchType.files,
          title: data['fileName'] ?? '',
          description: data['description'],
          data: data,
          relevanceScore: relevanceScore,
          highlights: _generateHighlights(data, query.keyword),
        ));
      }
    }

    return results;
  }

  Query _applyFilter(Query query, SearchFilter filter) {
    switch (filter.operator) {
      case SearchOperator.equals:
        return query.where(filter.field, isEqualTo: filter.value);
      case SearchOperator.greaterThan:
        return query.where(filter.field, isGreaterThan: filter.value);
      case SearchOperator.lessThan:
        return query.where(filter.field, isLessThan: filter.value);
      case SearchOperator.between:
        return query
            .where(filter.field, isGreaterThanOrEqualTo: filter.value)
            .where(filter.field, isLessThanOrEqualTo: filter.value2);
      case SearchOperator.inList:
        return query.where(filter.field, whereIn: filter.value);
      case SearchOperator.notInList:
        return query.where(filter.field, whereNotIn: filter.value);
      default:
        // Firestore에서 직접 지원하지 않는 연산자는 클라이언트 측에서 처리
        return query;
    }
  }

  double _calculateRelevanceScore(Map<String, dynamic> data, SearchQuery query) {
    double score = 0.0;
    final keyword = query.keyword.toLowerCase();

    // 검색 필드에서 키워드 검색
    final searchFields = query.fields.isEmpty
        ? ['title', 'description', 'content']
        : query.fields;

    for (final field in searchFields) {
      final value = _getNestedValue(data, field);
      if (value != null) {
        final fieldValue = value.toString().toLowerCase();

        // 정확히 일치
        if (fieldValue == keyword) {
          score += 1.0;
        }
        // 단어 포함
        else if (fieldValue.contains(keyword)) {
          score += 0.8;
        }
        // 부분 일치
        else if (fieldValue.contains(keyword.substring(0, min(3, keyword.length)))) {
          score += 0.3;
        }
      }
    }

    return score;
  }

  List<SearchResult> _sortResults(List<SearchResult> results, SearchQuery query) {
    results.sort((a, b) {
      switch (query.sortBy) {
        case 'relevance':
          return b.relevanceScore.compareTo(a.relevanceScore);
        case 'title':
          return query.sortAscending
              ? a.title.compareTo(b.title)
              : b.title.compareTo(a.title);
        case 'date':
          final aDate = (a.data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bDate = (b.data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          return query.sortAscending
              ? aDate.compareTo(bDate)
              : bDate.compareTo(aDate);
        default:
          return b.relevanceScore.compareTo(a.relevanceScore);
      }
    });

    return results;
  }

  List<SearchResult> _paginateResults(List<SearchResult> results, SearchQuery query) {
    final start = query.offset;
    final end = start + query.limit;

    if (start >= results.length) return [];
    if (end > results.length) return results.sublist(start);

    return results.sublist(start, end);
  }

  Map<String, dynamic> _generateHighlights(Map<String, dynamic> data, String keyword) {
    final highlights = <String, String>{};
    final searchFields = ['title', 'description', 'content'];

    for (final field in searchFields) {
      final value = _getNestedValue(data, field);
      if (value != null) {
        highlights[field] = _highlightText(value.toString(), keyword);
      }
    }

    return highlights;
  }

  String _highlightText(String text, String keyword) {
    final pattern = RegExp('($keyword)', caseSensitive: false);
    return text.replaceAll(pattern, '<mark>$1</mark>');
  }

  dynamic _getNestedValue(Map<String, dynamic> data, String field) {
    final parts = field.split('.');
    dynamic current = data;

    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current;
  }

  List<String> _getAllSearchableFields(Map<String, dynamic> data) {
    final fields = <String>[];
    _extractFields(data, '', fields);
    return fields;
  }

  void _extractFields(Map<String, dynamic> data, String prefix, List<String> fields) {
    for (final entry in data.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';

      if (entry.value is String) {
        fields.add(key);
      } else if (entry.value is Map<String, dynamic>) {
        _extractFields(entry.value, key, fields);
      }
    }
  }

  Future<void> _logSearchQuery(SearchQuery query) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('search_logs').add({
        'userId': user.uid,
        'query': query.toMap(),
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      // 로깅 실패는 무시
    }
  }

  Future<List<SearchSuggestion>> _getPopularSuggestions(String partial, SearchType? type) async {
    // 인기 검색어 로직
    return [];
  }

  Future<List<SearchSuggestion>> _getRecentSuggestions(String partial, SearchType? type) async {
    // 최근 검색어 로직
    return [];
  }

  Future<List<SearchSuggestion>> _getPersonalizedSuggestions(String partial, SearchType? type) async {
    // 개인화된 제안 로직
    return [];
  }

  List<SearchSuggestion> _removeDuplicateSuggestions(List<SearchSuggestion> suggestions) {
    final seen = <String>{};
    return suggestions.where((suggestion) => seen.add(suggestion.text)).toList();
  }

  Future<List<SearchSuggestion>> _getSearchSuggestions(String keyword) async {
    // 검색 제안 로직
    return [];
  }

  Future<Map<String, dynamic>> _calculateFacets(List<SearchResult> results) async {
    // 패싯 계산 로직
    return {};
  }

  Future<void> _updateSearchStatistics(SearchQuery query, int resultCount) async {
    // 검색 통계 업데이트
  }

  Future<List<SearchResult>> _recalculateRelevance(List<SearchResult> results, SearchQuery query) async {
    // 관련도 재계산 로직
    return results;
  }

  String _generateSearchId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // 벡터 유사도 계산 관련 메서드들
  Future<Map<String, double>> _generateDocumentVector(Map<String, dynamic> data) async {
    // TF-IDF 벡터 생성
    return {};
  }

  double _calculateCosineSimilarity(Map<String, double> vec1, Map<String, double> vec2) {
    double dotProduct = 0.0;
    double magnitude1 = 0.0;
    double magnitude2 = 0.0;

    vec1.forEach((key, value1) {
      final value2 = vec2[key] ?? 0.0;
      dotProduct += value1 * value2;
      magnitude1 += value1 * value1;
    });

    vec2.forEach((key, value) {
      magnitude2 += value * value;
    });

    if (magnitude1 == 0 || magnitude2 == 0) return 0.0;

    return dotProduct / (sqrt(magnitude1) * sqrt(magnitude2));
  }

  SearchType _getSearchTypeFromCollection(String collection) {
    switch (collection) {
      case 'grants':
        return SearchType.grants;
      case 'files':
        return SearchType.files;
      case 'projects':
        return SearchType.projects;
      case 'reports':
        return SearchType.reports;
      default:
        return SearchType.all;
    }
  }

  Future<List<SearchResult>> _searchProjects(SearchQuery query) async => [];
  Future<List<SearchResult>> _searchReports(SearchQuery query) async => [];
  Future<List<SearchResult>> _searchUsers(SearchQuery query) async => [];
}

class SearchResponse {
  final SearchQuery query;
  final List<SearchResult> results;
  final int total;
  final int took; // milliseconds
  final List<SearchSuggestion> suggestions;
  final Map<String, dynamic> facets;
  final Map<String, dynamic> metadata;

  const SearchResponse({
    required this.query,
    required this.results,
    required this.total,
    required this.took,
    this.suggestions = const [],
    this.facets = const {},
    required this.metadata,
  });
}

class SearchException implements Exception {
  final String message;
  SearchException(this.message);

  @override
  String toString() => 'SearchException: $message';
}