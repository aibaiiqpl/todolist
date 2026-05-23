package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sort"
	"strconv"
	"sync"
	"testing"
	"time"

	"todolist/server/internal/ai"
	"todolist/server/internal/apple"
	"todolist/server/internal/auth"
	"todolist/server/internal/store"
)

func TestUnauthenticatedCannotCallAI(t *testing.T) {
	handler, _, _ := newTestAPI(t, &fakeOrganizer{})

	resp := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/ai/organize", bytes.NewBufferString(`{"input":"tomorrow pay rent"}`))
	handler.ServeHTTP(resp, req)

	if resp.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", resp.Code, http.StatusUnauthorized)
	}
}

func TestAppleAuthUsesVerifierAndIssuesJWT(t *testing.T) {
	handler, signer, _ := newTestAPI(t, &fakeOrganizer{})

	body := doJSON(t, handler, http.MethodPost, "/auth/apple", "", map[string]string{"identity_token": "apple-subject-a"}, http.StatusOK)
	var resp struct {
		UserID      string `json:"user_id"`
		AccessToken string `json:"access_token"`
		ExpiresAt   string `json:"expires_at"`
	}
	if err := json.Unmarshal(body, &resp); err != nil {
		t.Fatal(err)
	}
	if resp.UserID == "" || resp.AccessToken == "" || resp.ExpiresAt == "" {
		t.Fatalf("auth response = %+v", resp)
	}
	if _, err := time.Parse(time.RFC3339, resp.ExpiresAt); err != nil {
		t.Fatalf("expires_at is not RFC3339: %v", err)
	}
	userID, err := signer.Verify(resp.AccessToken)
	if err != nil {
		t.Fatal(err)
	}
	if userID != resp.UserID {
		t.Fatalf("token subject = %q, want %q", userID, resp.UserID)
	}
}

func TestAIOrganizeUsesInputAndDraftsContract(t *testing.T) {
	handler, signer, _ := newTestAPI(t, &fakeOrganizer{})
	token := signToken(t, signer, "user-a")

	body := doJSON(t, handler, http.MethodPost, "/ai/organize", token, map[string]string{"input": "tomorrow pay rent"}, http.StatusOK)
	var resp struct {
		Drafts []ai.Draft `json:"drafts"`
		Tasks  []ai.Draft `json:"tasks"`
	}
	if err := json.Unmarshal(body, &resp); err != nil {
		t.Fatal(err)
	}
	if len(resp.Drafts) != 1 || resp.Drafts[0].SourceText != "tomorrow pay rent" {
		t.Fatalf("drafts = %+v", resp.Drafts)
	}
	if resp.Tasks != nil {
		t.Fatalf("legacy tasks field should be absent: %+v", resp.Tasks)
	}
}

func TestTaskChangesAreIsolatedByUser(t *testing.T) {
	handler, signer, _ := newTestAPI(t, &fakeOrganizer{})
	userAToken := signToken(t, signer, "user-a")
	userBToken := signToken(t, signer, "user-b")

	task := store.Task{
		ID:         "shared-client-id",
		Title:      "User A task",
		Importance: 3,
		Urgency:    2,
		SourceText: "source",
		CreatedAt:  time.Date(2026, 5, 23, 10, 0, 0, 0, time.UTC),
		UpdatedAt:  time.Date(2026, 5, 23, 10, 0, 0, 0, time.UTC),
	}
	doJSON(t, handler, http.MethodPost, "/tasks/sync", userAToken, syncBody(syncOperation{
		ID:        "op-create-a",
		Kind:      syncKindCreate,
		Task:      task,
		CreatedAt: task.CreatedAt,
	}), http.StatusOK)

	userBChanges := doJSON(t, handler, http.MethodGet, "/tasks/changes?since_version=0", userBToken, nil, http.StatusOK)
	var changes store.ChangeSet
	if err := json.Unmarshal(userBChanges, &changes); err != nil {
		t.Fatal(err)
	}
	if len(changes.Tasks) != 0 {
		t.Fatalf("user B saw %d tasks, want 0", len(changes.Tasks))
	}

	userAChanges := doJSON(t, handler, http.MethodGet, "/tasks/changes?since_version=0", userAToken, nil, http.StatusOK)
	if err := json.Unmarshal(userAChanges, &changes); err != nil {
		t.Fatal(err)
	}
	if len(changes.Tasks) != 1 || changes.Tasks[0].Title != "User A task" {
		t.Fatalf("user A changes = %+v", changes.Tasks)
	}
}

