import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/core/providers/service_providers.dart';

class NotificationPermissionsNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final service = ref.watch(notificationServiceProvider);
    return service.hasPermissions();
  }

  Future<void> refreshPermissions() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(notificationServiceProvider).hasPermissions());
  }

  Future<void> requestPermissions() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(notificationServiceProvider).requestPermissions());
  }
}

final notificationPermissionsProvider = AsyncNotifierProvider<NotificationPermissionsNotifier, bool>(
  NotificationPermissionsNotifier.new,
);
