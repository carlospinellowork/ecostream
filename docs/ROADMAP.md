# Roadmap

Ordenado por impacto sobre os três pilares do produto (README), não por facilidade.

## Bloqueantes para publicar

Sem estes dois, o app não pode ir para as lojas.

1. **Cobrança real** — trocar `LocalBillingRepository` por uma implementação sobre
   `in_app_purchase`/RevenueCat. Ver `docs/MONETIZACAO.md`. Hoje o Pro é liberado sem
   cobrança, o que além de não gerar receita viola a política das lojas.
2. **Notificações reais** — plugar `flutter_local_notifications`. Ver
   `docs/NOTIFICACOES.md`. O pilar "antecipação" é metade da proposta de valor e hoje
   não entrega nada ao usuário.

## Alto impacto

3. **Ícone e splash próprios.** O app usa o ícone padrão do Flutter. É a primeira
   coisa que o usuário vê na loja e na gaveta de apps.
   `flutter_launcher_icons` + `flutter_native_splash`.

4. **Assinatura de release.** O `build.gradle.kts` ainda assina o release com a chave
   de debug (há um `TODO` do template no arquivo). Precisa de keystore próprio e
   dos segredos na CI.

5. **Onboarding de cadastro rápido.** Hoje o usuário cadastra assinatura por
   assinatura, em um formulário de oito campos. Um catálogo de serviços populares no
   Brasil — Netflix, Spotify, Globoplay, Game Pass, iFood Clube — com preço e ciclo
   pré-preenchidos derrubaria o atrito inicial, que é onde a maioria desiste.

6. **Alerta de reajuste e resumo semanal.** As preferências já existem na tela de
   lembretes, mas o `ReminderEngine` só gera avisos de cobrança. São duas regras
   novas no engine, com teste, sem mexer em plataforma.

7. **Gráfico de evolução do gasto.** `fl_chart` já está no `pubspec` e não é usado.
   Ver a curva subindo mês a mês é mais persuasivo que qualquer número isolado — e
   depende de guardar um histórico mensal, que hoje não existe.

## Médio impacto

8. **Backup e sincronização.** Hoje desinstalar o app apaga tudo, e a exportação em
   CSV é o único paliativo. Exige backend — é a mudança mais estrutural da lista e
   destrava plano família, multi-aparelho e validação de recibo no servidor.

9. **Exportação em arquivo.** A exportação atual copia para a área de transferência.
   Um `.csv` compartilhável exige `path_provider` + `share_plus`.

10. **Bloqueio por biometria.** Dado financeiro em app sem trava é desconfortável.
    `local_auth` é plugin nativo, então segue a regra do PR isolado.

11. **Widget de tela inicial** com a próxima cobrança. Alto valor percebido,
    implementação inteiramente nativa nas duas plataformas.

12. **Acessibilidade.** Nunca foi auditada. Contraste dos textos secundários sobre as
    superfícies, tamanho mínimo de alvo de toque (vários chips e ícones estão abaixo
    de 48dp) e rótulos de semântica nos botões só de ícone.

## Dívida técnica conhecida

- **`fl_chart` é dependência morta.** Ou usar no item 7, ou remover.
- **Sem testes de widget das telas principais.** Só o fluxo de login é coberto.
  Dashboard, insights e o formulário de assinatura não têm teste de UI.
- **`dart format` nunca rodou no projeto.** A CI avisa, mas não bloqueia
  (`continue-on-error`). Depois de uma formatação completa, vale tornar bloqueante e
  escalar as regras de estilo de `info` para `warning` em `analysis_options.yaml`.
- **`AuthLocalDataSource` serializa credencial como `salt|hash|iterations`.** Formato
  ad hoc, escolhido por ser mais simples que JSON dentro do secure storage. Se ganhar
  um quarto campo, migre para JSON.
- **Nenhuma migração de schema.** `SubscriptionModel.fromJson` tolera o formato antigo
  e valores desconhecidos, mas não há versionamento. Antes da primeira mudança
  incompatível, adicione um campo `schemaVersion`.
- **`InsightsEngine` recalcula tudo a cada `watch`.** É barato para 15 assinaturas e
  proposital (nada de cache dessincronizado), mas não escala para centenas.
- **Insights dispensados não são persistidos.** A chave
  `StorageKeys.dismissedInsights` existe, mas nada escreve nela — o usuário não
  consegue silenciar uma sugestão que já decidiu ignorar.
