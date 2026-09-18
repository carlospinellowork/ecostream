/// Um aviso agendado sobre uma cobrança futura.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.subscriptionId,
    required this.scheduledFor,
    required this.title,
    required this.body,
  });

  /// Id determinístico, derivado da assinatura e da antecedência.
  ///
  /// Precisa ser estável: reagendar é "cancelar o id anterior e criar de novo".
  /// Com id aleatório, cada recálculo deixaria um lembrete órfão no sistema e o
  /// usuário receberia o mesmo aviso várias vezes.
  final String id;

  final String subscriptionId;
  final DateTime scheduledFor;
  final String title;
  final String body;

  /// Id numérico exigido pelas APIs nativas de notificação.
  ///
  /// `hashCode` de String em Dart não é estável entre execuções, então derivamos de
  /// forma determinística e limitamos a 2^31-1, que é o teto do Android.
  int get platformId {
    var hash = 0;
    for (var i = 0; i < id.length; i++) {
      hash = (hash * 31 + id.codeUnitAt(i)) & 0x7fffffff;
    }
    return hash;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduledReminder &&
          other.id == id &&
          other.scheduledFor == scheduledFor;

  @override
  int get hashCode => Object.hash(id, scheduledFor);

  @override
  String toString() => 'ScheduledReminder($id, $scheduledFor)';
}

/// Preferências de lembrete do usuário.
class ReminderSettings {
  const ReminderSettings({
    this.enabled = true,
    this.leadDays = const <int>[1],
    this.hourOfDay = 9,
    this.notifyPriceIncrease = true,
    this.notifyWeeklyDigest = false,
  });

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    final rawLead = json['leadDays'];
    return ReminderSettings(
      enabled: json['enabled'] as bool? ?? true,
      leadDays: rawLead is List
          ? rawLead.whereType<int>().toSet().toList(growable: false)
          : const <int>[1],
      hourOfDay: json['hourOfDay'] as int? ?? 9,
      notifyPriceIncrease: json['notifyPriceIncrease'] as bool? ?? true,
      notifyWeeklyDigest: json['notifyWeeklyDigest'] as bool? ?? false,
    );
  }

  /// Interruptor geral.
  final bool enabled;

  /// Quantos dias antes avisar. Múltiplos valores são recurso do Pro.
  ///
  /// Ex.: `[3, 1]` avisa três dias antes e de novo na véspera.
  final List<int> leadDays;

  /// Hora do dia para o disparo, de 0 a 23.
  ///
  /// 9h por padrão: cedo o bastante para dar tempo de cancelar antes da cobrança,
  /// tarde o bastante para não acordar ninguém.
  final int hourOfDay;

  final bool notifyPriceIncrease;
  final bool notifyWeeklyDigest;

  ReminderSettings copyWith({
    bool? enabled,
    List<int>? leadDays,
    int? hourOfDay,
    bool? notifyPriceIncrease,
    bool? notifyWeeklyDigest,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      leadDays: leadDays ?? this.leadDays,
      hourOfDay: hourOfDay ?? this.hourOfDay,
      notifyPriceIncrease: notifyPriceIncrease ?? this.notifyPriceIncrease,
      notifyWeeklyDigest: notifyWeeklyDigest ?? this.notifyWeeklyDigest,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'leadDays': leadDays,
        'hourOfDay': hourOfDay,
        'notifyPriceIncrease': notifyPriceIncrease,
        'notifyWeeklyDigest': notifyWeeklyDigest,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderSettings &&
          other.enabled == enabled &&
          other.hourOfDay == hourOfDay &&
          other.notifyPriceIncrease == notifyPriceIncrease &&
          other.notifyWeeklyDigest == notifyWeeklyDigest &&
          _sameLeadDays(other.leadDays, leadDays);

  @override
  int get hashCode => Object.hash(
        enabled,
        Object.hashAllUnordered(leadDays),
        hourOfDay,
        notifyPriceIncrease,
        notifyWeeklyDigest,
      );

  static bool _sameLeadDays(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    final setA = a.toSet();
    return b.every(setA.contains);
  }
}
