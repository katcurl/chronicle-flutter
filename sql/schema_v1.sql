PRAGMA foreign_keys = ON;

CREATE TABLE schema_meta (
  version INTEGER NOT NULL,
  applied_at TEXT NOT NULL
);

CREATE TABLE workspaces (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT,
  accent_token TEXT,
  is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE projects (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL CHECK (status IN ('planned','active','paused','completed','archived')),
  start_date TEXT,
  target_date TEXT,
  budget_minutes INTEGER,
  hourly_rate_minor INTEGER,
  currency_code TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX idx_projects_workspace_status ON projects(workspace_id, status);

CREATE TABLE work_items (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(id),
  title TEXT NOT NULL,
  item_type TEXT NOT NULL DEFAULT 'general',
  status TEXT NOT NULL CHECK (status IN ('inbox','planned','in_progress','waiting','blocked','done','cancelled')),
  priority INTEGER NOT NULL DEFAULT 0,
  estimate_minutes INTEGER,
  next_action TEXT,
  outcome_summary TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  completed_at TEXT
);
CREATE INDEX idx_work_items_project_status ON work_items(project_id, status);

CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(id),
  work_item_id TEXT REFERENCES work_items(id),
  parent_task_id TEXT REFERENCES tasks(id),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL CHECK (status IN ('inbox','next','in_progress','waiting','blocked','done','cancelled')),
  priority INTEGER NOT NULL DEFAULT 0,
  estimate_minutes INTEGER,
  due_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  completed_at TEXT
);
CREATE INDEX idx_tasks_status_due ON tasks(status, due_at);
CREATE INDEX idx_tasks_work_item ON tasks(work_item_id);

CREATE TABLE task_dependencies (
  task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  depends_on_task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  PRIMARY KEY(task_id, depends_on_task_id),
  CHECK(task_id <> depends_on_task_id)
);

CREATE TABLE notes (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id),
  project_id TEXT REFERENCES projects(id),
  title TEXT NOT NULL,
  note_type TEXT NOT NULL DEFAULT 'general',
  status TEXT NOT NULL DEFAULT 'active',
  relative_path TEXT NOT NULL UNIQUE,
  content_hash TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);
CREATE INDEX idx_notes_project ON notes(project_id);

CREATE TABLE note_links (
  source_note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  target_note_id TEXT REFERENCES notes(id) ON DELETE CASCADE,
  unresolved_target TEXT,
  heading TEXT,
  link_kind TEXT NOT NULL DEFAULT 'wiki',
  PRIMARY KEY(source_note_id, target_note_id, unresolved_target, heading)
);

CREATE TABLE work_item_notes (
  work_item_id TEXT NOT NULL REFERENCES work_items(id) ON DELETE CASCADE,
  note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  relation TEXT NOT NULL DEFAULT 'related',
  PRIMARY KEY(work_item_id, note_id)
);

CREATE TABLE time_sessions (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(id),
  work_item_id TEXT REFERENCES work_items(id),
  task_id TEXT REFERENCES tasks(id),
  note_id TEXT REFERENCES notes(id),
  description TEXT NOT NULL DEFAULT '',
  started_at TEXT NOT NULL,
  ended_at TEXT,
  duration_seconds INTEGER,
  source TEXT NOT NULL CHECK (source IN ('timer','manual','imported','recovered')),
  outcome TEXT,
  interruption_reason TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  CHECK ((ended_at IS NULL AND duration_seconds IS NULL) OR (ended_at IS NOT NULL AND duration_seconds >= 0))
);
CREATE INDEX idx_sessions_started ON time_sessions(started_at);
CREATE INDEX idx_sessions_project ON time_sessions(project_id, started_at);

CREATE UNIQUE INDEX idx_single_running_primary_session
ON time_sessions((1)) WHERE ended_at IS NULL;

CREATE TABLE attachments (
  id TEXT PRIMARY KEY,
  note_id TEXT REFERENCES notes(id),
  original_name TEXT NOT NULL,
  relative_path TEXT NOT NULL UNIQUE,
  mime_type TEXT,
  size_bytes INTEGER NOT NULL,
  sha256 TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE note_versions (
  id TEXT PRIMARY KEY,
  note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  content_hash TEXT NOT NULL,
  snapshot_path TEXT NOT NULL,
  created_at TEXT NOT NULL,
  reason TEXT NOT NULL DEFAULT 'autosave'
);

CREATE TABLE bibliography (
  id TEXT PRIMARY KEY,
  citation_key TEXT NOT NULL UNIQUE,
  entry_type TEXT NOT NULL,
  title TEXT,
  authors TEXT,
  year INTEGER,
  doi TEXT,
  url TEXT,
  raw_bibtex TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  color_token TEXT
);

CREATE TABLE entity_tags (
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY(entity_type, entity_id, tag_id)
);

CREATE TABLE events (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id),
  project_id TEXT REFERENCES projects(id),
  work_item_id TEXT REFERENCES work_items(id),
  event_type TEXT NOT NULL,
  entity_type TEXT,
  entity_id TEXT,
  occurred_at TEXT NOT NULL,
  payload_json TEXT NOT NULL DEFAULT '{}'
);
CREATE INDEX idx_events_project_time ON events(project_id, occurred_at);

CREATE VIRTUAL TABLE search_index USING fts5(
  entity_type UNINDEXED,
  entity_id UNINDEXED,
  title,
  body,
  tags,
  tokenize = 'unicode61 remove_diacritics 2'
);
