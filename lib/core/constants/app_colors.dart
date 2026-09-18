import 'package:flutter/material.dart';

/// Paleta de marca e de categorias.
///
/// **Não** use estas constantes para cor semântica de UI (texto, fundo, borda) —
/// para isso use `Theme.of(context).colorScheme`, que já responde ao tema claro/escuro.
/// O que fica aqui é o que não tem equivalente no `ColorScheme`: identidade visual,
/// cores de status financeiro e a cor de cada categoria.
class AppColors {
  AppColors._();

  // --- Marca ---
  static const Color primary = Color(0xFF0D9488); // Teal 600
  static const Color primaryDark = Color(0xFF2DD4BF); // Teal 300, para fundo escuro
  static const Color primaryDeep = Color(0xFF042F2E); // Teal 950
  static const Color primarySoftLight = Color(0xFFCCFBF1); // Teal 100
  static const Color primarySoftDark = Color(0xFF115E59); // Teal 800

  static const Color secondary = Color(0xFF6366F1); // Indigo 500
  static const Color secondaryLight = Color(0xFF818CF8); // Indigo 400
  static const Color accent = Color(0xFFF59E0B); // Amber 500

  // --- Status financeiro ---
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFF87171);
  static const Color info = Color(0xFF3B82F6);

  /// Cor de destaque do Pro. Dourado sinaliza plano pago sem competir com a marca.
  static const Color pro = Color(0xFFD97706);

  // --- Superfícies: tema claro ---
  static const Color bgLight = Color(0xFFF8FAFC); // Slate 50
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceMutedLight = Color(0xFFF1F5F9); // Slate 100
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200

  // --- Superfícies: tema escuro ---
  static const Color bgDark = Color(0xFF0F172A); // Slate 900
  static const Color cardDark = Color(0xFF1E293B); // Slate 800
  static const Color surfaceMutedDark = Color(0xFF334155); // Slate 700
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color borderDark = Color(0xFF334155);

  // --- Categorias ---
  static const Color catStreaming = Color(0xFFE50914);
  static const Color catGames = Color(0xFF107C41);
  static const Color catAI = Color(0xFF8E2DE2);
  static const Color catCloud = Color(0xFF0078D4);
  static const Color catSoftware = Color(0xFF00C4CC);
  static const Color catCursos = Color(0xFFFF6B6B);
  static const Color catAcademias = Color(0xFFF39C12);
  static const Color catJornais = Color(0xFF34495E);
  static const Color catOutros = Color(0xFF7F8C8D);
}
