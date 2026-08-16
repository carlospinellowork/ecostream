import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Cores Primárias e Secundárias
  static const Color primary = Color(0xFF0D9488); // Teal Emerald
  static const Color primaryDark = Color(0xFF14B8A6);
  static const Color secondary = Color(0xFF6366F1); // Indigo
  static const Color accent = Color(0xFFF59E0B); // Amber

  // Indicadores Financeiros e Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Background e Surfaces - Light Mode
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Background e Surfaces - Dark Mode
  static const Color bgDark = Color(0xFF0F172A); // Slate 900
  static const Color cardDark = Color(0xFF1E293B); // Slate 800
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color borderDark = Color(0xFF334155);

  // Categorias (Paleta de cores para ícones/tags)
  static const Color catStreaming = Color(0xFFE50914); // Vermelho Netflix
  static const Color catGames = Color(0xFF107C41); // Verde Xbox
  static const Color catAI = Color(0xFF8E2DE2); // Roxo IA
  static const Color catCloud = Color(0xFF0078D4); // Azul Cloud
  static const Color catSoftware = Color(0xFF00C4CC); // Teal Canva
  static const Color catCursos = Color(0xFFFF6B6B);
  static const Color catAcademias = Color(0xFFF39C12);
  static const Color catJornais = Color(0xFF34495E);
  static const Color catOutros = Color(0xFF7F8C8D);
}
