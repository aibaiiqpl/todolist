CREATE TABLE users (
    id TEXT PRIMARY KEY,
    apple_subject TEXT NOT NULL UNIQUE,
    email TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE tasks (
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    id TEXT NOT NULL,
    title TEXT NOT NULL,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    importance INTEGER NOT NULL,
    urgency INTEGER NOT NULL,
    due_at TIMESTAMPTZ,
    source_text TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    deleted_at TIMESTAMPTZ,
    version BIGINT NOT NULL,
    PRIMARY KEY (user_id, id),
    CHECK (importance BETWEEN 1 AND 5),
    CHECK (urgency BETWEEN 1 AND 5)
);

CREATE INDEX tasks_user_version_idx ON tasks(user_id, version);
CREATE INDEX tasks_user_updated_at_idx ON tasks(user_id, updated_at);
