package apple

import (
	"context"
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"strings"
	"time"
)

const (
	DefaultJWKSURL = "https://appleid.apple.com/auth/keys"
	issuer         = "https://appleid.apple.com"
	clockSkew      = 5 * time.Minute
)

var ErrInvalidIdentityToken = errors.New("invalid apple identity token")

type Claims struct {
	Subject string
	Email   *string
}

type Verifier interface {
	Verify(ctx context.Context, identityToken string) (Claims, error)
}

type JWKSVerifier struct {
	audiences  []string
	jwksURL    string
	httpClient *http.Client
	now        func() time.Time
}

func NewJWKSVerifier(audiences []string) (*JWKSVerifier, error) {
	return NewJWKSVerifierWithURL(audiences, DefaultJWKSURL, nil)
}

func NewJWKSVerifierWithURL(audiences []string, jwksURL string, httpClient *http.Client) (*JWKSVerifier, error) {
	audiences = normalizeAudiences(audiences)
	if len(audiences) == 0 {
		return nil, fmt.Errorf("apple audience is required")
	}
	if strings.TrimSpace(jwksURL) == "" {
		return nil, fmt.Errorf("apple jwks url is required")
	}
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 10 * time.Second}
	}
	return &JWKSVerifier{
		audiences:  audiences,
		jwksURL:    jwksURL,
		httpClient: httpClient,
		now:        func() time.Time { return time.Now().UTC() },
	}, nil
}

func AudiencesFromEnv(value string) []string {
	return normalizeAudiences(strings.Split(value, ","))
}

func normalizeAudiences(values []string) []string {
	seen := map[string]struct{}{}
	var audiences []string
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		audiences = append(audiences, value)
	}
	return audiences
}

func (v *JWKSVerifier) Verify(ctx context.Context, identityToken string) (Claims, error) {
	header, claims, signingInput, signature, err := parseIdentityToken(identityToken)
	if err != nil {
		return Claims{}, err
	}
	if header.Algorithm != "RS256" || strings.TrimSpace(header.KeyID) == "" {
		return Claims{}, ErrInvalidIdentityToken
	}

	key, err := v.publicKey(ctx, header.KeyID)
	if err != nil {
		return Claims{}, err
	}
	digest := sha256.Sum256([]byte(signingInput))
	if err := rsa.VerifyPKCS1v15(key, crypto.SHA256, digest[:], signature); err != nil {
		return Claims{}, ErrInvalidIdentityToken
	}

	if err := v.validateClaims(claims); err != nil {
		return Claims{}, err
	}
	return Claims{Subject: claims.Subject, Email: claims.Email}, nil
}

func parseIdentityToken(identityToken string) (jwtHeader, jwtClaims, string, []byte, error) {
	parts := strings.Split(identityToken, ".")
	if len(parts) != 3 {
		return jwtHeader{}, jwtClaims{}, "", nil, ErrInvalidIdentityToken
	}

	headerJSON, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return jwtHeader{}, jwtClaims{}, "", nil, ErrInvalidIdentityToken
	}
	var header jwtHeader
	if err := json.Unmarshal(headerJSON, &header); err != nil {
		return jwtHeader{}, jwtClaims{}, "", nil, ErrInvalidIdentityToken
	}

	claimsJSON, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return jwtHeader{}, jwtClaims{}, "", nil, ErrInvalidIdentityToken
	}
	var claims jwtClaims
	if err := json.Unmarshal(claimsJSON, &claims); err != nil {
		return jwtHeader{}, jwtClaims{}, "", nil, ErrInvalidIdentityToken
	}

	signature, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return jwtHeader{}, jwtClaims{}, "", nil, ErrInvalidIdentityToken
	}

	return header, claims, parts[0] + "." + parts[1], signature, nil
}

func (v *JWKSVerifier) validateClaims(claims jwtClaims) error {
	now := v.now()
	if claims.Issuer != issuer {
		return ErrInvalidIdentityToken
	}
	if claims.Subject == "" {
		return ErrInvalidIdentityToken
	}
	if !claims.Audience.ContainsAny(v.audiences) {
		return ErrInvalidIdentityToken
	}
	if claims.ExpiresAt == 0 || time.Unix(claims.ExpiresAt, 0).Before(now.Add(-clockSkew)) {
		return ErrInvalidIdentityToken
	}
	if claims.IssuedAt == 0 || time.Unix(claims.IssuedAt, 0).After(now.Add(clockSkew)) {
		return ErrInvalidIdentityToken
	}
	if claims.NotBefore != nil && time.Unix(*claims.NotBefore, 0).After(now.Add(clockSkew)) {
		return ErrInvalidIdentityToken
	}
	return nil
}

func (v *JWKSVerifier) publicKey(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, v.jwksURL, nil)
	if err != nil {
		return nil, err
	}
	resp, err := v.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("apple jwks request failed: status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	var jwks jwksResponse
	if err := json.Unmarshal(body, &jwks); err != nil {
		return nil, err
	}
	for _, key := range jwks.Keys {
		if key.KeyID == kid {
			return key.publicKey()
		}
	}
	return nil, ErrInvalidIdentityToken
}

type jwtHeader struct {
	Algorithm string `json:"alg"`
	KeyID     string `json:"kid"`
}

type jwtClaims struct {
	Issuer    string   `json:"iss"`
	Subject   string   `json:"sub"`
	Audience  audience `json:"aud"`
	ExpiresAt int64    `json:"exp"`
	IssuedAt  int64    `json:"iat"`
	NotBefore *int64   `json:"nbf,omitempty"`
	Email     *string  `json:"email,omitempty"`
}

type audience []string

func (a *audience) UnmarshalJSON(data []byte) error {
	var one string
	if err := json.Unmarshal(data, &one); err == nil {
		*a = []string{one}
		return nil
	}
	var many []string
	if err := json.Unmarshal(data, &many); err != nil {
		return err
	}
	*a = many
	return nil
}

func (a audience) Contains(want string) bool {
	for _, got := range a {
		if got == want {
			return true
		}
	}
	return false
}

func (a audience) ContainsAny(wants []string) bool {
	for _, want := range wants {
		if a.Contains(want) {
			return true
		}
	}
	return false
}

type jwksResponse struct {
	Keys []jwk `json:"keys"`
}

type jwk struct {
	KeyType   string `json:"kty"`
	KeyID     string `json:"kid"`
	Algorithm string `json:"alg"`
	Use       string `json:"use"`
	Modulus   string `json:"n"`
	Exponent  string `json:"e"`
}

func (k jwk) publicKey() (*rsa.PublicKey, error) {
	if k.KeyType != "RSA" {
		return nil, ErrInvalidIdentityToken
	}
	if k.Algorithm != "" && k.Algorithm != "RS256" {
		return nil, ErrInvalidIdentityToken
	}
	if k.Use != "" && k.Use != "sig" {
		return nil, ErrInvalidIdentityToken
	}

	modulus, err := base64.RawURLEncoding.DecodeString(k.Modulus)
	if err != nil {
		return nil, ErrInvalidIdentityToken
	}
	exponent, err := base64.RawURLEncoding.DecodeString(k.Exponent)
	if err != nil {
		return nil, ErrInvalidIdentityToken
	}
	e := 0
	for _, b := range exponent {
		e = e<<8 + int(b)
	}
	if e == 0 {
		return nil, ErrInvalidIdentityToken
	}
	return &rsa.PublicKey{
		N: new(big.Int).SetBytes(modulus),
		E: e,
	}, nil
}
