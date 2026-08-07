import 'dart:async';
import 'package:delivery_customer/features/courier/data/courier_repository.dart';
import 'package:delivery_customer/features/courier/tracking/domain/courier_location_update.dart';
import 'package:delivery_customer/features/courier/tracking/presentation/courier_tracking_controller.dart';
import 'package:delivery_customer/features/courier/tracking/services/courier_location_permission_service.dart';
import 'package:delivery_customer/features/courier/tracking/services/courier_location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePermission implements CourierLocationPermissionServiceContract {
  _FakePermission(this.result);
  CourierLocationPermissionResult result;

  @override
  Future<CourierLocationPermissionResult> ensurePermission() async => result;
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

class _FakeLocationService implements CourierLocationServiceContract {
  final controller = StreamController<CourierLocationEvent>.broadcast();
  bool active = false;
  int starts = 0;
  int stops = 0;
  int resumes = 0;
  String? startedDeliveryId;
  Completer<void>? startGate;

  @override
  Stream<CourierLocationEvent> get events => controller.stream;
  @override
  bool get isActive => active;
  @override
  CourierLocationUpdate? get lastValidLocation => null;
  @override
  Future<bool> start({required String deliveryId}) async {
    starts++;
    startedDeliveryId = deliveryId;
    await startGate?.future;
    active = true;
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
    active = false;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async => resumes++;
  @override
  Future<void> sendFinalLocation() async {}
}

void main() {
  late _FakePermission permission;
  late _FakeLocationService service;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    permission = _FakePermission(CourierLocationPermissionResult.granted);
    service = _FakeLocationService();
    container = ProviderContainer(overrides: [
      courierLocationPermissionServiceProvider.overrideWithValue(permission),
      courierLocationServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(() async {
      container.dispose();
      await service.controller.close();
    });
  });

  CourierTrackingController controller() =>
      container.read(courierTrackingControllerProvider.notifier);

  test('double start creates only one GPS stream', () async {
    service.startGate = Completer<void>();
    final first = controller().startTracking(deliveryId: 'delivery');
    final second = controller().startTracking(deliveryId: 'delivery');
    await Future<void>.delayed(Duration.zero);
    expect(service.starts, 1);
    service.startGate!.complete();
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(service.starts, 1);
  });

  test('stop releases the service', () async {
    await controller().startTracking(deliveryId: 'delivery');
    await controller().stopTracking();
    expect(service.active, isFalse);
    expect(service.stops, 1);
    expect(container.read(courierTrackingControllerProvider),
        isA<TrackingStopped>());
  });

  test('denied permission does not start GPS', () async {
    permission.result = CourierLocationPermissionResult.denied;
    expect(await controller().startTracking(), isFalse);
    expect(service.starts, 0);
    expect(container.read(courierTrackingControllerProvider),
        isA<TrackingPermissionDenied>());
  });

  test('disabled GPS does not start tracking', () async {
    permission.result = CourierLocationPermissionResult.gpsDisabled;
    expect(await controller().startTracking(), isFalse);
    expect(container.read(courierTrackingControllerProvider),
        isA<TrackingGpsDisabled>());
  });

  test('offline and backend errors are visible', () async {
    await controller().startTracking(deliveryId: 'delivery');
    service.controller.add(const CourierLocationEvent(
      CourierLocationEventType.offline,
      message: 'HTTP 503',
    ));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(courierTrackingControllerProvider),
        isA<TrackingOffline>());
    service.controller.add(const CourierLocationEvent(
      CourierLocationEventType.error,
      message: 'GPS error',
    ));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(courierTrackingControllerProvider),
        isA<TrackingError>());
  });

  test('resume asks the active service to flush retries', () async {
    await controller().startTracking(deliveryId: 'delivery');
    await controller().resumeTracking();
    expect(service.resumes, 1);
  });

  test('logout or expired token stops tracking', () async {
    await controller().startTracking(deliveryId: 'delivery');
    await controller().onSessionEnded();
    expect(service.active, isFalse);
    expect(container.read(courierTrackingControllerProvider),
        isA<TrackingStopped>());
  });

  test('terminal delivery stops tracking', () async {
    await controller().startTracking(deliveryId: 'delivery');
    await controller().synchronizeDelivery(const CourierDelivery(
      id: 'delivery',
      orderId: 'order',
      status: 'DELIVERED',
      deliveryType: 'PLATFORM_DELIVERY',
      pickupNotes: null,
      deliveryNotes: null,
      createdAt: '2026-07-28T00:00:00Z',
    ));
    expect(service.active, isFalse);
  });

  test('recovery keeps the explicitly persisted delivery among multiple active deliveries', () async {
    SharedPreferences.setMockInitialValues({'courier.deliveryId': 'delivery-2'});
    await controller().restoreFromBackend([
      delivery('delivery-1'),
      delivery('delivery-2'),
    ]);
    expect(service.startedDeliveryId, 'delivery-2');
  });

  test('recovery does not guess when multiple active deliveries have no persisted selection', () async {
    await controller().restoreFromBackend([
      delivery('delivery-1'),
      delivery('delivery-2'),
    ]);
    expect(service.starts, 0);
    expect(container.read(courierTrackingControllerProvider), isA<TrackingError>());
  });
}

CourierDelivery delivery(String id) => CourierDelivery(
      id: id,
      orderId: 'order-$id',
      status: 'IN_TRANSIT',
      deliveryType: 'PLATFORM_DELIVERY',
      pickupNotes: null,
      deliveryNotes: null,
      createdAt: '2026-08-07T00:00:00Z',
    );
