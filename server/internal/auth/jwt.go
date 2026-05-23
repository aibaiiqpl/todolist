package auth

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
)

var ErrInvalidToken = errors.New("invalid token")

type JWT struct {
	secret []byte
	now    func() time.Time
}

func NewJWT(secret string) (*JWT, error) {
	if secret == "" {
		return nil, fmt.Errorf("jwt secret is required")
	}
	return &JWT{secret: []byte(secret), now: func() time.Time { return time.Now().UTC() }}, nil
}

func (j *JWT) Sign(userID string, ttl time.Duration) (string, error) {
	return j.SignUntil(userID, j.now().Add(ttl))
}

func (j *JWT) SignUntil(userID string, expiresAt time.Time) (string, error) {
	if userID == "" {
		return "", fmt.Errorf("user id is required")
	}
	header := map[string]string{"alg": "HS256", "typ": "JWT"}
	now := j.now()
	claims := map[string]any{
		"sub": userID,
		"iat": now.Unix(),
		"exp": expiresAt.Unix(),
	}

	headerJSON, err := json.Marshal(header)
	if err != nil {
		return "", err
	}
	claimsJSON, err := json.Marshal(claims)
	if err != nil {
		return "", err
	}

	unsigned := base64.RawURLEncoding.EncodeToString(headerJSON) + "." + base64.RawURLEncoding.EncodeToString(claimsJSON)
	return unsigned + "." + j.signature(unsigned), nil
}

func (j *JWT) Verify(token string) (string, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return "", ErrInvalidToken
	}

	unsigned := parts[0] + "." + parts[1]
	if !hmac.Equal([]byte(parts[2]), []byte(j.signature(unsigned))) {
		return "", ErrInvalidToken
	}

	claimsJSON, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return "", ErrInvalidToken
	}
	var claims struct {
		Subject string `json:"sub"`
		Expires int64  `json:"exp"`
	}
	if err := json.Unmarshal(claimsJSON, &claims); err != nil {
		return "", ErrInvalidToken
	}
	if claims.Subject == "" || claims.Expires <= j.now().Unix() {
		return "", ErrInvalidToken
	}
	return claims.Subject, nil
}

func (j *JWT) signature(unsigned string) string {
	mac := hmac.New(sha256.New, j.secret)
	mac.Write([]byte(unsigned))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}
