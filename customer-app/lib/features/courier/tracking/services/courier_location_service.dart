import 'dart:async';
import 'dart:collection';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/courier_tracking_repository.dart';
import '../domain/courier_location_update.dart';
import '../../../../core/errors/app_exception.dart';

class CourierTrackingConfig {
  static const interval = Duration(seconds: 10);
  static const stoppedInterval = Duration(seconds: 45);
  static const minimumDistanceMeters = 15.0;
  static const maximumAccuracyMeters = 50.0;
  static const maximumPendingLocations = 30;
  static const maximumPendingAge = Duration(minutes: 2);
  static const retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];
}

enum CourierLocationEventType { sending, sent, offline, error }

class CourierLocationEvent {
  const CourierLocationEvent(this.type, {this.sentAt, this.message});
  final CourierLocationEventType type;
  final DateTime? sentAt;
  final String? message;
}

abstract interface class CourierLocationServiceContract {
  Stream<CourierLocationEvent> get events;
  bool get isActive;
  CourierLocationUpdate? get lastValidLocation;
  Future<bool> start();
  Future<void> sendFinalLocation();
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
}

class CourierLocationService implements CourierLocationServiceContract {
  CourierLocationService(this.repository);
  static const _trackingChannel = MethodChannel(
    'com.delivery.platform.customer/tracking',
  );
  final CourierTrackingRepository repository;
  final _events = StreamController<CourierLocationEvent>.broadcast();
  final Queue<CourierLocationUpdate> _pending = Queue();
  StreamSubscription<Position>? _subscription;
  Timer? _retryTimer;
  CourierLocationUpdate? _lastCaptured;
  CourierLocationUpdate? _lastSent;
  DateTime? _lastSentAt;
  Future<bool>? _startOperation;
  int _retryIndex = 0;
  bool _sending = false;

  @override
  Stream<CourierLocationEvent> get events => _events.stream;
  @override
  bool get isActive => _subscription != null;
  @override
  CourierLocationUpdate? get lastValidLocation => _lastCaptured;

  @override
  Future<bool> start() async {
    if (isActive) return true;
    final currentStart = _startOperation;
    if (currentStart != null) return currentStart;
    final operation = _start();
    _startOperation = operation;
    try {
      return await operation;
    } finally {
      if (identical(_startOperation, operation)) _startOperation = null;
    }
  }

  Future<bool> _start() async {
    _debug('tracking start requested');
    final initial = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    ).timeout(const Duration(seconds: 25));
    _subscription = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        intervalDuration: CourierTrackingConfig.interval,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'Cerka está compartiendo tu ubicación',
          notificationText: 'Entrega en curso',
          enableWakeLock: true,
          setOngoing: true,
        ),
      ),
    ).listen(_handle, onError: (Object error) {
      _events.add(CourierLocationEvent(
        CourierLocationEventType.error,
        message: error.toString(),
      ));
    });
    // Starting GPS must not depend on backend availability. The first point is
    // queued and sent asynchronously so a server failure cannot leave the UI
    // indefinitely in "Iniciando GPS".
    unawaited(_handle(initial, force: true));
    return true;
  }

  @override
  Future<void> sendFinalLocation() async {
    final location = _lastCaptured;
    if (location != null) await _enqueueAndFlush(location, force: true);
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _trackingChannel.invokeMethod<void>('stopLocationForeground');
      } on PlatformException catch (error) {
        _debug('foreground stop failed code=${error.code}');
      }
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    _pending.clear();
    _retryIndex = 0;
    _sending = false;
  }

  @override
  Future<void> pause() async {
    _subscription?.pause();
  }

  @override
  Future<void> resume() async {
    _subscription?.resume();
    if (_pending.isNotEmpty) {
      await _flush();
      return;
    }
    final location = _lastCaptured;
    if (location != null) {
      await _enqueueAndFlush(location, force: true);
    }
  }

  Future<void> _handle(Position position, {bool force = false}) async {
    if (!isActive && !force) return;
    final location = CourierLocationUpdate(
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed >= 0 ? position.speed * 3.6 : null,
      heading: position.heading >= 0 ? position.heading : null,
      accuracy: position.accuracy,
      altitude: position.altitude,
      provider: 'gps',
      gpsTimestamp: position.timestamp,
    );
    _debug(
      'position captured accuracy=${location.accuracy.toStringAsFixed(1)}m',
    );
    if (!location.isValid ||
        location.accuracy > CourierTrackingConfig.maximumAccuracyMeters) {
      return;
    }
    _lastCaptured = location;
    if (!force && !_shouldSend(location)) return;
    await _enqueueAndFlush(location, force: force);
  }

  bool _shouldSend(CourierLocationUpdate location) {
    final previous = _lastSent;
    if (previous == null) return true;
    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      location.latitude,
      location.longitude,
    );
    if (distance == 0) return false;
    final elapsed = DateTime.now().difference(_lastSentAt!);
    final moving = (location.speed ?? 0) >= 3;
    return distance >= CourierTrackingConfig.minimumDistanceMeters ||
        elapsed >=
            (moving
                ? CourierTrackingConfig.interval
                : CourierTrackingConfig.stoppedInterval);
  }

  Future<void> _enqueueAndFlush(
    CourierLocationUpdate location, {
    bool force = false,
  }) async {
    if (!force && _pending.any((item) => _same(item, location))) return;
    if (_pending.length >= CourierTrackingConfig.maximumPendingLocations) {
      _pending.removeFirst();
    }
    _pending.add(location);
    _debug('position queued pending=${_pending.length}');
    await _flush();
  }

  Future<void> _flush() async {
    if (_sending || _pending.isEmpty) return;
    _sending = true;
    try {
      while (_pending.isNotEmpty) {
        final location = _pending.first;
        if (DateTime.now().difference(location.gpsTimestamp) >
            CourierTrackingConfig.maximumPendingAge) {
          _pending.removeFirst();
          continue;
        }
        _events.add(const CourierLocationEvent(
          CourierLocationEventType.sending,
        ));
        _debug('location send started');
        try {
          await repository.sendLocation(location);
          _pending.removeFirst();
          _lastSent = location;
          _lastSentAt = DateTime.now();
          _retryIndex = 0;
          _events.add(CourierLocationEvent(
            CourierLocationEventType.sent,
            sentAt: _lastSentAt,
          ));
        } catch (error) {
          final offline=error is AppException && const {
            'NETWORK_UNAVAILABLE','NETWORK_TIMEOUT'
          }.contains(error.code);
          _events.add(CourierLocationEvent(
            offline ? CourierLocationEventType.offline : CourierLocationEventType.error,
            message: error.toString(),
          ));
          if(offline) _scheduleRetry();
          break;
        }
      }
    } finally {
      _sending = false;
    }
  }

  void _scheduleRetry() {
    if (_retryTimer?.isActive == true || !isActive) return;
    final index =
        _retryIndex.clamp(0, CourierTrackingConfig.retryDelays.length - 1);
    _retryIndex++;
    _retryTimer = Timer(
      CourierTrackingConfig.retryDelays[index],
      _flush,
    );
    _debug(
      'retry scheduled seconds=${CourierTrackingConfig.retryDelays[index].inSeconds}',
    );
  }

  bool _same(CourierLocationUpdate a, CourierLocationUpdate b) =>
      a.gpsTimestamp == b.gpsTimestamp ||
      (a.latitude == b.latitude && a.longitude == b.longitude);

  void _debug(String message) {
    if (kDebugMode) debugPrint('[CourierTracking] $message');
  }
}
