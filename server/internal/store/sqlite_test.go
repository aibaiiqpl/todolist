package store

import (
	"context"
	"database/sql"
	"testing"
	"time"

	_ "modernc.org/sqlite"
)

func TestSQLiteStoreSyncAndChanges(t *testing.T) {
	ctx := context.Background()
	db, err := sql.Open("sqlite", t.TempDir()+"/todolist.sqlite")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	if err := InitializeSQLite(ctx, db); err != nil {
		t.Fatal(err)
	}
	store := NewSQLiteStore(db)

	email := "user@example.test"
	user, err := store.UpsertUserByAppleSubject(ctx, "apple-subject", &email)
	if err != nil {
		t.Fatal(err)
	}
	if user.ID == "" || user.AppleSubject != "apple-subject" || user.Email == nil || *user.Email != email {
		t.Fatalf("user = %+v", user)
	}

	createdAt := time.Date(2026, 5, 23, 10, 0, 0, 0, time.UTC)
	task := Task{
		ID:         "task-1",
		Title:      "Pay rent",
		Importance: 4,
		Urgency:    5,
		SourceText: "pay rent today",
		CreatedAt:  createdAt,
		UpdatedAt:  createdAt,
	}
	synced, err := store.SyncTasks(ctx, user.ID, []Task{task})
	if err != nil {
		t.Fatal(err)
	}
	if synced.ServerVersion != 1 || len(synced.Tasks) != 1 {
		t.Fatalf("synced = %+v", synced)
	}

	changes, err := store.Changes(ctx, user.ID, 0)
	if err != nil {
		t.Fatal(err)
	}
	if changes.ServerVersion != 1 || len(changes.Tasks) != 1 {
		t.Fatalf("changes = %+v", changes)
	}
	if changes.Tasks[0].Title != task.Title || changes.Tasks[0].Completed {
		t.Fatalf("task = %+v", changes.Tasks[0])
	}

	deletedAt := createdAt.Add(time.Hour)
	task.DeletedAt = &deletedAt
	task.UpdatedAt = deletedAt
	task.Version = synced.ServerVersion
	deleted, err := store.SyncTasks(ctx, user.ID, []Task{task})
	if err != nil {
		t.Fatal(err)
	}
	if deleted.ServerVersion != 2 || len(deleted.Tasks) != 1 {
		t.Fatalf("deleted = %+v", deleted)
	}

	changes, err = store.Changes(ctx, user.ID, 1)
	if err != nil {
		t.Fatal(err)
	}
	if len(changes.Tasks) != 1 || changes.Tasks[0].DeletedAt == nil || !changes.Tasks[0].DeletedAt.Equal(deletedAt) {
		t.Fatalf("delete changes = %+v", changes.Tasks)
	}
}
