package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
)

type SQLiteStore struct {
	db *sql.DB
}

func NewSQLiteStore(db *sql.DB) *SQLiteStore {
	return &SQLiteStore{db: db}
}

func InitializeSQLite(ctx context.Context, db *sql.DB) error {
	statements := []string{
		`PRAGMA foreign_keys = ON`,
		`CREATE TABLE IF NOT EXISTS users (
			id TEXT PRIMARY KEY,
			apple_subject TEXT NOT NULL UNIQUE,
			email TEXT,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
		)`,
		`CREATE TABLE IF NOT EXISTS tasks (
			user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			id TEXT NOT NULL,
			title TEXT NOT NULL,
			completed BOOLEAN NOT NULL DEFAULT FALSE,
			importance INTEGER NOT NULL,
			urgency INTEGER NOT NULL,
			due_at DATETIME,
			source_text TEXT NOT NULL DEFAULT '',
			created_at DATETIME NOT NULL,
			updated_at DATETIME NOT NULL,
			deleted_at DATETIME,
			version INTEGER NOT NULL,
			PRIMARY KEY (user_id, id),
			CHECK (importance BETWEEN 1 AND 5),
			CHECK (urgency BETWEEN 1 AND 5)
		)`,
		`CREATE INDEX IF NOT EXISTS tasks_user_version_idx ON tasks(user_id, version)`,
		`CREATE INDEX IF NOT EXISTS tasks_user_updated_at_idx ON tasks(user_id, updated_at)`,
	}
	for _, statement := range statements {
		if _, err := db.ExecContext(ctx, statement); err != nil {
			return err
		}
	}
	return nil
}

func (s *SQLiteStore) UpsertUserByAppleSubject(ctx context.Context, appleSubject string, email *string) (User, error) {
	if appleSubject == "" {
		return User{}, fmt.Errorf("apple subject is required")
	}

	id, err := newID()
	if err != nil {
		return User{}, err
	}

	var user User
	err = s.db.QueryRowContext(ctx, `
		INSERT INTO users (id, apple_subject, email)
		VALUES (?, ?, ?)
		ON CONFLICT (apple_subject) DO UPDATE
		SET email = COALESCE(EXCLUDED.email, users.email)
		RETURNING id, apple_subject, email, created_at
	`, id, appleSubject, email).Scan(&user.ID, &user.AppleSubject, &user.Email, &user.CreatedAt)
	if err != nil {
		return User{}, err
	}
	return user, nil
}

