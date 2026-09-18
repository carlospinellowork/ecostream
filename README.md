# EcoStream

App Flutter para o mercado brasileiro que centraliza **assinaturas e serviços digitais
recorrentes**: quanto custam, quando vencem, quais valem a pena manter.

O problema é concreto — a pessoa média acumula de 8 a 15 assinaturas em cartões e
contas diferentes, e descobre quanto gasta só quando a fatura chega. O EcoStream
responde três perguntas:

1. **Quanto eu gasto?** Total mensal e anual, com o equivalente real de cada ciclo
   de cobrança.
2. **O que vem por aí?** Calendário de cobranças e avisos antes do débito.
3. **Onde estou perdendo dinheiro?** Serviços que você paga e não usa, streamings
   sobrepostos, planos anuais mais baratos, reajustes silenciosos.

---

## Estado atual

| Área | Situação |
|---|---|
| Autenticação | Local, com hash PBKDF2 e sessão persistida. Sem backend. |
| Dados | Persistidos no aparelho, por usuário. Sem sincronização. |
| Insights | 8 regras determinísticas, cobertas por testes. |
| Monetização | Freemium com trial. Compra **simulada** — ver abaixo. |
| Lembretes | Regra e UI completas; disparo no sistema operacional **ainda não plugado**. |

Dois pontos precisam de atenção antes de publicar nas lojas:

- **`LocalBillingRepository` não cobra de verdade.** Ele libera o Pro localmente como
  se a compra tivesse sido aprovada. É a implementação de desenvolvimento e demo.
  Substitua por uma sobre `in_app_purchase` ou RevenueCat — a interface
  `BillingRepository` existe exatamente para isso.
- **As notificações não disparam.** `InMemoryNotificationService` registra os
  agendamentos e loga, mas nada chega ao usuário. Ver `docs/NOTIFICACOES.md`.

---

## Rodando o projeto

Requer Flutter estável (canal `stable`) com Dart 3.13+ e JDK 17 para o build Android.

```bash
flutter pub get
flutter run
```

Na primeira execução, use **"Explorar sem criar conta"** na tela de login: isso cria
uma conta de demonstração real e semeia uma carteira de exemplo, com serviços sem uso
e planos anuais, para que o app tenha o que analisar.

### Verificação

```bash
flutter analyze --no-fatal-infos   # o mesmo que a CI roda
flutter test                        # suíte completa
flutter test --coverage
dart format lib test
```

---

## Arquitetura em uma tela

Organização **feature-first**, três camadas por feature, dependências só para dentro:

```
presentation  →  data  →  domain
```

```
lib/
├── main.dart                  # composition root
├── bootstrap.dart             # boot: locale, storage, captura de erro
├── core/                      # infra compartilhada (storage, erro, tema, rotas, utils)
└── features/
    ├── auth/                  # login, cadastro, sessão
    ├── billing/               # planos, direitos de acesso, paywall
    ├── subscriptions/         # CRUD, persistência, recorrência
    ├── insights/              # motor de análise financeira
    ├── reminders/             # regra de lembretes e agendamento
    ├── calendar/ dashboard/ profile/ navigation/ categories/
```

Estado com **Riverpod** (`StateNotifier` + estado imutável). Navegação com
**go_router**, incluindo `ShellRoute` para as abas — cada aba é uma rota real, então
deep link e botão "voltar" funcionam.

A regra de negócio que importa vive em classes puras e testadas:

| Classe | Responsabilidade |
|---|---|
| `FinancialCalculator` | conversão entre periodicidades de cobrança |
| `Recurrence` | aritmética de datas de cobrança (inclui o dia 31) |
| `InsightsEngine` | as 8 regras que geram as recomendações |
| `ReminderEngine` | o que notificar e quando |
| `Entitlements` | o que o plano do usuário libera |
| `PasswordHasher` | PBKDF2-HMAC-SHA256 |

---

## Monetização

Freemium. Gratuito entrega valor real; o Pro entrega a análise que economiza dinheiro.

| | Free | Pro |
|---|---|---|
| Assinaturas | até 5 | ilimitadas |
| Insights | básicos | completos |
| Lembretes | 1 por assinatura | múltiplos, com antecedência escolhida |
| Exportação CSV | — | sim |

Preços em `PricingCatalog` (`lib/features/billing/domain/plan.dart`). Trial de 7 dias.

O princípio do paywall: insight bloqueado **não é escondido** — aparece com o valor em
reais visível e o detalhe borrado. O argumento de venda é o número do próprio usuário,
não uma lista de recursos.

---

## Segurança e privacidade

- Nenhum dado sai do aparelho. Não há servidor.
- Senha nunca é gravada em texto puro: PBKDF2-HMAC-SHA256, 120 mil iterações, salt
  aleatório de 16 bytes por conta.
- Hash, salt e token de sessão ficam no Keystore (Android) / Keychain (iOS);
  perfil e assinaturas, no armazenamento local comum.
- Exclusão de conta apaga conta, credencial e todos os dados do usuário.
- Como não há sincronização, desinstalar o app apaga tudo. A exportação em CSV existe
  para o usuário guardar uma cópia.

---

## Documentação

- **[CLAUDE.md](CLAUDE.md)** — convenções, arquitetura e armadilhas. Leia antes de
  escrever código.
- **[docs/NOTIFICACOES.md](docs/NOTIFICACOES.md)** — como plugar as notificações reais.
- **[docs/MONETIZACAO.md](docs/MONETIZACAO.md)** — modelo de negócio e como ligar a
  cobrança real.
- **[docs/ROADMAP.md](docs/ROADMAP.md)** — o que vem depois, em ordem de impacto.
