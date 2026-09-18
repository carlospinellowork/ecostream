# CLAUDE.md — EcoStream

Guia de trabalho para agentes e devs neste repositório. Leia antes de escrever código.

---

## 1. O que é o EcoStream

App Flutter (Android/iOS) para o mercado brasileiro que centraliza **assinaturas e serviços
digitais recorrentes** do usuário: quanto custam, quando vencem, quais valem a pena manter.

A proposta de valor tem três pilares, nesta ordem de importância:

1. **Visibilidade** — o usuário descobre quanto realmente gasta por mês/ano.
2. **Antecipação** — ele é avisado antes da cobrança, não depois da fatura.
3. **Economia** — o app aponta, com números, o que cortar, pausar ou migrar para anual.

O pilar 3 é o que sustenta a monetização (ver §8). Toda feature nova deve responder
"a qual pilar isso serve?". Se não servir a nenhum, não entra.

Idioma do produto: **pt-BR**. Moeda padrão: **BRL**.

---

## 2. Comandos

```bash
flutter pub get                 # dependências
flutter analyze                 # lints — precisa passar limpo, zero issues
flutter test                    # testes unitários e de widget
flutter test --coverage         # com cobertura (lcov.info)
flutter run                     # executar em device/emulador
flutter build apk --release --no-tree-shake-icons --android-skip-build-dependency-validation
dart format lib test            # formatação (100 colunas, ver §5)
```

O CI (`.github/workflows/build_apk.yml`) roda `analyze` → `test` → `build apk`.
**Se `flutter analyze` falhar, o build não sai.** Rode localmente antes de commitar.

---

## 3. Arquitetura

Organização **feature-first** com três camadas por feature. Nada de pasta global por tipo
(`models/`, `screens/`) — tudo vive dentro da feature que o usa.

```
lib/
├── main.dart                   # composition root: ProviderScope + MaterialApp.router
├── core/                       # infraestrutura compartilhada, sem regra de negócio de feature
│   ├── constants/              # cores, strings, limites de plano
│   ├── error/                  # AppException, Result<T>
│   ├── logging/                # AppLogger
│   ├── router/                 # rotas e guarda de autenticação
│   ├── storage/                # KeyValueStore e SecureStore (interfaces + implementações)
│   ├── theme/                  # ThemeData claro/escuro + controller de ThemeMode
│   ├── utils/                  # formatadores, calculadora financeira, validadores
│   └── widgets/                # design system: botões, cards, campos, estados vazios
└── features/
    └── <feature>/
        ├── domain/             # modelos, enums, regras puras. ZERO import de Flutter*
        ├── data/               # repositórios: persistência, serialização, fontes de dados
        └── presentation/
            ├── controllers/    # Notifier/StateNotifier + providers Riverpod
            ├── screens/        # telas completas
            └── widgets/        # widgets só daquela feature
```

\* Exceção tolerada: `categories/domain/category_model.dart` importa `material` por causa de
`IconData`/`Color`. É catálogo de UI, não regra de negócio. Não replique o padrão.

### Regra de dependência

```
presentation  →  data  →  domain
```

Setas só apontam para a direita. `domain` não conhece `data` nem `presentation`.
`data` não importa widgets. Uma feature **não** importa `presentation/` de outra feature —
se precisar, importe `domain/` ou o provider do controller.

### Fluxo de dados

```
Screen (ConsumerWidget)
  ├─ ref.watch(xControllerProvider)          → lê estado
  └─ ref.read(xControllerProvider.notifier)  → dispara ação
        └─ Repository                         → I/O, devolve Result<T>
              └─ Store / DataSource           → SharedPreferences, SecureStorage, (futuro) API
```

---

## 4. Gerenciamento de estado — Riverpod

- Estado de feature: `StateNotifierProvider` com uma classe de estado **imutável**
  (`final` em tudo + `copyWith`).
