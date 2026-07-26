package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

var (
	ErrMissingAPIKey    = errors.New("deepseek api key is required")
	ErrInvalidModelJSON = errors.New("deepseek returned invalid task json")
)

const DefaultDeepSeekModel = "deepseek-chat"
const DefaultDeepSeekBaseURL = "https://api.deepseek.com/chat/completions"

type Draft struct {
	Title      string     `json:"title"`
	Importance int        `json:"importance"`
	Urgency    int        `json:"urgency"`
	DueAt      *time.Time `json:"due_at,omitempty"`
	SourceText string     `json:"source_text"`
}

type Organizer interface {
	Organize(ctx context.Context, text string) ([]Draft, error)
}

type DeepSeekClient struct {
	apiKey     string
	model      string
	baseURL    string
	httpClient *http.Client
}

func NewDeepSeekClientFromEnv() (*DeepSeekClient, error) {
	model := os.Getenv("DEEPSEEK_MODEL")
	if model == "" {
		model = DefaultDeepSeekModel
	}
	baseURL := os.Getenv("DEEPSEEK_BASE_URL")
	if baseURL == "" {
		baseURL = DefaultDeepSeekBaseURL
	}
	return newDeepSeekClient(os.Getenv("DEEPSEEK_API_KEY"), model, baseURL, nil)
}

func newDeepSeekClient(apiKey string, model string, baseURL string, httpClient *http.Client) (*DeepSeekClient, error) {
	if apiKey == "" {
		return nil, ErrMissingAPIKey
	}
	if model == "" {
		model = DefaultDeepSeekModel
	}
	if baseURL == "" {
		baseURL = DefaultDeepSeekBaseURL
	}
	parsedURL, err := url.ParseRequestURI(baseURL)
	if err != nil || parsedURL.Scheme == "" || parsedURL.Host == "" {
		return nil, fmt.Errorf("deepseek base url is invalid")
	}
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 20 * time.Second}
	}
	return &DeepSeekClient{
		apiKey:     apiKey,
		model:      model,
		baseURL:    baseURL,
		httpClient: httpClient,
	}, nil
}

func (c *DeepSeekClient) Organize(ctx context.Context, text string) ([]Draft, error) {
	if strings.TrimSpace(text) == "" {
		return nil, fmt.Errorf("input text is required")
	}

	body := chatRequest{
		Model: c.model,
		Messages: []chatMessage{
			{Role: "system", Content: prompt},
			{Role: "user", Content: text},
		},
		Temperature:    0.2,
		ResponseFormat: map[string]string{"type": "json_object"},
	}
	encoded, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL, bytes.NewReader(encoded))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("deepseek request failed: status %d", resp.StatusCode)
	}

	var completion chatResponse
	if err := json.Unmarshal(respBody, &completion); err != nil {
		return nil, fmt.Errorf("decode deepseek response: %w", err)
	}
	if len(completion.Choices) == 0 {
		return nil, fmt.Errorf("deepseek response has no choices")
	}

	return parseDrafts(completion.Choices[0].Message.Content)
}

func parseDrafts(content string) ([]Draft, error) {
	var output struct {
		Tasks []draftWire `json:"tasks"`
	}
	decoder := json.NewDecoder(strings.NewReader(content))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&output); err != nil {
		return nil, ErrInvalidModelJSON
	}
	if len(output.Tasks) == 0 {
		return nil, ErrInvalidModelJSON
	}

	drafts := make([]Draft, 0, len(output.Tasks))
	for _, task := range output.Tasks {
		draft, err := task.toDraft()
		if err != nil {
			return nil, ErrInvalidModelJSON
		}
		drafts = append(drafts, draft)
	}
	return drafts, nil
}

type draftWire struct {
	Title      string  `json:"title"`
	Importance int     `json:"importance"`
	Urgency    int     `json:"urgency"`
	DueAt      *string `json:"due_at"`
	SourceText string  `json:"source_text"`
}

func (d draftWire) toDraft() (Draft, error) {
	title := strings.TrimSpace(d.Title)
	sourceText := strings.TrimSpace(d.SourceText)
	if title == "" || sourceText == "" {
		return Draft{}, fmt.Errorf("title and source_text are required")
	}
	if d.Importance < 1 || d.Importance > 5 || d.Urgency < 1 || d.Urgency > 5 {
		return Draft{}, fmt.Errorf("importance and urgency must be between 1 and 5")
	}

	var dueAt *time.Time
	if d.DueAt != nil && strings.TrimSpace(*d.DueAt) != "" {
		parsed, err := time.Parse(time.RFC3339, *d.DueAt)
		if err != nil {
			return Draft{}, err
		}
		dueAt = &parsed
	}

	return Draft{
		Title:      title,
		Importance: d.Importance,
		Urgency:    d.Urgency,
		DueAt:      dueAt,
		SourceText: sourceText,
	}, nil
}

type chatRequest struct {
	Model          string            `json:"model"`
	Messages       []chatMessage     `json:"messages"`
	Temperature    float64           `json:"temperature"`
	ResponseFormat map[string]string `json:"response_format"`
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatResponse struct {
	Choices []struct {
		Message chatMessage `json:"message"`
	} `json:"choices"`
}

const prompt = `You turn natural language into todo task JSON.
Return exactly one JSON object with this shape:
{"tasks":[{"title":"string","importance":1,"urgency":1,"due_at":null,"source_text":"string"}]}
importance and urgency are integers from 1 to 5. due_at must be RFC3339 or null.`
