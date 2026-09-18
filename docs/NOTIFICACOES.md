# Notificações — como plugar de verdade

## Situação

`ReminderEngine` decide **o que** avisar e **quando**, e está coberto por testes.
`NotificationService` é a interface que agenda. A implementação ativa é
`InMemoryNotificationService`: registra os agendamentos, loga e **não dispara nada no
sistema operacional**.

A UI inteira (tela de preferências, prévia dos próximos avisos, gates de plano)
funciona contra essa implementação.

## Por que não está plugado

`flutter_local_notifications` é um plugin nativo. Adicioná-lo exige, de uma vez:

- desugaring no Gradle (`coreLibraryDesugaringEnabled` + `desugar_jdk_libs`);
- permissões novas no `AndroidManifest.xml`, incluindo `POST_NOTIFICATIONS`
  (runtime, Android 13+) e `SCHEDULE_EXACT_ALARM`;
- receivers declarados no manifesto para o reagendamento após reboot;
- configuração no `AppDelegate.swift` e no `Info.plist`;
- `compileSdk` e AGP em versões mínimas específicas.

O build Android deste projeto foi estabilizado recentemente (três commits seguidos de
`fix(ci)`), e a convenção do repositório é que **plugin nativo novo entra em PR
isolado, com o APK verde antes do merge** (CLAUDE.md §12). Entregar a regra testada
atrás de uma interface é a parte que não tem risco; o acoplamento nativo é a parte que
precisa de aparelho na mão.

## Passo a passo

### 1. Dependências

```yaml
dependencies:
  flutter_local_notifications: ^19.0.0
  timezone: ^0.10.0
  flutter_timezone: ^4.0.0   # descobrir o fuso do aparelho
```

Confira no pub.dev a versão corrente e os requisitos mínimos de Flutter, AGP e
`compileSdk` antes de fixar — eles mudam entre majors.

### 2. Android

`android/app/build.gradle.kts`:

```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

`android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

E, dentro de `<application>`, os receivers que o plugin documenta para reagendar os
alarmes depois de um reboot. Sem eles, os lembretes desaparecem quando o usuário
reinicia o celular — falha silenciosa e difícil de notar em teste.

### 3. iOS

`ios/Runner/AppDelegate.swift`, antes de `GeneratedPluginRegistrant.register`:

```swift
if #available(iOS 10.0, *) {
  UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
}
```

### 4. A implementação

Crie `lib/features/reminders/data/local_notification_service.dart` implementando
`NotificationService`. Pontos que importam:

- **`initialize()` idempotente**: inicialize o `timezone` com o fuso real do aparelho
  (`flutter_timezone`), não com UTC. Um lembrete às 9h em UTC chega às 6h em Brasília.
- **`replaceSchedule` substitui, não soma**: `cancelAll()` e reagende a lista inteira.
  Reconciliar item a item é onde nascem os avisos duplicados. Use
  `ScheduledReminder.platformId`, que é determinístico justamente para isso.
- **`zonedSchedule`** com `androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle`.
- **Trate a permissão negada**: `requestPermission()` deve devolver `false`, e a UI
  precisa continuar navegável. Notificação é melhoria, não requisito.
- **Limite de 64 notificações pendentes no iOS**: uma carteira com 15 assinaturas e 3
  antecedências dá 45 — perto do teto. Se o Pro ganhar mais antecedências, agende
  apenas a janela dos próximos 60 dias e reagende quando o app abrir.

### 5. Ligar

Uma linha, em `reminder_controller.dart`:

```dart
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return LocalNotificationService();
});
```

Nada mais no app muda. Nos testes, mantenha o override para
`InMemoryNotificationService`.

### 6. Verificar

Não existe teste automatizado que prove que uma notificação chegou. Verifique em
aparelho físico:

- [ ] Aviso chega no horário configurado, com o app fechado.
- [ ] Muda o horário na tela de preferências → o aviso antigo não chega mais.
- [ ] Cancela uma assinatura → o aviso dela não chega.
- [ ] Reinicia o aparelho → os avisos futuros continuam agendados.
- [ ] Nega a permissão → o app continua utilizável e a tela explica o que aconteceu.
- [ ] Android 13+: o diálogo de permissão aparece no momento certo, e não no boot.

## Resumo semanal e alerta de reajuste

As preferências já existem (`notifyWeeklyDigest`, `notifyPriceIncrease`), mas o
`ReminderEngine` ainda não gera esses lembretes — só os de cobrança. São duas regras
novas no engine, com teste, e nenhuma mudança de plataforma.
