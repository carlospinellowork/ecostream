import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Categoria de assinatura.
///
/// Importa `material` por causa de [IconData] e [Color] — é um catálogo de
/// apresentação, não regra de negócio. Exceção documentada em CLAUDE.md §3; não
/// replique o padrão em outros domínios.
class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;

  /// Categoria usada quando o id não é reconhecido.
  ///
  /// Existe para que nenhuma tela precise de `orElse:` espalhado — um id órfão
  /// (vindo de dado antigo ou corrompido) renderiza como "Outros" em vez de lançar
  /// `StateError` no meio da lista.
  static const CategoryModel fallback = CategoryModel(
    id: 'cat_outros',
    name: 'Outros Serviços',
    icon: Icons.devices_other_outlined,
    color: AppColors.catOutros,
  );

  /// Busca por id, com fallback seguro.
  static CategoryModel byId(String? id) {
    if (id == null) return fallback;
    for (final category in defaultCategories) {
      if (category.id == id) return category;
    }
    return fallback;
  }

  static const List<CategoryModel> defaultCategories = <CategoryModel>[
    CategoryModel(
      id: 'cat_streaming',
      name: 'Streaming',
      icon: Icons.movie_outlined,
      color: AppColors.catStreaming,
    ),
    CategoryModel(
      id: 'cat_games',
      name: 'Games',
      icon: Icons.sports_esports_outlined,
      color: AppColors.catGames,
    ),
    CategoryModel(
      id: 'cat_ai',
      name: 'IA & Produtividade',
      icon: Icons.psychology_outlined,
      color: AppColors.catAI,
    ),
    CategoryModel(
      id: 'cat_cloud',
      name: 'Cloud & Storage',
      icon: Icons.cloud_outlined,
      color: AppColors.catCloud,
    ),
    CategoryModel(
      id: 'cat_software',
      name: 'Softwares & Design',
      icon: Icons.palette_outlined,
      color: AppColors.catSoftware,
    ),
    CategoryModel(
      id: 'cat_cursos',
      name: 'Cursos & Educação',
      icon: Icons.school_outlined,
      color: AppColors.catCursos,
    ),
    CategoryModel(
      id: 'cat_academias',
      name: 'Saúde & Academia',
      icon: Icons.fitness_center_outlined,
      color: AppColors.catAcademias,
    ),
    CategoryModel(
      id: 'cat_jornais',
      name: 'Notícias & Mídia',
      icon: Icons.newspaper_outlined,
      color: AppColors.catJornais,
    ),
    fallback,
  ];
}
