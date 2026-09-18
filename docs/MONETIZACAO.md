# Monetização

## O modelo

Freemium com trial de 7 dias. Duas ofertas: mensal (R$ 12,90) e anual (R$ 95,90).

Preços em `PricingCatalog` — `lib/features/billing/domain/plan.dart`.

### Por que esses números

**R$ 95,90/ano (R$ 7,99/mês).** A régua não é o preço de outros apps de finanças, é a
economia que o app entrega. Uma carteira típica de 10 assinaturas tem, entre serviço
sem uso e plano mensal onde existe anual, algo entre R$ 300 e R$ 800 por ano de gasto
evitável. Cobrar R$ 95,90 para destravar isso é uma proposta que se explica sozinha:
o paywall mostra o número do próprio usuário e o compara com o preço.

**R$ 12,90/mês existe para ancorar.** Doze meses de mensal custam R$ 154,80 — o anual
sai 38% mais barato, e a diferença aparece no card sem o usuário precisar calcular.
O anual também reduz churn e custo de transação.

**Trial de 7 dias, não 30.** O ciclo de decisão aqui é curto: em uma semana o usuário
cadastra as assinaturas, recebe o primeiro lembrete e vê os insights. Trinta dias só
adiariam a decisão.

### Por que o limite gratuito é 5 assinaturas

5 cobre com folga quem tem só streaming — essa pessoa usa o app de graça e fica.
Quem tem o problema que o EcoStream resolve (10, 15 assinaturas espalhadas por três
cartões) bate no limite **depois** de já ter visto o valor. O limite não é uma barreira
na entrada; é uma barreira no momento em que o produto já provou que funciona.

## Regras de implementação

`Entitlements.can(Feature)` é a **única** porta de autorização. Nunca compare
`plan == Plan.pro` na UI: o `switch` exaustivo em `Entitlements.can` força a decisão
quando uma `Feature` nova é criada, em vez de ela virar gratuita por omissão.

O limite de assinaturas é verificado no **controller**
(`SubscriptionController.addSubscription`), não na tela. O modal de cadastro não é a
única porta — há a ação rápida do dashboard e, no futuro, importação.

### Como o paywall é construído

A ordem da tela é deliberada:

1. **O número do usuário** — quanto ele deixa de economizar hoje.
2. **O que o Pro entrega** — em termos de resultado, não de recurso.
3. **Preço**, com o anual ancorado contra o mensal.
4. **Botão.**

Preço antes de valor percebido é o erro clássico de paywall.

Insight bloqueado **não é escondido**: `ProLockedOverlay` desfoca o detalhe e mostra
o valor em reais por cima. "R$ 412 por ano identificados" converte; "Faça upgrade"
não. Esconder o insight inteiro remove o motivo de assinar.

Cada entrada no paywall carrega a origem (`?origem=insight-annual_switch`,
`?origem=limite-assinaturas`, `?origem=perfil`...). É o que permite descobrir qual
gatilho converte quando houver analytics.

## Ligar a cobrança real

`LocalBillingRepository` **não cobra nada**. Ele grava o direito de acesso localmente
como se a compra tivesse sido aprovada. Serve para desenvolvimento, demo e para
validar toda a UI do paywall — e é o único ponto a trocar antes de publicar.

### Passos

1. **Criar os produtos nas lojas** com os ids de `PricingCatalog`:
   `ecostream_pro_monthly` e `ecostream_pro_annual`. A loja passa a ser a fonte de
   verdade do preço; o catálogo no código vira fallback de exibição.

2. **Implementar `BillingRepository`** sobre `in_app_purchase` ou RevenueCat, em
   `lib/features/billing/data/store_billing_repository.dart`. O que a implementação
   real precisa e a local não tem:
   - escutar o stream de atualizações de compra (a compra conclui **depois** que o
     método retorna);
   - tratar `PurchaseStatus.pending` — Pix e boleto na Play Store levam horas;
   - validar o recibo antes de liberar o acesso;
   - `restore` consultando a loja, não o armazenamento local;
   - tratar compra feita em outro aparelho com a mesma conta de loja.

3. **Trocar o provider**, em `entitlement_controller.dart`:

   ```dart
   final billingRepositoryProvider = Provider<BillingRepository>((ref) {
     return StoreBillingRepository(...);
   });
   ```

   Nenhuma outra camada muda. Se alguma precisar, é vazamento de camada.

4. **Validação de recibo.** Sem servidor, a validação local é burlável em aparelho
   com root. Para o MVP isso é um risco aceitável; a partir de volume, é preciso um
   endpoint que confira o recibo com a Apple/Google e guarde o direito de acesso.

### Sobre liberar o Pro sem cobrança em release

Hoje, num APK de release, tocar em "Assinar" libera o Pro sem nenhuma cobrança.
Enquanto o app não está publicado, isso não é um problema — é o comportamento de uma
implementação de demonstração. **Não publique nas lojas antes de trocar o
repositório**: além de não gerar receita, distribuir um app com compra simulada viola
as políticas de in-app purchase das duas lojas.

## O que medir quando houver analytics

Sem esses números, qualquer mudança de preço é chute:

- Conversão gratuito → trial, e trial → pago.
- Conversão por `origem` do paywall: qual gatilho traz assinante.
- Retenção D1/D7/D30, separada por gratuito e Pro.
- Assinaturas cadastradas por usuário na primeira semana — é o melhor preditor de
  quem vai bater no limite.
- Churn do mensal contra o anual.
- Economia realizada: quantos usuários de fato cancelaram algo depois de um insight.
  É a única métrica que mostra se o produto cumpre a promessa.

## Ideias descartadas por ora

- **Anúncios.** Um app que promete cortar gastos e exibe anúncio de assinatura destrói
  a própria credibilidade.
- **Vender dados de consumo.** Fora de questão: a privacidade é argumento de venda.
- **Links de afiliado para trocar de serviço.** Faz sentido (o app já sabe o que
  recomendar), mas cria conflito de interesse com o insight. Só com a comissão
  declarada na tela.
- **Plano família.** Exige backend e sincronização entre contas. Depende do item 1 do
  roadmap.
