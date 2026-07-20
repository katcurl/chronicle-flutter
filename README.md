# Chronicle 0.7 — Data Core

Нативное local-first Android-приложение для проектов, задач, Markdown/LaTeX-заметок и учёта времени.

## Что уже работает

- аккуратный Material 3 интерфейс;
- проекты и задачи со статусами;
- Markdown-редактор, предпросмотр и безопасное управление порядком блоков;
- кликабельные `[[вики-ссылки]]`, автодополнение, обратные ссылки, безопасное переименование и интерактивная карта знаний;
- блочные LaTeX-формулы;
- таймер с привязкой к проекту и заметке;
- сохранение активного таймера после закрытия приложения;
- SQLite-база для проектов, задач, заметок и временных записей;
- автоматический перенос данных из старой SharedPreferences-версии;
- JSON-резервная копия через буфер обмена;
- статистика по проектам;
- светлая и тёмная темы;
- GitHub Actions для сборки `app-release.apk`;
- in-memory репозиторий и автоматические тесты.

## Архитектура Data Core

```text
Flutter UI
   ↓
AppStore
   ↓
AppRepository
   ├── SqliteAppRepository — Android production
   └── InMemoryAppRepository — tests
   ↓
chronicle.db
```

Подробности: [`docs/11-data-core-v0.7.md`](docs/11-data-core-v0.7.md).

## Обновление с установленной v0.6

Устанавливай новый APK поверх старого, не удаляя приложение. При первом запуске v0.7:

1. создаётся `chronicle.db`;
2. старые проекты, задачи, заметки и сессии читаются из `chronicle_data_v5`;
3. данные записываются в SQLite;
4. дальнейшая работа идёт через SQLite.

Старый JSON пока не удаляется и остаётся аварийной копией.

## Локальная проверка

```bash
flutter pub get
flutter analyze
flutter test
```

Запуск на подключённом Android-устройстве:

```bash
flutter run
```

## Сборка APK через GitHub Actions

Workflow запускается при push в `main` и `feature/data-core`, а также вручную:

```text
Actions → Build Android APK → Run workflow
```

После успешной сборки скачай artifact:

```text
chronicle-release-apk
```

Внутри находится:

```text
app-release.apk
```

## Foundation

Продуктовая спецификация находится в `docs/`, SQL-схема — в `sql/`, шаблоны заметок — в `templates/`.

Следующий этап: **v0.8 Timer Core** — ручные интервалы, редактирование истории, foreground service и системное уведомление Android.
