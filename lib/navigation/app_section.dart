import 'package:flutter/material.dart';

enum AppSection {
  today(
    label: 'Сегодня',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard_rounded,
  ),
  projects(
    label: 'Проекты',
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder_rounded,
  ),
  tasks(
    label: 'Задачи',
    icon: Icons.checklist_outlined,
    selectedIcon: Icons.checklist_rounded,
  ),
  notes(
    label: 'Заметки',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book_rounded,
  ),
  insights(
    label: 'Отчёты',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights_rounded,
  );

  const AppSection({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
