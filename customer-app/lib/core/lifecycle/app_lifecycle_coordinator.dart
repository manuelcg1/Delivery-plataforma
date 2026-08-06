import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/courier/data/courier_repository.dart';
import '../../features/courier/tracking/presentation/courier_tracking_controller.dart';
import '../providers.dart';

enum AppConnectionStatus { online, checking, offline, backendUnavailable, sessionExpired, realtimeDisconnected }

final appConnectionStatusProvider=StateProvider<AppConnectionStatus>((_)=>AppConnectionStatus.checking);
final appLifecycleCoordinatorProvider=Provider((ref)=>AppLifecycleCoordinator(ref));

class AppLifecycleCoordinator {
  AppLifecycleCoordinator(this.ref);
  final Ref ref;
  Future<void>? _recovery;
  bool _backgroundLogged=false;

  Future<void> recover() {
    final active=_recovery;
    if(active!=null) return active;
    final operation=_recover();
    _recovery=operation;
    return operation.whenComplete(() { if(identical(_recovery,operation)) _recovery=null; });
  }

  Future<void> _recover() async {
    _backgroundLogged=false;
    _log('APP_RESUMED');
    final status=ref.read(appConnectionStatusProvider.notifier);
    status.state=AppConnectionStatus.checking;
    final api=ref.read(apiClientProvider);
    try {
      if(!await api.readiness()) {
        status.state=AppConnectionStatus.backendUnavailable;
        return;
      }
      await api.ensureValidSession();
      status.state=AppConnectionStatus.online;
      _log('NETWORK_RECOVERED');
      _log('REALTIME_RECONNECT_STARTED');
      try {
        await Future.wait([
          ref.read(realtimeClientProvider).reconnect(),
          ref.read(customerRealtimeClientProvider).reconnect(),
        ]);
        _log('REALTIME_RECONNECTED');
      } catch(_) {
        status.state=AppConnectionStatus.realtimeDisconnected;
      }
      ref.read(appRecoveryRevisionProvider.notifier).state++;
      final user=ref.read(authControllerProvider).value;
      if(user?.isCourier==true) {
        final deliveries=await CourierRepository(api).deliveries();
        await ref.read(courierTrackingControllerProvider.notifier).restoreFromBackend(deliveries);
        _log('COURIER_TRACKING_RESUMED');
      }
    } catch(error) {
      final parsed=api.exception(error);
      final authenticated=ref.read(authControllerProvider).value!=null;
      status.state=switch(parsed.code) {
        'AUTH_EXPIRED' when !authenticated=>AppConnectionStatus.online,
        'AUTH_EXPIRED'=>AppConnectionStatus.sessionExpired,
        'SESSION_REFRESH_FAILED'=>AppConnectionStatus.backendUnavailable,
        'NETWORK_UNAVAILABLE'||'NETWORK_TIMEOUT'=>AppConnectionStatus.offline,
        'SERVICE_UNAVAILABLE'=>AppConnectionStatus.backendUnavailable,
        _=>AppConnectionStatus.backendUnavailable,
      };
    }
  }

  void paused() {
    if(_backgroundLogged) return;
    _backgroundLogged=true;
    _log('APP_PAUSED');
  }
  void _log(String value) { if(kDebugMode) debugPrint('[Lifecycle] $value'); }
}

class AppLifecycleCoordinatorHost extends ConsumerStatefulWidget {
  const AppLifecycleCoordinatorHost({super.key,required this.child});
  final Widget child;
  @override ConsumerState<AppLifecycleCoordinatorHost> createState()=>_AppLifecycleCoordinatorHostState();
}

class _AppLifecycleCoordinatorHostState extends ConsumerState<AppLifecycleCoordinatorHost> with WidgetsBindingObserver {
  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(()=>ref.read(appLifecycleCoordinatorProvider).recover());
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    switch(state) {
      case AppLifecycleState.resumed: unawaited(ref.read(appLifecycleCoordinatorProvider).recover());
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden: ref.read(appLifecycleCoordinatorProvider).paused();
    }
  }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override Widget build(BuildContext context)=>widget.child;
}
