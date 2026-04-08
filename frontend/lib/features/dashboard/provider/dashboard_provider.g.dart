// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dashboardInsightsHash() => r'510644ce900586b029721bd7f5f5e64accb571dc';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [dashboardInsights].
@ProviderFor(dashboardInsights)
const dashboardInsightsProvider = DashboardInsightsFamily();

/// See also [dashboardInsights].
class DashboardInsightsFamily extends Family<AsyncValue<Map<String, dynamic>>> {
  /// See also [dashboardInsights].
  const DashboardInsightsFamily();

  /// See also [dashboardInsights].
  DashboardInsightsProvider call(
    String instructorId,
  ) {
    return DashboardInsightsProvider(
      instructorId,
    );
  }

  @override
  DashboardInsightsProvider getProviderOverride(
    covariant DashboardInsightsProvider provider,
  ) {
    return call(
      provider.instructorId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'dashboardInsightsProvider';
}

/// See also [dashboardInsights].
class DashboardInsightsProvider
    extends AutoDisposeFutureProvider<Map<String, dynamic>> {
  /// See also [dashboardInsights].
  DashboardInsightsProvider(
    String instructorId,
  ) : this._internal(
          (ref) => dashboardInsights(
            ref as DashboardInsightsRef,
            instructorId,
          ),
          from: dashboardInsightsProvider,
          name: r'dashboardInsightsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$dashboardInsightsHash,
          dependencies: DashboardInsightsFamily._dependencies,
          allTransitiveDependencies:
              DashboardInsightsFamily._allTransitiveDependencies,
          instructorId: instructorId,
        );

  DashboardInsightsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.instructorId,
  }) : super.internal();

  final String instructorId;

  @override
  Override overrideWith(
    FutureOr<Map<String, dynamic>> Function(DashboardInsightsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DashboardInsightsProvider._internal(
        (ref) => create(ref as DashboardInsightsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        instructorId: instructorId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Map<String, dynamic>> createElement() {
    return _DashboardInsightsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DashboardInsightsProvider &&
        other.instructorId == instructorId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, instructorId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DashboardInsightsRef
    on AutoDisposeFutureProviderRef<Map<String, dynamic>> {
  /// The parameter `instructorId` of this provider.
  String get instructorId;
}

class _DashboardInsightsProviderElement
    extends AutoDisposeFutureProviderElement<Map<String, dynamic>>
    with DashboardInsightsRef {
  _DashboardInsightsProviderElement(super.provider);

  @override
  String get instructorId => (origin as DashboardInsightsProvider).instructorId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
