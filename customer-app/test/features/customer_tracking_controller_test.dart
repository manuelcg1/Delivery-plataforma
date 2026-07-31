import 'dart:async';

import 'package:delivery_customer/core/realtime/realtime_client.dart';
import 'package:delivery_customer/features/customer_tracking/data/customer_tracking_repository.dart';
import 'package:delivery_customer/features/customer_tracking/domain/customer_tracking_event.dart';
import 'package:delivery_customer/features/customer_tracking/domain/customer_tracking_response.dart';
import 'package:delivery_customer/features/customer_tracking/domain/tracking_location.dart';
import 'package:delivery_customer/features/customer_tracking/presentation/customer_tracking_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeTrackingRepository repository;
  late CustomerOrderTrackingController controller;

  setUp(() {
    repository = FakeTrackingRepository();
    controller = CustomerOrderTrackingController(repository);
  });

  tearDown(() {
    controller.dispose();
    repository.dispose();
  });

  test('start evita doble suscripción y carga REST después de suscribirse',
      () async {
    await controller.start('order');
    await controller.start('order');
    expect(repository.subscriptions, 1);
    expect(repository.calls, ['subscribe', 'get']);
    expect(controller.state.trackingActive, isTrue);
  });

  test('ignora evento de otro pedido y ubicación antigua', () async {
    await controller.start('order');
    repository.events.add(event('other', 2));
    repository.events.add(event('order', 0));
    await pumpEventQueue();
    expect(controller.state.tracking!.location!.latitude, 1);
  });

  test('aplica ubicación nueva y estado terminal detiene suscripción',
      () async {
    await controller.start('order');
    repository.events.add(event('order', 2));
    await pumpEventQueue();
    expect(controller.state.tracking!.location!.latitude, 2);
    repository.events
        .add(event('order', 3, status: 'DELIVERED', type: 'TRACKING_STOPPED'));
    await pumpEventQueue();
    expect(controller.state.trackingActive, isFalse);
    expect(repository.cancelled, isTrue);
  });

  test('desconexión activa polling y reconexión ejecuta REST y lo detiene',
      () async {
    await controller.start('order');
    repository.states.add(RealtimeConnectionState.disconnected);
    await pumpEventQueue();
    expect(controller.state.polling, isTrue);
    repository.states.add(RealtimeConnectionState.connected);
    await pumpEventQueue();
    expect(controller.state.polling, isFalse);
    expect(repository.gets, 2);
  });

  test('stop cancela streams y polling', () async {
    await controller.start('order');
    repository.states.add(RealtimeConnectionState.disconnected);
    await pumpEventQueue();
    await controller.stop();
    expect(repository.cancelled, isTrue);
    expect(controller.state.polling, isFalse);
  });
}

class FakeTrackingRepository implements CustomerTrackingRepositoryContract {
  final events = StreamController<CustomerTrackingEvent>.broadcast();
  final states = StreamController<RealtimeConnectionState>.broadcast();
  int subscriptions = 0, gets = 0;
  bool cancelled = false;
  final calls = <String>[];

  @override
  Future<CustomerOrderTracking> getTracking(String orderId) async {
    calls.add('get');
    gets++;
    return CustomerOrderTracking(
      orderId: orderId,
      deliveryStatus: 'IN_TRANSIT',
      trackingActive: true,
      stale: false,
      location: location(1),
    );
  }

  @override
  Future<CustomerTrackingSubscription> subscribeToTracking(
      String orderId) async {
    calls.add('subscribe');
    subscriptions++;
    return CustomerTrackingSubscription(
      events: events.stream,
      connectionStates: states.stream,
      cancel: () async => cancelled = true,
    );
  }

  @override
  String errorMessage(Object error) => error.toString();

  void dispose() {
    events.close();
    states.close();
  }
}

TrackingLocation location(int latitude) => TrackingLocation(
      latitude: latitude.toDouble(),
      longitude: -77,
      accuracy: 8,
      gpsTimestamp: DateTime.utc(2026, 7, 31, 15, 30, latitude),
    );

CustomerTrackingEvent event(String orderId, int latitude,
        {String status = 'IN_TRANSIT',
        String type = 'COURIER_LOCATION_UPDATED'}) =>
    CustomerTrackingEvent(
      type: type,
      orderId: orderId,
      deliveryStatus: status,
      location: location(latitude),
      publishedAt: DateTime.utc(2026, 7, 31, 15, 31, latitude),
    );