- Valores derivados (totais, listas filtradas) ficam como **getters na classe de estado**,
  não recalculados na UI. Ver `SubscriptionState.totalMonthlySpend`.
- Nunca use `ref.watch` dentro do corpo de um `Provider` que constrói objeto caro e com
  ciclo de vida próprio (ex.: `GoRouter`) — isso recria o objeto e derruba a navegação.
  Use `refreshListenable` / `ref.listen`.
- Providers ficam no arquivo do controller, no fim do arquivo, com sufixo `Provider`.
- `ref.read` só dentro de callbacks; `ref.watch` só em `build`.

### Convenção de estado assíncrono

Estados que carregam de I/O expõem um `status` explícito, não booleanos soltos:

```dart
enum LoadStatus { initial, loading, ready, error }
```

Isso evita o clássico "isLoading true e errorMessage preenchido ao mesmo tempo".

Em `copyWith`, campos anuláveis que precisam ser **limpos** usam um sentinela, nunca
`campo ?? this.campo` — senão fica impossível voltar o valor para `null`. Ver
`AuthState.copyWith`.

---

## 5. Estilo de código

- **Idioma**: código, tipos e nomes em **inglês**. Strings de UI, comentários e docs em
  **português**. Nada de `nomeDoUsuario` ou `calcularTotal` no código.
- Largura de linha: **100 colunas**.
- Aspas simples (`prefer_single_quotes` está ativo).
- `const` sempre que possível — está como erro no analyzer.
- Um widget público por arquivo; widgets auxiliares privados (`_Nome`) no mesmo arquivo.
- Arquivos em `snake_case.dart`; classes em `PascalCase`; membros privados com `_`.
- Classes só de estáticos levam construtor privado: `AppColors._();`
- **Proibido** `withOpacity()` (depreciado) — use `.withValues(alpha: 0.12)`.
- **Proibido** `print()` — use `AppLogger`.
- Evite `BuildContext` após `await`: cheque `if (!context.mounted) return;`.

### Comentários

Comente **por quê**, não **o quê**. Regras de negócio e fórmulas financeiras merecem
`///` explicando a decisão (ex.: por que semanal vira `* 52 / 12` e não `* 4`).

---

## 6. Domínio financeiro — cuidados

Este é um app de dinheiro. Erros aqui destroem a confiança do usuário.

- **Nunca** compare `double` com `==` em teste; use `closeTo`.
- Toda conversão entre periodicidades passa por `FinancialCalculator`. Não replique a
  fórmula na UI.
- Semanal → mensal é `preco * 52 / 12` (52 semanas/ano), **não** `preco * 4`.
- Datas de cobrança: dia 31 não existe em fevereiro. Use `Recurrence.nextOccurrence`,
  que faz o *clamp* para o último dia do mês. Nunca construa `DateTime(y, m, 31)` na mão.
- Valores exibidos sempre via `CurrencyFormatter`, nunca `toStringAsFixed(2)` cru.
- Comparação de datas: normalize para meia-noite (`DateUtils.dateOnly`) antes de subtrair.

---

## 7. Autenticação

O MVP usa autenticação **local** (`AuthLocalDataSource`), sem backend:

- Senha **nunca** é armazenada em texto plano. Hash **PBKDF2-HMAC-SHA256**, 120k iterações,
  salt aleatório de 16 bytes por usuário (`PasswordHasher`).
- Credenciais e token de sessão vão para `SecureStore` (Keychain/Keystore).
  Perfil não sensível vai para `KeyValueStore` (SharedPreferences).
- A sessão é restaurada no boot: o router segura a navegação na `SplashScreen` enquanto
  `AuthStatus` for `unknown`. Sem isso o app pisca entre login e dashboard.
- O guarda de rota vive em `app_router.dart` → `redirect`. É a **única** fonte de verdade
  sobre quem pode ver o quê. Não replique checagem de login dentro de telas.