func TestSoftDeleteIsSyncedAsChange(t *testing.T) {
	handler, signer, _ := newTestAPI(t, &fakeOrganizer{})
	token := signToken(t, signer, "user-a")
	createdAt := time.Date(2026, 5, 23, 10, 0, 0, 0, time.UTC)
	deletedAt := time.Date(2026, 5, 23, 11, 0, 0, 0, time.UTC)

	task := store.Task{
		ID:         "task-1",
		Title:      "Pay rent",
		Importance: 4,
		Urgency:    4,
		SourceText: "pay rent",
		CreatedAt:  createdAt,
		UpdatedAt:  createdAt,
	}
	body := doJSON(t, handler, http.MethodPost, "/tasks/sync", token, syncBody(syncOperation{
		ID:        "op-create",
		Kind:      syncKindCreate,
		Task:      task,
		CreatedAt: createdAt,
	}), http.StatusOK)
	var first syncResponse
	if err := json.Unmarshal(body, &first); err != nil {
		t.Fatal(err)
	}
	if first.ServerVersion != 1 {
		t.Fatalf("server version = %d, want 1", first.ServerVersion)
	}
	if got := first.AcknowledgedOperationIDs; len(got) != 1 || got[0] != "op-create" {
		t.Fatalf("acknowledged operation ids = %+v", got)
	}

	task.DeletedAt = &deletedAt
	task.UpdatedAt = deletedAt
	task.Version = first.ServerVersion
	body = doJSON(t, handler, http.MethodPost, "/tasks/sync", token, syncBody(syncOperation{
		ID:        "op-delete",
		Kind:      syncKindDelete,
		Task:      task,
		CreatedAt: deletedAt,
	}), http.StatusOK)
	var deleted syncResponse
	if err := json.Unmarshal(body, &deleted); err != nil {
		t.Fatal(err)
	}
	if got := deleted.AcknowledgedOperationIDs; len(got) != 1 || got[0] != "op-delete" {
		t.Fatalf("acknowledged operation ids = %+v", got)
	}

	body = doJSON(t, handler, http.MethodGet, "/tasks/changes?since_version=1", token, nil, http.StatusOK)
	var changes store.ChangeSet
	if err := json.Unmarshal(body, &changes); err != nil {
		t.Fatal(err)
	}
	if len(changes.Tasks) != 1 {
		t.Fatalf("changes count = %d, want 1", len(changes.Tasks))
	}
	if changes.Tasks[0].DeletedAt == nil || !changes.Tasks[0].DeletedAt.Equal(deletedAt) {
		t.Fatalf("deleted_at = %v, want %v", changes.Tasks[0].DeletedAt, deletedAt)
	}
}

func TestTaskSyncAcknowledgesOperationIDs(t *testing.T) {
	handler, signer, _ := newTestAPI(t, &fakeOrganizer{})
	token := signToken(t, signer, "user-a")
	createdAt := time.Date(2026, 5, 23, 10, 0, 0, 0, time.UTC)
	task := store.Task{
		ID:         "task-ack",
		Title:      "Ack task",
		Importance: 2,
		Urgency:    3,
		SourceText: "ack task",
		CreatedAt:  createdAt,
		UpdatedAt:  createdAt,
	}

	body := doJSON(t, handler, http.MethodPost, "/tasks/sync", token, syncBody(syncOperation{
		ID:        "operation-ack",
		Kind:      syncKindCreate,
		Task:      task,
		CreatedAt: createdAt,
	}), http.StatusOK)
	var resp syncResponse
	if err := json.Unmarshal(body, &resp); err != nil {
		t.Fatal(err)
	}
	if len(resp.AcknowledgedOperationIDs) != 1 || resp.AcknowledgedOperationIDs[0] != "operation-ack" {
		t.Fatalf("acknowledged_operation_ids = %+v", resp.AcknowledgedOperationIDs)
	}
	if len(resp.Tasks) != 1 || resp.ServerVersion != 1 {
		t.Fatalf("sync response = %+v", resp)
	}
}

func newTestAPI(t *testing.T, organizer ai.Organizer) (http.Handler, *auth.JWT, *fakeStore) {
	t.Helper()
	signer, err := auth.NewJWT("test-secret")
	if err != nil {
		t.Fatal(err)
	}
	store := newFakeStore()
	api := New(store, signer, fakeAppleVerifier{}, organizer)
	return api.Handler(), signer, store
}

