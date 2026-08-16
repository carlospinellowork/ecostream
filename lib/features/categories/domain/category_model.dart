import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class CategoryModel {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  static const List<CategoryModel> defaultCategories = [
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
    CategoryModel(
      id: 'cat_outros',
      name: 'Outros Serviços',
      icon: Icons.devices_other_outlined,
      color: AppColors.catOutros,
    ),
  ];
}
