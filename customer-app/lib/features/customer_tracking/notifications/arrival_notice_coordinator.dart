import '../../../core/offline/offline_cache.dart';

const arrivalEvent = 'COURIER_ARRIVED';
const arrivalChannel = 'CERKA_ORDER_ARRIVAL';

/// One presentation decision for FCM and WebSocket, scoped to the signed-in user.
class ArrivalNoticeCoordinator {
  ArrivalNoticeCoordinator({required this.scope});
  final String scope;
  Future<void> Function(String orderId)? onNotice;
  final _pending = <String>{};
  final _tracking = <Object,
      ({
    String orderId,
    bool Function() isVisible,
    Future<void> Function() show
  })>{};

  Object watchTracking(String orderId,
      {required bool Function() isVisible,
      required Future<void> Function() show}) {
    final key = Object();
    _tracking[key] = (orderId: orderId, isVisible: isVisible, show: show);
    return key;
  }

  void unwatchTracking(Object key) => _tracking.remove(key);

  Future<void> receive(Map<String, dynamic> data) async {
    final orderId = data['orderId']?.toString();
    final deliveryId = data['deliveryId']?.toString();
    if (data['type'] != arrivalEvent ||
        orderId == null ||
        orderId.isEmpty ||
        deliveryId == null ||
        deliveryId.isEmpty) return;
    final key = 'arrivalShown:$scope:$deliveryId';
    if (!_pending.add(key)) return;
    try {
      if (await OfflineCache.read(key) == true) return;
      Future<void> Function()? show;
      for (final tracking in _tracking.values.toList().reversed) {
        if (tracking.orderId == orderId && tracking.isVisible()) {
          show = tracking.show;
          break;
        }
      }
      final general = onNotice;
      if (show != null) {
        await show();
      } else if (general != null) {
        await general(orderId);
      } else {
        return;
      }
      await OfflineCache.write(key, true);
    } finally {
      _pending.remove(key);
    }
  }
}
