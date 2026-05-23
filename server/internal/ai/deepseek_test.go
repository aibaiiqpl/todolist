package ai

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestDeepSeekInvalidJSONReturnsError(t *testing.T) {
	client, err := newDeepSeekClient("test-key", DefaultDeepSeekModel, &http.Client{
		Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
			return &http.Response{
				StatusCode: http.StatusOK,
				Body:       io.NopCloser(strings.NewReader(`{"choices":[{"message":{"content":"not-json"}}]}`)),
				Header:     make(http.Header),
			}, nil
		}),
	})
	if err != nil {
		t.Fatal(err)
	}

	_, err = client.Organize(context.Background(), "tomorrow pay rent")
	if !errors.Is(err, ErrInvalidModelJSON) {
		t.Fatalf("error = %v, want %v", err, ErrInvalidModelJSON)
	}
}

func TestDeepSeekParsesMultipleTasksWithDateAndPriority(t *testing.T) {
	client, err := newDeepSeekClient("test-key", DefaultDeepSeekModel, &http.Client{
		Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
			return &http.Response{
				StatusCode: http.StatusOK,
				Body:       io.NopCloser(strings.NewReader(`{"choices":[{"message":{"content":"{\"tasks\":[{\"title\":\"Prepare launch notes\",\"importance\":5,\"urgency\":4,\"due_at\":\"2026-05-24T09:00:00Z\",\"source_text\":\"tomorrow morning prepare launch notes\"},{\"title\":\"Buy coffee\",\"importance\":1,\"urgency\":2,\"due_at\":null,\"source_text\":\"buy coffee sometime\"}]}"}}]}`)),
				Header:     make(http.Header),
			}, nil
		}),
	})
	if err != nil {
		t.Fatal(err)
	}

	drafts, err := client.Organize(context.Background(), "tomorrow morning prepare launch notes and buy coffee sometime")
	if err != nil {
		t.Fatal(err)
	}

	if len(drafts) != 2 {
		t.Fatalf("draft count = %d, want 2", len(drafts))
	}
	if drafts[0].Title != "Prepare launch notes" || drafts[0].Importance != 5 || drafts[0].Urgency != 4 {
		t.Fatalf("first draft = %+v", drafts[0])
	}
	if drafts[0].DueAt == nil || drafts[0].DueAt.Format("2006-01-02T15:04:05Z07:00") != "2026-05-24T09:00:00Z" {
		t.Fatalf("first draft due_at = %v", drafts[0].DueAt)
	}
	if drafts[1].Title != "Buy coffee" || drafts[1].DueAt != nil {
		t.Fatalf("second draft = %+v", drafts[1])
	}
}

func TestDeepSeekParsesTaskWithoutDate(t *testing.T) {
	client, err := newDeepSeekClient("test-key", DefaultDeepSeekModel, &http.Client{
		Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
			return &http.Response{
				StatusCode: http.StatusOK,
				Body:       io.NopCloser(strings.NewReader(`{"choices":[{"message":{"content":"{\"tasks\":[{\"title\":\"Review notes\",\"importance\":3,\"urgency\":2,\"due_at\":null,\"source_text\":\"review notes\"}]}"}}]}`)),
				Header:     make(http.Header),
			}, nil
		}),
	})
	if err != nil {
		t.Fatal(err)
	}

	drafts, err := client.Organize(context.Background(), "review notes")
	if err != nil {
		t.Fatal(err)
	}

	if len(drafts) != 1 {
		t.Fatalf("draft count = %d, want 1", len(drafts))
	}
	if drafts[0].DueAt != nil {
		t.Fatalf("due_at = %v, want nil", drafts[0].DueAt)
	}
}

func TestDeepSeekMissingAPIKeyReturnsError(t *testing.T) {
	_, err := newDeepSeekClient("", DefaultDeepSeekModel, nil)
	if !errors.Is(err, ErrMissingAPIKey) {
		t.Fatalf("error = %v, want %v", err, ErrMissingAPIKey)
	}
}

func TestNewDeepSeekClientFromEnvUsesModelOverride(t *testing.T) {
	t.Setenv("DEEPSEEK_API_KEY", "test-key")
	t.Setenv("DEEPSEEK_MODEL", "env-model")

	client, err := NewDeepSeekClientFromEnv()
	if err != nil {
		t.Fatal(err)
	}
	if client.model != "env-model" {
		t.Fatalf("model = %q, want env-model", client.model)
	}
}

func TestDeepSeekUsesConfiguredModel(t *testing.T) {
	var gotModel string
	client, err := newDeepSeekClient("test-key", "custom-model", &http.Client{
		Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
			var body struct {
				Model string `json:"model"`
			}
			if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
				t.Fatal(err)
			}
			gotModel = body.Model
			return &http.Response{
				StatusCode: http.StatusOK,
				Body:       io.NopCloser(strings.NewReader(`{"choices":[{"message":{"content":"{\"tasks\":[{\"title\":\"Pay rent\",\"importance\":3,\"urgency\":4,\"due_at\":null,\"source_text\":\"pay rent\"}]}"}}]}`)),
				Header:     make(http.Header),
			}, nil
		}),
	})
	if err != nil {
		t.Fatal(err)
	}

	if _, err := client.Organize(context.Background(), "pay rent"); err != nil {
		t.Fatal(err)
	}
	if gotModel != "custom-model" {
		t.Fatalf("model = %q, want custom-model", gotModel)
	}
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(req *http.Request) (*http.Response, error) {
	return f(req)
}
