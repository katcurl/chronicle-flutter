import 'package:flutter/material.dart';

const taskStatuses = <(String, String, IconData)>[
  ('next', 'Далее', Icons.arrow_forward_rounded),
  ('doing', 'В работе', Icons.timelapse_rounded),
  ('blocked', 'Ожидает', Icons.pause_circle_outline_rounded),
  ('done', 'Готово', Icons.check_circle_outline_rounded),
];

String taskStatusLabel(String value) =>
    taskStatuses
        .firstWhere(
          (item) => item.$1 == value,
          orElse: () => taskStatuses.first,
        )
        .$2;

const taskPriorities = <(int, String, IconData)>[
  (0, 'Низкий', Icons.keyboard_arrow_down_rounded),
  (1, 'Обычный', Icons.remove_rounded),
  (2, 'Высокий', Icons.keyboard_arrow_up_rounded),
  (3, 'Срочный', Icons.priority_high_rounded),
];

String taskPriorityLabel(int value) =>
    taskPriorities
        .firstWhere((item) => item.$1 == value, orElse: () => taskPriorities[1])
        .$2;

IconData taskPriorityIcon(int value) =>
    taskPriorities
        .firstWhere((item) => item.$1 == value, orElse: () => taskPriorities[1])
        .$3;

Color taskPriorityColor(BuildContext context, int value) {
  final colors = Theme.of(context).colorScheme;
  return switch (value) {
    3 => colors.error,
    2 => colors.tertiary,
    0 => colors.onSurfaceVariant,
    _ => colors.primary,
  };
}

String shortDate(DateTime? value) {
  if (value == null) return 'Без срока';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

bool isOverdue(DateTime? value) {
  if (value == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(value.year, value.month, value.day);
  return date.isBefore(today);
}
