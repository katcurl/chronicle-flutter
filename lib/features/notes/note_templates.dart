class NoteTemplate {
  const NoteTemplate({
    required this.id,
    required this.title,
    required this.icon,
    required this.noteType,
    required this.content,
    this.defaultTags = const [],
    this.defaultProperties = const {},
  });

  final String id;
  final String title;
  final String icon;
  final String noteType;
  final String content;
  final List<String> defaultTags;
  final Map<String, String> defaultProperties;
}

const noteTemplates = <NoteTemplate>[
  NoteTemplate(
    id: 'blank',
    title: 'Пустая заметка',
    icon: '📝',
    noteType: 'note',
    content: '# Новая заметка\n\n',
  ),
  NoteTemplate(
    id: 'lecture',
    title: 'Лекция',
    icon: '🎓',
    noteType: 'lecture',
    defaultTags: ['лекция'],
    defaultProperties: {'audience': '', 'lesson_number': ''},
    content: '''# Тема лекции

## Цели занятия

После занятия ученики должны уметь:

- 
- 

## План

1. Введение
2. Основная часть
3. Примеры
4. Практика
5. Итоги

## Теория

## Формулы

\\[
E = mc^2
\\]

## Задачи

- [ ] Подготовить пример

## Домашнее задание

## Источники
''',
  ),
  NoteTemplate(
    id: 'research',
    title: 'Исследовательский журнал',
    icon: '🧬',
    noteType: 'research',
    defaultTags: ['исследование'],
    defaultProperties: {'object': '', 'method': '', 'result': ''},
    content: '''# Исследовательская запись

## Цель

## Материалы и методы

## Наблюдения

## Результат

## Интерпретация

## Следующий шаг

- [ ] 
''',
  ),
  NoteTemplate(
    id: 'literature',
    title: 'Конспект источника',
    icon: '📚',
    noteType: 'literature',
    defaultTags: ['литература'],
    defaultProperties: {'authors': '', 'year': '', 'doi': '', 'citekey': ''},
    content: '''# Название источника

## Главная идея

## Методы

## Основные результаты

## Важные детали

## Цитаты и страницы

## Связи

- [[Связанная заметка]]

## Мои выводы
''',
  ),
  NoteTemplate(
    id: 'meeting',
    title: 'Встреча',
    icon: '🤝',
    noteType: 'meeting',
    defaultTags: ['встреча'],
    defaultProperties: {'participants': '', 'date': ''},
    content: '''# Встреча

## Повестка

## Обсуждение

## Решения

## Следующие действия

- [ ] 
''',
  ),
];

String noteTypeLabel(String value) => switch (value) {
  'lecture' => 'Лекция',
  'research' => 'Исследование',
  'literature' => 'Источник',
  'meeting' => 'Встреча',
  _ => 'Заметка',
};

String noteTypeIcon(String value) => switch (value) {
  'lecture' => '🎓',
  'research' => '🧬',
  'literature' => '📚',
  'meeting' => '🤝',
  _ => '📝',
};
