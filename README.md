# Chronicle 0.4 — Flutter Android

Нативный local-first MVP для проектов, задач, Markdown/LaTeX-заметок и учёта времени.

## Уже реализовано
- Material 3 интерфейс без браузерной панели и WebView;
- таймер, который считает время по абсолютной дате и корректно восстанавливает длительность после сворачивания;
- проекты, задачи и статусы;
- Markdown-редактор и предпросмотр;
- блочные LaTeX-формулы;
- wiki-ссылки как текстовый формат;
- локальная JSON-база в SharedPreferences;
- статистика и отчёты;
- светлая/тёмная тема;
- GitHub Actions для сборки `app-release.apk`.

## Получение APK через GitHub
1. Создайте пустой репозиторий GitHub.
2. Загрузите туда всё содержимое этой папки.
3. Откройте Actions → Build Android APK → Run workflow.
4. Скачайте artifact `chronicle-release-apk`.

## Локальный запуск
```bash
flutter pub get
flutter create --platforms=android --org=app.chronicle .
flutter run
```

## Важно
Это самостоятельный Flutter-проект, а не оболочка сайта. Для production-версии следующим этапом нужны SQLite/Drift, Android foreground service с уведомлением, SAF-доступ к Obsidian-vault и полноценное управление вложениями.

## Foundation specification

The repository now includes the Chronicle Foundation documents in `docs/`, the initial database schema in `sql/`, and content templates in `templates/`.

These documents define the intended architecture and roadmap. They do not imply that every documented module is already implemented in the current Flutter prototype.
