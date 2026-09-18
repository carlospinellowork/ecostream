import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';
import '../domain/reminder.dart';

/// Quem efetivamente agenda notificações no sistema operacional.
///
/// A regra de **o que** notificar é do `ReminderEngine`; aqui fica só o **como**.
/// Manter a fronteira permite trocar de plugin sem tocar em regra de negócio, e
/// testar a regra sem plataforma.
///
/// Ver `docs/NOTIFICACOES.md` para o passo a passo de plugar o
/// `flutter_local_notifications` de verdade.
abstract interface class NotificationService {
  /// Prepara o serviço. Deve ser idempotente.
  Future<void> initialize();

  /// Pede permissão ao usuário. Devolve se foi concedida.
  Future<bool> requestPermission();

  /// Substitui **toda** a agenda pela lista informada.
  ///
  /// É uma substituição, e não uma adição, de propósito: mudar uma assinatura
  /// muda vários lembretes de uma vez, e reconciliar item a item é onde nascem os
  /// avisos duplicados.
  Future<void> replaceSchedule(List<ScheduledReminder> reminders);

  Future<void> cancelAll();

  /// Lembretes atualmente agendados. Usado pela tela de diagnóstico.
  Future<List<ScheduledReminder>> pending();
}

/// Implementação **em memória**, ativa hoje.
///
/// Registra os agendamentos e loga, mas **não dispara nada no sistema operacional**.
/// Toda a UI e toda a regra de lembrete funcionam ponta a ponta contra ela.
///
/// A escolha é deliberada: o `flutter_local_notifications` exige plugin nativo,
/// desugaring no Gradle, permissões novas no manifesto e ajuste no Info.plist — e o
/// build Android deste projeto acabou de ser estabilizado (CLAUDE.md §12).
/// Trocar aqui é um PR isolado, com o APK verde antes de mergear.
class InMemoryNotificationService implements NotificationService {
  final List<ScheduledReminder> _scheduled = <ScheduledReminder>[];

  bool _initialized = false;

  @visibleForTesting
  List<ScheduledReminder> get scheduled => List.unmodifiable(_scheduled);

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    AppLogger.debug('Serviço de notificações em memória iniciado.', scope: 'reminders');
  }

  @override
  Future<bool> requestPermission() async {
    // Sem plataforma não há o que pedir; a UI trata como concedido para que o fluxo
    // de configuração possa ser percorrido inteiro.
    return true;
  }

  @override
  Future<void> replaceSchedule(List<ScheduledReminder> reminders) async {
    _scheduled
      ..clear()
      ..addAll(reminders);
    AppLogger.debug(
      '${reminders.length} lembretes agendados (em memória).',
      scope: 'reminders',
    );
  }

  @override
  Future<void> cancelAll() async {
    _scheduled.clear();
    AppLogger.debug('Lembretes cancelados.', scope: 'reminders');
  }

  @override
  Future<List<ScheduledReminder>> pending() async => List.unmodifiable(_scheduled);
}
