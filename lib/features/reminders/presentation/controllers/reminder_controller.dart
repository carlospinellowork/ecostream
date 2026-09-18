import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/storage/key_value_store.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../billing/domain/entitlements.dart';
import '../../../billing/domain/plan.dart';
import '../../../subscriptions/domain/subscription_model.dart';
import '../../../subscriptions/presentation/controllers/subscription_controller.dart';
import '../../data/notification_service.dart';
import '../../domain/reminder.dart';
import '../../domain/reminder_engine.dart';

@immutable
class ReminderState {
  const ReminderState({
    this.settings = const ReminderSettings(),
    this.scheduled = const <ScheduledReminder>[],
    this.permissionGranted = false,
  });

  final ReminderSettings settings;
  final List<ScheduledReminder> scheduled;
  final bool permissionGranted;

  ReminderState copyWith({
    ReminderSettings? settings,
    List<ScheduledReminder>? scheduled,
    bool? permissionGranted,
  }) {
    return ReminderState(
      settings: settings ?? this.settings,
      scheduled: scheduled ?? this.scheduled,
      permissionGranted: permissionGranted ?? this.permissionGranted,
    );
  }
}

class ReminderController extends StateNotifier<ReminderState> {
  ReminderController({
    required KeyValueStore store,
    required NotificationService service,
    required String? userId,
    required DateTime Function() clock,
  })  : _store = store,
        _service = service,
        _userId = userId,
        _clock = clock,
        super(const ReminderState()) {
    if (_userId != null) _load();
  }

  final KeyValueStore _store;
  final NotificationService _service;
  final String? _userId;
  final DateTime Function() _clock;

  static const ReminderEngine _engine = ReminderEngine();

  void _load() {
    final userId = _userId;
    if (userId == null) return;

    final json = _store.getJson(StorageKeys.reminderSettings(userId));
    if (json != null) {
      state = state.copyWith(settings: ReminderSettings.fromJson(json));
    }
  }

  Future<bool> requestPermission() async {
    await _service.initialize();
    final granted = await _service.requestPermission();
    if (!mounted) return granted;
    state = state.copyWith(permissionGranted: granted);
    return granted;
  }

  /// Recalcula e reagenda tudo a partir das assinaturas atuais.
  ///
  /// Chamado sempre que uma assinatura ou uma preferência muda. Barato, porque o
  /// cálculo é puro — e reconstruir do zero elimina a classe inteira de bugs de
  /// "sobrou um lembrete de algo que já foi cancelado".
  Future<void> reschedule(List<SubscriptionModel> subscriptions) async {
    await _service.initialize();

    final reminders = _engine.buildSchedule(
      subscriptions: subscriptions,
      settings: state.settings,
      now: _clock(),
    );

    await _service.replaceSchedule(reminders);
    if (!mounted) return;
    state = state.copyWith(scheduled: reminders);
  }

  Future<void> updateSettings(
    ReminderSettings settings, {
    required List<SubscriptionModel> subscriptions,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    state = state.copyWith(settings: settings);
    await _store.setJson(StorageKeys.reminderSettings(userId), settings.toJson());
    await reschedule(subscriptions);
  }

  /// Aplica as antecedências permitidas pelo plano.
  ///
  /// No plano gratuito só existe um aviso, na véspera. Manter a normalização aqui —
  /// e não na tela — evita que um caminho alternativo de UI conceda um recurso pago.
  ReminderSettings normalizeForPlan(
    ReminderSettings settings,
    Entitlements entitlements,
  ) {
    if (entitlements.can(Feature.customReminders, now: _clock())) return settings;
    return settings.copyWith(
      leadDays: const <int>[FreePlanLimits.fixedReminderLeadDays],
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return InMemoryNotificationService();
});

final reminderControllerProvider =
    StateNotifierProvider<ReminderController, ReminderState>((ref) {
  return ReminderController(
    store: ref.watch(keyValueStoreProvider),
    service: ref.watch(notificationServiceProvider),
    userId: ref.watch(currentUserProvider)?.id,
    clock: ref.watch(clockProvider),
  );
});

/// Mantém a agenda de lembretes sincronizada com as assinaturas.
///
/// É um provider "observador": ninguém lê o valor dele, mas ele reage a cada
/// mudança na lista de assinaturas e reagenda. Sem isso, cadastrar uma assinatura
/// não criaria lembrete até o app ser reaberto.
final reminderSyncProvider = Provider<void>((ref) {
  final subscriptions = ref.watch(activeSubscriptionsProvider);
  final controller = ref.watch(reminderControllerProvider.notifier);
  // `ref.watch` do estado garante que mudar a preferência também reagende.
  ref.watch(reminderControllerProvider.select((s) => s.settings));

  Future<void>.microtask(() => controller.reschedule(subscriptions));
});