**Ao plugar um backend real** troque apenas `AuthRepository`. Nada em `presentation/`
deve precisar mudar — se precisar, o vazamento de camada é um bug.

---

## 8. Monetização

Modelo **freemium** com trial. Definido em `features/billing/domain/`.

| | Free | Pro |
|---|---|---|
| Assinaturas | até 5 | ilimitadas |
| Insights | básicos | completos (migração anual, duplicidade, custo/uso, projeção 5 anos) |
| Lembretes | 1 por assinatura | múltiplos + antecedência custom |
| Exportação | — | CSV |
| Trial | — | 7 dias |

Preços em `PricingCatalog`. Âncora de conversão: plano anual com desconto destacado.

### Regras de implementação

- **Todo** gate de feature passa por `Entitlements.can(...)`.
  Nunca cheque `plan == Plan.pro` espalhado pela UI.
- Ao bloquear algo, mostre **o valor perdido em reais**, não "recurso Pro".
  Ex.: "Você deixa R$ 312/ano na mesa" converte; "Faça upgrade" não.
- `BillingRepository` é uma **abstração**. A implementação atual (`LocalBillingRepository`)
  simula a compra e persiste localmente — é para desenvolvimento e demo.
  Para produção, implemente `BillingRepository` sobre `in_app_purchase` ou RevenueCat.
  **Nenhuma outra camada deve mudar.**

---

## 9. Lembretes / notificações

`ReminderEngine` (puro, testável) decide **o que** notificar e **quando**.
`NotificationService` é a interface que efetivamente agenda.

A implementação ativa hoje é `InMemoryNotificationService`: registra os agendamentos em
memória e loga. A UI e as regras funcionam ponta a ponta, mas **nada dispara no sistema
operacional ainda**.

Para plugar de verdade, ver `docs/NOTIFICACOES.md` — é uma mudança isolada em um arquivo
mais configuração de plataforma. Não espalhe chamadas de plugin pelo app.

---

## 10. Testes

- `test/` espelha a estrutura de `lib/`.
- Prioridade de cobertura: `domain/` e `core/utils/` (regra pura, barato e valioso testar) >
  `data/` > widgets.
- **Obrigatório** teste para: qualquer fórmula financeira, qualquer regra de insight,
  qualquer cálculo de data.
- Nome do teste descreve o comportamento em português:
  `test('converte ciclo semanal usando 52 semanas por ano', ...)`.
- Repositórios são testados com fakes in-memory de `KeyValueStore`/`SecureStore`
  (`test/fakes/`).

---

## 11. Git

- Branch base: `main`.
- **Conventional Commits** com escopo: `feat(auth): ...`, `fix(insights): ...`,
  `refactor(core): ...`, `test(subscriptions): ...`, `docs: ...`, `chore(ci): ...`.
- Assunto no imperativo, minúsculo, sem ponto final, até 72 caracteres.
- Um commit = uma mudança coerente. Não misture refactor com feature.
- Não commite `pubspec.lock` desatualizado após mexer em `pubspec.yaml`.

---

## 12. Armadilhas conhecidas deste repo

- O build Android foi estabilizado recentemente (AGP 8.11.1, Gradle 8.14, JDK 17).
  **Adicionar plugin nativo novo é mudança de risco** — faça em PR isolado, com o
  build de APK verde antes de mergear. Foi exatamente por isso que as notificações
  ficaram atrás de uma interface (§9) em vez de entrar direto.
- `flutter analyze` está estrito (ver `analysis_options.yaml`). Código que compila pode
  ainda assim quebrar o CI.
- Não existe backend. Tudo é local, por usuário, com chave derivada do `userId`.
  Qualquer feature que pressuponha sincronização entre dispositivos precisa ser desenhada
  junto com a API — não improvise.
- `flutter_secure_storage` não funciona em teste unitário (precisa de plataforma).
  Sempre injete um fake via override de provider.
