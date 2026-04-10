import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/services/api_service.dart';

part 'dashboard_provider.g.dart';

@riverpod
Future<Map<String, dynamic>> dashboardInsights(
  Ref ref,
  String instructorId,
) async {
  return ApiService().getDashboard(instructorId);
}
