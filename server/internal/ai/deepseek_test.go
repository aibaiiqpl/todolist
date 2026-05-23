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
