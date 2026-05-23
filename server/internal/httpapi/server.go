package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"todolist/server/internal/ai"
	"todolist/server/internal/apple"
	"todolist/server/internal/auth"
	"todolist/server/internal/store"
)

const jwtTTL = 30 * 24 * time.Hour

type Server struct {
	store         store.Store
	jwt           *auth.JWT
	appleVerifier apple.Verifier
	organizer     ai.Organizer
}

func New(store store.Store, jwt *auth.JWT, appleVerifier apple.Verifier, organizer ai.Organizer) *Server {
	return &Server{
		store:         store,
		jwt:           jwt,
		appleVerifier: appleVerifier,
		organizer:     organizer,
	}
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.health)
	mux.HandleFunc("POST /auth/apple", s.authApple)
	mux.Handle("GET /tasks/changes", s.requireAuth(http.HandlerFunc(s.taskChanges)))
	mux.Handle("POST /tasks/sync", s.requireAuth(http.HandlerFunc(s.taskSync)))
	mux.Handle("POST /ai/organize", s.requireAuth(http.HandlerFunc(s.organize)))
	return mux
}

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) authApple(w http.ResponseWriter, r *http.Request) {
	var req struct {
		IdentityToken string `json:"identity_token"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if strings.TrimSpace(req.IdentityToken) == "" {
		writeError(w, http.StatusBadRequest, "invalid_request", "identity_token is required")
		return
	}

	claims, err := s.appleVerifier.Verify(r.Context(), req.IdentityToken)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "invalid_apple_token", "apple identity token is invalid")
		return
	}

	user, err := s.store.UpsertUserByAppleSubject(r.Context(), claims.Subject, claims.Email)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	expiresAt := time.Now().UTC().Add(jwtTTL).Truncate(time.Second)
	token, err := s.jwt.SignUntil(user.ID, expiresAt)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "token_error", err.Error())
		return
	}

	writeJSON(w, http.StatusOK, authAppleResponse{
		UserID:      user.ID,
		AccessToken: token,
		ExpiresAt:   expiresAt.Format(time.RFC3339),
	})
}

func (s *Server) taskChanges(w http.ResponseWriter, r *http.Request) {
	sinceVersion, err := parseSinceVersion(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	changes, err := s.store.Changes(r.Context(), userIDFromContext(r.Context()), sinceVersion)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, changes)
}

func (s *Server) taskSync(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Operations []syncOperation `json:"operations"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	tasks := make([]store.Task, 0, len(req.Operations))
	acknowledgedOperationIDs := make([]string, 0, len(req.Operations))
	for _, operation := range req.Operations {
		if err := operation.validate(); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_operation", err.Error())
			return
		}
		tasks = append(tasks, operation.Task)
		acknowledgedOperationIDs = append(acknowledgedOperationIDs, operation.ID)
	}

	changes, err := s.store.SyncTasks(r.Context(), userIDFromContext(r.Context()), tasks)
	if err != nil {
		writeError(w, http.StatusBadRequest, "sync_error", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, syncResponse{
		AcknowledgedOperationIDs: acknowledgedOperationIDs,
		Tasks:                    changes.Tasks,
		ServerVersion:            changes.ServerVersion,
	})
}

func (s *Server) organize(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Input string `json:"input"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if strings.TrimSpace(req.Input) == "" {
		writeError(w, http.StatusBadRequest, "invalid_request", "input is required")
		return
	}

	drafts, err := s.organizer.Organize(r.Context(), req.Input)
	if err != nil {
		status := http.StatusBadGateway
		code := "ai_error"
		if errors.Is(err, ai.ErrInvalidModelJSON) {
			code = "invalid_ai_json"
		}
		if errors.Is(err, ai.ErrMissingAPIKey) {
			status = http.StatusInternalServerError
			code = "missing_ai_api_key"
		}
		writeError(w, status, code, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"drafts": drafts})
}

func (s *Server) requireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		token := strings.TrimPrefix(header, "Bearer ")
		if token == header || strings.TrimSpace(token) == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized", "bearer token is required")
			return
		}
		userID, err := s.jwt.Verify(token)
		if err != nil {
			writeError(w, http.StatusUnauthorized, "unauthorized", "bearer token is invalid")
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), userIDKey{}, userID)))
	})
}

type userIDKey struct{}

type authAppleResponse struct {
	UserID      string `json:"user_id"`
	AccessToken string `json:"access_token"`
	ExpiresAt   string `json:"expires_at"`
}

type syncResponse struct {
	AcknowledgedOperationIDs []string     `json:"acknowledged_operation_ids"`
	Tasks                    []store.Task `json:"tasks"`
	ServerVersion            int64        `json:"server_version"`
}

type syncOperation struct {
	ID        string     `json:"id"`
	Kind      string     `json:"kind"`
	Task      store.Task `json:"task"`
	CreatedAt time.Time  `json:"created_at"`
}

const (
	syncKindCreate = "create"
	syncKindUpdate = "update"
	syncKindDelete = "delete"
)

func (o syncOperation) validate() error {
	if strings.TrimSpace(o.ID) == "" {
		return fmt.Errorf("operation id is required")
	}
	if o.CreatedAt.IsZero() {
		return fmt.Errorf("operation created_at is required")
	}
	switch o.Kind {
	case syncKindCreate, syncKindUpdate:
		return nil
	case syncKindDelete:
		if o.Task.DeletedAt == nil {
			return fmt.Errorf("delete operation requires task.deleted_at")
		}
		return nil
	default:
		return fmt.Errorf("operation kind must be create, update, or delete")
	}
}

func userIDFromContext(ctx context.Context) string {
	value, _ := ctx.Value(userIDKey{}).(string)
	return value
}

func parseSinceVersion(r *http.Request) (int64, error) {
	raw := r.URL.Query().Get("since_version")
	if raw == "" {
		return 0, nil
	}
	value, err := strconv.ParseInt(raw, 10, 64)
	if err != nil || value < 0 {
		return 0, fmt.Errorf("since_version must be a non-negative integer")
	}
	return value, nil
}

func decodeJSON(r *http.Request, dst any) error {
	defer r.Body.Close()
	decoder := json.NewDecoder(io.LimitReader(r.Body, 1<<20))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(dst); err != nil {
		return err
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return fmt.Errorf("request body must contain a single JSON object")
	}
	return nil
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

func writeError(w http.ResponseWriter, status int, code string, message string) {
	writeJSON(w, status, map[string]any{
		"error": map[string]string{
			"code":    code,
			"message": message,
		},
	})
}
