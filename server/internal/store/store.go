package store

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"time"
)

var ErrNotFound = errors.New("not found")

type User struct {
	ID           string    `json:"id"`
	AppleSubject string    `json:"-"`
	Email        *string   `json:"email,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
}

type Task struct {
	ID         string     `json:"id"`
	UserID     string     `json:"-"`
	Title      string     `json:"title"`
	Completed  bool       `json:"completed"`
	Importance int        `json:"importance"`
	Urgency    int        `json:"urgency"`
	DueAt      *time.Time `json:"due_at,omitempty"`
	SourceText string     `json:"source_text"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
	DeletedAt  *time.Time `json:"deleted_at,omitempty"`
	Version    int64      `json:"version"`
}

type ChangeSet struct {
	Tasks         []Task `json:"tasks"`
	ServerVersion int64  `json:"server_version"`
}

type Store interface {
	UpsertUserByAppleSubject(ctx context.Context, appleSubject string, email *string) (User, error)
	Changes(ctx context.Context, userID string, sinceVersion int64) (ChangeSet, error)
	SyncTasks(ctx context.Context, userID string, tasks []Task) (ChangeSet, error)
}

type PostgresStore struct {
	db *sql.DB
}

func NewPostgresStore(db *sql.DB) *PostgresStore {
	return &PostgresStore{db: db}
}

func (s *PostgresStore) UpsertUserByAppleSubject(ctx context.Context, appleSubject string, email *string) (User, error) {
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
		VALUES ($1, $2, $3)
		ON CONFLICT (apple_subject) DO UPDATE
		SET email = COALESCE(EXCLUDED.email, users.email)
		RETURNING id, apple_subject, email, created_at
	`, id, appleSubject, email).Scan(&user.ID, &user.AppleSubject, &user.Email, &user.CreatedAt)
	if err != nil {
		return User{}, err
	}
	return user, nil
}

func (s *PostgresStore) Changes(ctx context.Context, userID string, sinceVersion int64) (ChangeSet, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, user_id, title, completed, importance, urgency, due_at, source_text, created_at, updated_at, deleted_at, version
		FROM tasks
		WHERE user_id = $1 AND version > $2
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

func (s *PostgresStore) SyncTasks(ctx context.Context, userID string, tasks []Task) (ChangeSet, error) {
	tx, err := s.db.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})
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

		existing, err := selectTask(ctx, tx, userID, incoming.ID)
		if err != nil && !errors.Is(err, ErrNotFound) {
			return ChangeSet{}, err
		}

		if errors.Is(err, ErrNotFound) || shouldAcceptIncoming(existing, incoming) {
			version, err := nextVersion(ctx, tx, userID)
			if err != nil {
				return ChangeSet{}, err
			}
			incoming.Version = version
			if incoming.CreatedAt.IsZero() {
				incoming.CreatedAt = incoming.UpdatedAt
			}
			if err := upsertTask(ctx, tx, incoming); err != nil {
				return ChangeSet{}, err
			}
			accepted = append(accepted, incoming)
			continue
		}

		accepted = append(accepted, existing)
	}

	version, err := latestVersionTx(ctx, tx, userID)
	if err != nil {
		return ChangeSet{}, err
	}
	if err := tx.Commit(); err != nil {
		return ChangeSet{}, err
	}
	return ChangeSet{Tasks: accepted, ServerVersion: version}, nil
}

func scanTasks(rows *sql.Rows) ([]Task, error) {
	var tasks []Task
	for rows.Next() {
		var task Task
		var dueAt sql.NullTime
		var deletedAt sql.NullTime
		if err := rows.Scan(
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
		); err != nil {
			return nil, err
		}
		task.DueAt = timePtr(dueAt)
		task.DeletedAt = timePtr(deletedAt)
		tasks = append(tasks, task)
	}
	return tasks, rows.Err()
}

func selectTask(ctx context.Context, tx *sql.Tx, userID string, taskID string) (Task, error) {
	var task Task
	var dueAt sql.NullTime
	var deletedAt sql.NullTime
	err := tx.QueryRowContext(ctx, `
		SELECT id, user_id, title, completed, importance, urgency, due_at, source_text, created_at, updated_at, deleted_at, version
		FROM tasks
		WHERE user_id = $1 AND id = $2
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

func upsertTask(ctx context.Context, tx *sql.Tx, task Task) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO tasks (
			user_id, id, title, completed, importance, urgency, due_at, source_text,
			created_at, updated_at, deleted_at, version
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
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

func shouldAcceptIncoming(existing Task, incoming Task) bool {
	if incoming.UpdatedAt.After(existing.UpdatedAt) {
		return true
	}
	if incoming.UpdatedAt.Equal(existing.UpdatedAt) && incoming.Version >= existing.Version {
		return true
	}
	return incoming.Version > existing.Version
}

func validateTask(task Task) error {
	if task.ID == "" {
		return fmt.Errorf("task id is required")
	}
	if task.Title == "" {
		return fmt.Errorf("task title is required")
	}
	if task.Importance < 1 || task.Importance > 5 {
		return fmt.Errorf("task importance must be between 1 and 5")
	}
	if task.Urgency < 1 || task.Urgency > 5 {
		return fmt.Errorf("task urgency must be between 1 and 5")
	}
	if task.UpdatedAt.IsZero() {
		return fmt.Errorf("task updated_at is required")
	}
	return nil
}

func (s *PostgresStore) latestVersion(ctx context.Context, userID string) (int64, error) {
	return latestVersionQuery(ctx, s.db, userID)
}

type queryer interface {
	QueryRowContext(context.Context, string, ...any) *sql.Row
}

func latestVersionQuery(ctx context.Context, q queryer, userID string) (int64, error) {
	var version int64
	err := q.QueryRowContext(ctx, `SELECT COALESCE(MAX(version), 0) FROM tasks WHERE user_id = $1`, userID).Scan(&version)
	return version, err
}

func latestVersionTx(ctx context.Context, tx *sql.Tx, userID string) (int64, error) {
	return latestVersionQuery(ctx, tx, userID)
}

func nextVersion(ctx context.Context, tx *sql.Tx, userID string) (int64, error) {
	version, err := latestVersionTx(ctx, tx, userID)
	if err != nil {
		return 0, err
	}
	return version + 1, nil
}

func newID() (string, error) {
	var buf [16]byte
	if _, err := rand.Read(buf[:]); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf[:]), nil
}

func timePtr(value sql.NullTime) *time.Time {
	if !value.Valid {
		return nil
	}
	t := value.Time
	return &t
}
