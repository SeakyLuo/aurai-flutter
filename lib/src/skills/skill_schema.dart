const skillSchema = [
  '''CREATE TABLE skills (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    instructions TEXT NOT NULL,
    script TEXT NOT NULL,
    enabled INTEGER NOT NULL,
    icon TEXT NOT NULL DEFAULT 'skill',
    revision INTEGER NOT NULL
  )''',
  '''CREATE TABLE skill_dependencies (
    skill_id TEXT NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    dependency_id TEXT NOT NULL REFERENCES skills(id) ON DELETE RESTRICT,
    PRIMARY KEY(skill_id, dependency_id),
    CHECK(skill_id <> dependency_id)
  )''',
  'CREATE INDEX skill_dependencies_target ON skill_dependencies(dependency_id)',
];
