import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'customCacheKey';

  static CustomCacheManager? _instance;
  factory CustomCacheManager() {
    return _instance ??= CustomCacheManager._();
  }

  CustomCacheManager._() : super(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

class PerformanceOptimizer {
  static final Map<String, Widget> _widgetCache = {};
  static final Map<String, dynamic> _dataCache = {};

  static Widget cacheWidget(String key, Widget widget) {
    if (!_widgetCache.containsKey(key)) {
      _widgetCache[key] = widget;
    }
    return _widgetCache[key]!;
  }

  static T? getCachedData<T>(String key) {
    return _dataCache[key] as T?;
  }

  static void cacheData(String key, dynamic data) {
    if (_dataCache.length > 50) {
      _dataCache.clear();
    }
    _dataCache[key] = data;
  }

  static void clearCache() {
    _widgetCache.clear();
    _dataCache.clear();
  }
}

class OptimizedFutureBuilder<T> extends StatelessWidget {
  final Future<T>? future;
  final T? initialData;
  final Widget Function(BuildContext context, T? data) builder;
  final Widget Function(BuildContext context, Object? error)? errorBuilder;
  final Widget? loadingWidget;
  final Duration? timeout;

  const OptimizedFutureBuilder({
    super.key,
    this.future,
    this.initialData,
    required this.builder,
    this.errorBuilder,
    this.loadingWidget,
    this.timeout,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: timeout != null ? future?.timeout(timeout!) : future,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ?? const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return errorBuilder?.call(context, snapshot.error) ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('오류가 발생했습니다: ${snapshot.error}'),
                  ],
                ),
              );
        }

        if (snapshot.hasData || initialData != null) {
          return builder(context, snapshot.data ?? initialData);
        }

        return loadingWidget ?? const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class OptimizedStreamBuilder<T> extends StatelessWidget {
  final Stream<T>? stream;
  final T? initialData;
  final Widget Function(BuildContext context, T? data) builder;
  final Widget Function(BuildContext context, Object? error)? errorBuilder;
  final Widget? loadingWidget;

  const OptimizedStreamBuilder({
    super.key,
    this.stream,
    this.initialData,
    required this.builder,
    this.errorBuilder,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && initialData == null) {
          return loadingWidget ?? const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return errorBuilder?.call(context, snapshot.error) ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('오류가 발생했습니다: ${snapshot.error}'),
                  ],
                ),
              );
        }

        return builder(context, snapshot.data);
      },
    );
  }
}

class OptimizedListView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final double? itemExtent;
  final Widget? separator;

  const OptimizedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.itemExtent,
    this.separator,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('데이터가 없습니다.'),
      );
    }

    return ListView.separated(
      controller: controller,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemExtent: itemExtent,
      itemCount: items.length,
      separatorBuilder: separator != null
          ? (context, index) => separator!
          : (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return itemBuilder(context, items[index], index);
      },
    );
  }
}

class LazyLoadBuilder extends StatefulWidget {
  final Widget Function(BuildContext context) builder;
  final Duration delay;

  const LazyLoadBuilder({
    super.key,
    required this.builder,
    this.delay = Duration.zero,
  });

  @override
  State<LazyLoadBuilder> createState() => _LazyLoadBuilderState();
}

class _LazyLoadBuilderState extends State<LazyLoadBuilder> {
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(widget.delay, () {
        if (mounted) {
          setState(() {
            _isLoaded = true;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const SizedBox.shrink();
    }
    return widget.builder(context);
  }
}