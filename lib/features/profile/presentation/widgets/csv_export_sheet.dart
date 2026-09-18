import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../subscriptions/domain/csv_exporter.dart';
import '../../../subscriptions/presentation/controllers/subscription_controller.dart';

/// Exportação das assinaturas em CSV.
///
/// Copia para a área de transferência em vez de gravar arquivo: gravar exigiria
/// `path_provider` e `share_plus` — dois plugins nativos a mais — e a área de
/// transferência já resolve o caso real de colar numa planilha.
/// Ver `docs/ROADMAP.md` para a versão com compartilhamento de arquivo.
class CsvExportSheet extends ConsumerWidget {
  const CsvExportSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subscriptions = ref.watch(subscriptionControllerProvider).subscriptions;
    final csv = CsvExporter.subscriptionsToCsv(subscriptions);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SectionHeader(title: 'Exportar em CSV'),
            const SizedBox(height: 8),
            Text(
              '${subscriptions.length} '
              '${subscriptions.length == 1 ? 'assinatura' : 'assinaturas'} serão '
              'exportadas. Cole o conteúdo numa planilha para abrir em colunas.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  csv,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Copiar CSV',
              icon: Icons.copy_all_outlined,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: csv));
                if (!context.mounted) return;
                Navigator.of(context).pop();
                AppSnackBar.showSuccess(context, 'CSV copiado para a área de transferência.');
              },
            ),
          ],
        ),
      ),
    );
  }
}
