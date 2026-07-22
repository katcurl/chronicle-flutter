class NoteTemplate {
  const NoteTemplate({
    required this.id,
    required this.title,
    required this.icon,
    required this.noteType,
    required this.content,
    this.category = '',
    this.defaultTags = const [],
    this.defaultProperties = const {},
    this.isCustom = false,
  });

  final String id;
  final String title;
  final String icon;
  final String noteType;
  final String content;
  final String category;
  final List<String> defaultTags;
  final Map<String, String> defaultProperties;
  final bool isCustom;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'icon': icon,
    'noteType': noteType,
    'content': content,
    'category': category,
    'defaultTags': defaultTags,
    'defaultProperties': defaultProperties,
    'isCustom': isCustom,
  };

  factory NoteTemplate.fromJson(Map<String, Object?> json) {
    final rawTags = json['defaultTags'];
    final rawProperties = json['defaultProperties'];
    return NoteTemplate(
      id: (json['id'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString().trim(),
      icon: (json['icon'] ?? '📝').toString().trim(),
      noteType: (json['noteType'] ?? 'note').toString().trim(),
      content: (json['content'] ?? '').toString(),
      category: (json['category'] ?? '').toString().trim(),
      defaultTags:
          rawTags is Iterable
              ? rawTags
                  .map((item) => item.toString().trim())
                  .where((item) => item.isNotEmpty)
                  .toList(growable: false)
              : const <String>[],
      defaultProperties:
          rawProperties is Map
              ? <String, String>{
                for (final entry in rawProperties.entries)
                  if (entry.key.toString().trim().isNotEmpty)
                    entry.key.toString().trim(): entry.value.toString(),
              }
              : const <String, String>{},
      isCustom: json['isCustom'] == true,
    );
  }
}

const laboratoryNoteTemplates = <NoteTemplate>[
  NoteTemplate(
    id: 'lab_day',
    title: 'Лабораторный день',
    icon: '🧪',
    noteType: 'lab_day',
    defaultTags: ['лаборатория', 'журнал'],
    defaultProperties: {'date': '', 'operator': '', 'location': ''},
    content: '''# Лабораторный день

## Цели на день

- [ ]

## Образцы и материалы

| ID / название | Состояние в начале | Что сделано | Состояние в конце |
| --- | --- | --- | --- |
|  |  |  |  |

## Ход работы

### Время — действие

## Наблюдения

## Отклонения и проблемы

## Полученные файлы и данные

-

## Итоги

## Следующий шаг

- [ ]
''',
  ),
  NoteTemplate(
    id: 'experiment',
    title: 'Эксперимент',
    icon: '⚗️',
    noteType: 'experiment',
    defaultTags: ['лаборатория', 'эксперимент'],
    defaultProperties: {
      'date': '',
      'operator': '',
      'sample_id': '',
      'method': '',
    },
    content: '''# Эксперимент

## Исследовательский вопрос

## Гипотеза

## Образцы, реагенты и оборудование

| Материал | ID / партия | Количество | Примечание |
| --- | --- | --- | --- |
|  |  |  |  |

## План и контролируемые параметры

| Параметр | Значение | Допуск |
| --- | --- | --- |
|  |  |  |

## Протокол

1.

## Наблюдения по ходу работы

## Результаты

## Отклонения от протокола

## Интерпретация

## Вывод

## Следующий эксперимент

- [ ]
''',
  ),
  NoteTemplate(
    id: 'sample',
    title: 'Паспорт образца',
    icon: '🧫',
    noteType: 'sample',
    defaultTags: ['лаборатория', 'образец'],
    defaultProperties: {
      'sample_id': '',
      'material': '',
      'concentration': '',
      'buffer': '',
      'storage': '',
    },
    content: '''# Паспорт образца

## Идентификация

- **ID образца:**
- **Название / объект:**
- **Проект:**
- **Дата получения:**
- **Ответственный:**

## Состав и состояние

- **Концентрация:**
- **Объём:**
- **Буфер / растворитель:**
- **pH:**
- **Добавки:**
- **Температура:**

## Происхождение и подготовка

## История образца

| Дата | Действие | Условия | Остаток / новое состояние |
| --- | --- | --- | --- |
|  |  |  |  |

## Контроль качества

## Хранение

- **Место:**
- **Температура:**
- **Циклы заморозки-разморозки:**
- **Срок использования:**

## Связанные эксперименты

- [[Эксперимент]]
''',
  ),
  NoteTemplate(
    id: 'protein_purification',
    title: 'Экспрессия и очистка',
    icon: '🧬',
    noteType: 'protein_purification',
    defaultTags: ['лаборатория', 'белок', 'очистка'],
    defaultProperties: {
      'construct': '',
      'host': '',
      'batch': '',
      'date': '',
    },
    content: '''# Экспрессия и очистка белка

## Конструкт и штамм

- **Белок / конструкт:**
- **Вектор:**
- **Сайт протеазы / метка:**
- **Штамм:**
- **Антибиотик:**

## Экспрессия

| Параметр | Значение |
| --- | --- |
| Объём культуры |  |
| Температура роста |  |
| OD при индукции |  |
| Индуктор и концентрация |  |
| Температура после индукции |  |
| Время экспрессии |  |

## Сбор и лизис

- **Масса осадка:**
- **Буфер лизиса:**
- **Метод лизиса:**
- **Условия центрифугирования:**

## Хроматография

| Этап / колонка | Буфер | Фракции | Наблюдения |
| --- | --- | --- | --- |
|  |  |  |  |

## Расщепление метки и дополнительная очистка

## Аналитика фракций

- **SDS-PAGE:**
- **Концентрация:**
- **Выход:**
- **Чистота:**

## Финальный образец

- **Буфер:**
- **Концентрация:**
- **Объём:**
- **Условия хранения:**

## Проблемы и решения

## Следующий шаг

- [ ]
''',
  ),
  NoteTemplate(
    id: 'nmr_experiment',
    title: 'ЯМР-эксперимент',
    icon: '🧲',
    noteType: 'nmr_experiment',
    defaultTags: ['лаборатория', 'ЯМР'],
    defaultProperties: {
      'sample_id': '',
      'spectrometer': '',
      'pulse_sequence': '',
      'temperature_k': '',
    },
    content: '''# ЯМР-эксперимент

## Образец

- **ID образца:**
- **Белок / молекула:**
- **Концентрация:**
- **Объём и пробирка:**
- **Буфер:**
- **Изотопное мечение:**

## Спектрометр и зонд

- **Спектрометр / частота:**
- **Зонд:**
- **Температура, K:**
- **Дата и оператор:**

## Эксперимент

| Параметр | Значение |
| --- | --- |
| Импульсная последовательность |  |
| Размерность |  |
| Число сканов |  |
| Точки / инкременты |  |
| Спектральные ширины |  |
| Задержка релаксации |  |
| Общее время |  |

## Настройка и контроль качества

- **Lock / shim:**
- **Настройка импульсов:**
- **Уровень сигнала:**
- **Артефакты:**

## Обработка

- **ПО:**
- **Аподизация:**
- **Zero filling:**
- **Фазировка и baseline:**
- **Химический сдвиг / референс:**

## Наблюдения и результат

## Файлы

- **Raw data:**
- **Processed data:**
- **Рисунки / таблицы:**

## Следующий шаг

- [ ]
''',
  ),
  NoteTemplate(
    id: 'solution',
    title: 'Буфер или раствор',
    icon: '🧴',
    noteType: 'solution',
    defaultTags: ['лаборатория', 'раствор'],
    defaultProperties: {
      'solution_name': '',
      'target_volume': '',
      'target_ph': '',
      'prepared_at': '',
    },
    content: '''# Буфер или раствор

## Назначение

## Расчёт состава

| Компонент | Исходная концентрация | Финальная концентрация | Количество |
| --- | --- | --- | --- |
|  |  |  |  |

- **Целевой объём:**
- **Целевой pH:**
- **Растворитель:**

## Приготовление

1.

## Контроль

- **Фактический pH:**
- **Внешний вид:**
- **Стерилизация / фильтрация:**

## Маркировка и хранение

- **Дата приготовления:**
- **Ответственный:**
- **Температура хранения:**
- **Срок годности:**
- **Место хранения:**

## Примечания
''',
  ),
];

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
  ...laboratoryNoteTemplates,
];

String noteTypeLabel(String value) => switch (value) {
  'lecture' => 'Лекция',
  'research' => 'Исследование',
  'literature' => 'Источник',
  'meeting' => 'Встреча',
  'lab_day' => 'Лабораторный день',
  'experiment' => 'Эксперимент',
  'sample' => 'Образец',
  'protein_purification' => 'Экспрессия и очистка',
  'nmr_experiment' => 'ЯМР-эксперимент',
  'solution' => 'Буфер или раствор',
  _ => 'Заметка',
};

String noteTypeIcon(String value) => switch (value) {
  'lecture' => '🎓',
  'research' => '🧬',
  'literature' => '📚',
  'meeting' => '🤝',
  'lab_day' => '🧪',
  'experiment' => '⚗️',
  'sample' => '🧫',
  'protein_purification' => '🧬',
  'nmr_experiment' => '🧲',
  'solution' => '🧴',
  _ => '📝',
};
