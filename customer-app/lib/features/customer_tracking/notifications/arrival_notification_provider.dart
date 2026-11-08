import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import 'arrival_notice_coordinator.dart';

final arrivalNoticeCoordinatorProvider = Provider((ref) {
  final user = ref.watch(authControllerProvider).value;
  return ArrivalNoticeCoordinator(scope: '${user?.tenantId}:${user?.id}');
});