func signToken(t *testing.T, signer *auth.JWT, userID string) string {
	t.Helper()
	token, err := signer.Sign(userID, time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	return token
}

func syncBody(operations ...syncOperation) map[string]any {
	return map[string]any{"operations": operations}
}

func doJSON(t *testing.T, handler http.Handler, method string, path string, token string, body any, wantStatus int) []byte {
	t.Helper()
	var reader *bytes.Reader
	if body == nil {
		reader = bytes.NewReader(nil)
	} else {
		encoded, err := json.Marshal(body)
		if err != nil {
			t.Fatal(err)
		}
		reader = bytes.NewReader(encoded)
	}

	resp := httptest.NewRecorder()
	req := httptest.NewRequest(method, path, reader)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	handler.ServeHTTP(resp, req)
	if resp.Code != wantStatus {
		t.Fatalf("%s %s status = %d, want %d, body = %s", method, path, resp.Code, wantStatus, resp.Body.String())
	}
	return resp.Body.Bytes()
}

type fakeOrganizer struct{}

func (fakeOrganizer) Organize(ctx context.Context, text string) ([]ai.Draft, error) {
	return []ai.Draft{{Title: "Draft", Importance: 3, Urgency: 3, SourceText: text}}, nil
}

type fakeAppleVerifier struct{}

func (fakeAppleVerifier) Verify(ctx context.Context, identityToken string) (apple.Claims, error) {
	email := identityToken + "@example.test"
	return apple.Claims{Subject: identityToken, Email: &email}, nil
}

type fakeStore struct {
	mu             sync.Mutex
	usersBySubject map[string]store.User
	tasksByUser    map[string]map[string]store.Task
	nextUser       int
	versionByUser  map[string]int64
}

func newFakeStore() *fakeStore {
	return &fakeStore{
		usersBySubject: map[string]store.User{},
		tasksByUser:    map[string]map[string]store.Task{},
		versionByUser:  map[string]int64{},
	}
}

func (s *fakeStore) UpsertUserByAppleSubject(ctx context.Context, appleSubject string, email *string) (store.User, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if user, ok := s.usersBySubject[appleSubject]; ok {
		return user, nil
	}
	s.nextUser++
	user := store.User{
		ID:           "user-" + strconv.Itoa(s.nextUser),
		AppleSubject: appleSubject,
		Email:        email,
		CreatedAt:    time.Now().UTC(),
	}
	s.usersBySubject[appleSubject] = user
	return user, nil
}

func (s *fakeStore) Changes(ctx context.Context, userID string, sinceVersion int64) (store.ChangeSet, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	var tasks []store.Task
	for _, task := range s.tasksByUser[userID] {
		if task.Version > sinceVersion {
			tasks = append(tasks, task)
		}
	}
	sort.Slice(tasks, func(i, j int) bool { return tasks[i].Version < tasks[j].Version })
	return store.ChangeSet{Tasks: tasks, ServerVersion: s.versionByUser[userID]}, nil
}

func (s *fakeStore) SyncTasks(ctx context.Context, userID string, tasks []store.Task) (store.ChangeSet, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.tasksByUser[userID] == nil {
		s.tasksByUser[userID] = map[string]store.Task{}
	}
	accepted := make([]store.Task, 0, len(tasks))
	for _, task := range tasks {
		existing, exists := s.tasksByUser[userID][task.ID]
		if exists && !acceptIncoming(existing, task) {
			accepted = append(accepted, existing)
			continue
		}
		s.versionByUser[userID]++
		task.UserID = userID
		task.Version = s.versionByUser[userID]
		if task.UpdatedAt.IsZero() {
			task.UpdatedAt = time.Now().UTC()
		}
		if task.CreatedAt.IsZero() {
			task.CreatedAt = task.UpdatedAt
		}
		s.tasksByUser[userID][task.ID] = task
		accepted = append(accepted, task)
	}
	return store.ChangeSet{Tasks: accepted, ServerVersion: s.versionByUser[userID]}, nil
}

func acceptIncoming(existing store.Task, incoming store.Task) bool {
	if incoming.UpdatedAt.After(existing.UpdatedAt) {
		return true
	}
	if incoming.UpdatedAt.Equal(existing.UpdatedAt) && incoming.Version >= existing.Version {
		return true
	}
	return incoming.Version > existing.Version
}
