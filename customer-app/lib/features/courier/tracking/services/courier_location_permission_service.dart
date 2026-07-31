import 'package:geolocator/geolocator.dart';

enum CourierLocationPermissionResult {
  granted,
  denied,
  permanentlyDenied,
  gpsDisabled,
}

abstract interface class CourierLocationPermissionServiceContract {
  Future<CourierLocationPermissionResult> ensurePermission();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class CourierLocationPermissionService
    implements CourierLocationPermissionServiceContract {
  @override
  Future<CourierLocationPermissionResult> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return CourierLocationPermissionResult.gpsDisabled;
    }
    var status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      status = await Geolocator.requestPermission();
    }
    if (status == LocationPermission.deniedForever) {
      return CourierLocationPermissionResult.permanentlyDenied;
    }
    return status == LocationPermission.whileInUse ||
            status == LocationPermission.always
        ? CourierLocationPermissionResult.granted
        : CourierLocationPermissionResult.denied;
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
