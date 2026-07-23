import '../../models/app_models.dart';

class ProjectResearchTemplate {
  const ProjectResearchTemplate({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.researchGoal,
    this.researchQuestions = const <String>[],
    this.knownFindings = const <String>[],
    this.openChecks = const <String>[],
  });

  final String id;
  final String title;
  final String emoji;
  final String description;
  final String researchGoal;
  final List<String> researchQuestions;
  final List<String> knownFindings;
  final List<String> openChecks;
}

const projectResearchTemplates = <ProjectResearchTemplate>[
  ProjectResearchTemplate(
    id: 'open-research',
    title: 'Свободное исследование',
    emoji: '🔬',
    description: 'Гибкая структура для вопроса, материалов и результатов.',
    researchGoal: 'Сформулировать, что именно должно стать понятнее или доказано.',
    researchQuestions: <String>[
      'Какой главный вопрос проекта?',
      'Какие наблюдения могут изменить текущую гипотезу?',
    ],
    openChecks: <String>[
      'Уточнить критерий, по которому результат считается убедительным.',
    ],
  ),
  ProjectResearchTemplate(
    id: 'computational-study',
    title: 'Вычислительное исследование',
    emoji: '🧬',
    description: 'Для моделирования, анализа траекторий и сравнения методов.',
    researchGoal: 'Сопоставить модели, метрики и устойчивые состояния системы.',
    researchQuestions: <String>[
      'Какие состояния или кластеры воспроизводятся разными методами?',
      'Какие метрики действительно различают состояния?',
      'Какие результаты чувствительны к параметрам расчёта?',
    ],
    knownFindings: <String>[
      'Зафиксировать исходные структуры, версии программ и параметры запуска.',
    ],
    openChecks: <String>[
      'Проверить воспроизводимость на независимом запуске.',
      'Проверить альтернативную метрику или референс.',
    ],
  ),
  ProjectResearchTemplate(
    id: 'experimental-study',
    title: 'Экспериментальное исследование',
    emoji: '🧪',
    description: 'Для серии экспериментов без навязанного лабораторного workflow.',
    researchGoal: 'Проверить гипотезу серией связанных наблюдений и контролей.',
    researchQuestions: <String>[
      'Какой результат поддержит гипотезу?',
      'Какой результат её опровергнет?',
      'Какие контроли необходимы для интерпретации?',
    ],
    openChecks: <String>[
      'Зафиксировать положительные и отрицательные контроли.',
      'Проверить повторяемость результата.',
    ],
  ),
  ProjectResearchTemplate(
    id: 'literature-review',
    title: 'Обзор литературы',
    emoji: '📚',
    description: 'Для сборки карты поля, противоречий и пробелов в литературе.',
    researchGoal: 'Собрать проверяемую картину того, что известно по теме.',
    researchQuestions: <String>[
      'В чём согласны основные источники?',
      'Где результаты расходятся и почему?',
      'Какие вопросы остаются без надёжного ответа?',
    ],
    openChecks: <String>[
      'Найти первичные источники для ключевых утверждений.',
      'Проверить свежие обзоры и отрицательные результаты.',
    ],
  ),
];

List<String> projectResearchLines(String raw) {
  final result = <String>[];
  final seen = <String>{};
  for (final line in raw.split('\n')) {
    final normalized = line
        .trim()
        .replaceFirst(RegExp(r'^[-*•]\s*'), '')
        .trim();
    if (normalized.isEmpty) continue;
    if (seen.add(normalized.toLowerCase())) result.add(normalized);
  }
  return result;
}

String projectResearchLinesText(Iterable<String> values) => values.join('\n');

List<String> projectAttachmentPaths(Iterable<Note> notes) {
  final result = <String>[];
  final seen = <String>{};
  final pattern = RegExp(
    r'!?\[(?:\\.|[^\]])*\]\(\s*(?:<([^>]+)>|([^\s)]+))',
    multiLine: true,
  );
  for (final note in notes) {
    for (final match in pattern.allMatches(note.body)) {
      var target = (match.group(1) ?? match.group(2) ?? '').trim();
      try {
        target = Uri.decodeComponent(target);
      } on Object {
        // Keep malformed targets visible instead of dropping project material.
      }
      target = target.replaceAll('\\', '/');
      final marker = target.indexOf('Attachments/');
      if (marker < 0) continue;
      final normalized = target.substring(marker).split(RegExp(r'[?#]')).first;
      if (normalized.split('/').any((segment) => segment.isEmpty || segment == '..')) {
        continue;
      }
      if (seen.add(normalized.toLowerCase())) result.add(normalized);
    }
  }
  result.sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
  return result;
}
