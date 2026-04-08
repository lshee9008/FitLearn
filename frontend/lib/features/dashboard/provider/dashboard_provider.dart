import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';

part 'dashboard_provider.g.dart';

@riverpod
Future<Map<String, dynamic>> dashboardInsights(
  Ref ref,
  String instructorId,
) async {
  final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final res = await dio.get(ApiConstants.dashboard(instructorId));
  return res.data as Map<String, dynamic>;
}