func (s *SQLiteStore) Changes(ctx context.Context, userID string, sinceVersion int64) (ChangeSet, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, user_id, title, completed, importance, urgency, due_at, source_text, created_at, updated_at, deleted_at, version
		FROM tasks
		WHERE user_id = ? AND version > ?
		ORDER BY version ASC
	`, userID, sinceVersion)
	if err != nil {
		return ChangeSet{}, err
	}
	defer rows.Close()

	tasks, err := scanTasks(rows)
	if err != nil {
		return ChangeSet{}, err
	}

	version, err := s.latestVersion(ctx, userID)
	if err != nil {
		return ChangeSet{}, err
	}
	return ChangeSet{Tasks: tasks, ServerVersion: version}, nil
}

func (s *SQLiteStore) SyncTasks(ctx context.Context, userID string, tasks []Task) (ChangeSet, error) {
	tx, err := s.db.BeginTx(ctx, &sql.TxOptions{})
	if err != nil {
		return ChangeSet{}, err
	}
	defer tx.Rollback()

	accepted := make([]Task, 0, len(tasks))
	for _, incoming := range tasks {
		if err := validateTask(incoming); err != nil {
			return ChangeSet{}, err
		}
		incoming.UserID = userID

		existing, err := selectSQLiteTask(ctx, tx, userID, incoming.ID)
		if err != nil && !errors.Is(err, ErrNotFound) {
			return ChangeSet{}, err
		}

		if errors.Is(err, ErrNotFound) || shouldAcceptIncoming(existing, incoming) {
			version, err := nextSQLiteVersion(ctx, tx, userID)
			if err != nil {
				return ChangeSet{}, err
			}
			incoming.Version = version
			if incoming.CreatedAt.IsZero() {
				incoming.CreatedAt = incoming.UpdatedAt
			}
			if err := upsertSQLiteTask(ctx, tx, incoming); err != nil {
				return ChangeSet{}, err
			}
			accepted = append(accepted, incoming)
			continue
		}

		accepted = append(accepted, existing)
	}

	version, err := latestSQLiteVersionTx(ctx, tx, userID)
	if err != nil {
		return ChangeSet{}, err
	}
	if err := tx.Commit(); err != nil {
		return ChangeSet{}, err
	}
	return ChangeSet{Tasks: accepted, ServerVersion: version}, nil
}

func (s *SQLiteStore) latestVersion(ctx context.Context, userID string) (int64, error) {
	return latestSQLiteVersionQuery(ctx, s.db, userID)
}

func selectSQLiteTask(ctx context.Context, tx *sql.Tx, userID string, taskID string) (Task, error) {
	var task Task
	var dueAt sql.NullTime
	var deletedAt sql.NullTime
	err := tx.QueryRowContext(ctx, `
		SELECT id, user_id, title, completed, importance, urgency, due_at, source_text, created_at, updated_at, deleted_at, version
		FROM tasks
		WHERE user_id = ? AND id = ?
	`, userID, taskID).Scan(
		&task.ID,
		&task.UserID,
		&task.Title,
		&task.Completed,
		&task.Importance,
		&task.Urgency,
		&dueAt,
		&task.SourceText,
		&task.CreatedAt,
		&task.UpdatedAt,
		&deletedAt,
		&task.Version,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return Task{}, ErrNotFound
	}
	if err != nil {
		return Task{}, err
	}
	task.DueAt = timePtr(dueAt)
	task.DeletedAt = timePtr(deletedAt)
	return task, nil
}

func upsertSQLiteTask(ctx context.Context, tx *sql.Tx, task Task) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO tasks (
			user_id, id, title, completed, importance, urgency, due_at, source_text,
			created_at, updated_at, deleted_at, version
		)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT (user_id, id) DO UPDATE SET
			title = EXCLUDED.title,
			completed = EXCLUDED.completed,
			importance = EXCLUDED.importance,
			urgency = EXCLUDED.urgency,
			due_at = EXCLUDED.due_at,
			source_text = EXCLUDED.source_text,
			created_at = EXCLUDED.created_at,
			updated_at = EXCLUDED.updated_at,
			deleted_at = EXCLUDED.deleted_at,
			version = EXCLUDED.version
	`, task.UserID, task.ID, task.Title, task.Completed, task.Importance, task.Urgency, task.DueAt,
		task.SourceText, task.CreatedAt, task.UpdatedAt, task.DeletedAt, task.Version)
	return err
}

type sqliteQueryer interface {
	QueryRowContext(context.Context, string, ...any) *sql.Row
}

func latestSQLiteVersionQuery(ctx context.Context, q sqliteQueryer, userID string) (int64, error) {
	var version int64
	err := q.QueryRowContext(ctx, `SELECT COALESCE(MAX(version), 0) FROM tasks WHERE user_id = ?`, userID).Scan(&version)
	return version, err
}

func latestSQLiteVersionTx(ctx context.Context, tx *sql.Tx, userID string) (int64, error) {
	return latestSQLiteVersionQuery(ctx, tx, userID)
}

func nextSQLiteVersion(ctx context.Context, tx *sql.Tx, userID string) (int64, error) {
	version, err := latestSQLiteVersionTx(ctx, tx, userID)
	if err != nil {
		return 0, err
	}
	return version + 1, nil
}

var _ Store = (*SQLiteStore)(nil)
