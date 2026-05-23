package apple

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestJWKSVerifierValidToken(t *testing.T) {
	privateKey := generateKey(t)
	jwksServer := serveJWKS(t, privateKey, "apple-key")
	verifier := newTestVerifier(t, jwksServer.URL)
	email := "user@example.test"
	token := signIdentityToken(t, privateKey, "apple-key", jwtClaims{
		Issuer:    issuer,
		Subject:   "apple-subject",
		Audience:  audience{"com.example.todolist"},
		ExpiresAt: time.Now().Add(time.Hour).Unix(),
		IssuedAt:  time.Now().Add(-time.Minute).Unix(),
		Email:     &email,
	})

	claims, err := verifier.Verify(context.Background(), token)
	if err != nil {
		t.Fatal(err)
	}
	if claims.Subject != "apple-subject" {
		t.Fatalf("subject = %q, want apple-subject", claims.Subject)
	}
	if claims.Email == nil || *claims.Email != email {
		t.Fatalf("email = %v, want %q", claims.Email, email)
	}
}

func TestJWKSVerifierRejectsWrongAudience(t *testing.T) {
	privateKey := generateKey(t)
	jwksServer := serveJWKS(t, privateKey, "apple-key")
	verifier := newTestVerifier(t, jwksServer.URL)
	token := signIdentityToken(t, privateKey, "apple-key", jwtClaims{
		Issuer:    issuer,
		Subject:   "apple-subject",
		Audience:  audience{"wrong.bundle.id"},
		ExpiresAt: time.Now().Add(time.Hour).Unix(),
		IssuedAt:  time.Now().Add(-time.Minute).Unix(),
	})

	if _, err := verifier.Verify(context.Background(), token); err == nil {
		t.Fatal("expected wrong audience to fail")
	}
}

func TestJWKSVerifierRejectsUnknownKeyID(t *testing.T) {
	privateKey := generateKey(t)
	jwksServer := serveJWKS(t, privateKey, "apple-key")
	verifier := newTestVerifier(t, jwksServer.URL)
	token := signIdentityToken(t, privateKey, "unknown-key", jwtClaims{
		Issuer:    issuer,
		Subject:   "apple-subject",
		Audience:  audience{"com.example.todolist"},
		ExpiresAt: time.Now().Add(time.Hour).Unix(),
		IssuedAt:  time.Now().Add(-time.Minute).Unix(),
	})

	if _, err := verifier.Verify(context.Background(), token); err == nil {
		t.Fatal("expected unknown kid to fail")
	}
}

func TestJWKSVerifierRejectsInvalidSignature(t *testing.T) {
	jwksKey := generateKey(t)
	signingKey := generateKey(t)
	jwksServer := serveJWKS(t, jwksKey, "apple-key")
	verifier := newTestVerifier(t, jwksServer.URL)
	token := signIdentityToken(t, signingKey, "apple-key", jwtClaims{
		Issuer:    issuer,
		Subject:   "apple-subject",
		Audience:  audience{"com.example.todolist"},
		ExpiresAt: time.Now().Add(time.Hour).Unix(),
		IssuedAt:  time.Now().Add(-time.Minute).Unix(),
	})

	if _, err := verifier.Verify(context.Background(), token); err == nil {
		t.Fatal("expected invalid signature to fail")
	}
}

func newTestVerifier(t *testing.T, jwksURL string) *JWKSVerifier {
	t.Helper()
	verifier, err := NewJWKSVerifierWithURL([]string{"com.example.todolist"}, jwksURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	return verifier
}

func TestJWKSVerifierAcceptsAnyConfiguredAudience(t *testing.T) {
	privateKey := generateKey(t)
	jwksServer := serveJWKS(t, privateKey, "apple-key")
	verifier, err := NewJWKSVerifierWithURL(
		[]string{"com.example.todolist.ios", "com.example.todolist.macos"},
		jwksServer.URL,
		nil,
	)
	if err != nil {
		t.Fatal(err)
	}
	token := signIdentityToken(t, privateKey, "apple-key", jwtClaims{
		Issuer:    issuer,
		Subject:   "apple-subject",
		Audience:  audience{"com.example.todolist.macos"},
		ExpiresAt: time.Now().Add(time.Hour).Unix(),
		IssuedAt:  time.Now().Add(-time.Minute).Unix(),
	})

	if _, err := verifier.Verify(context.Background(), token); err != nil {
		t.Fatal(err)
	}
}

func TestAudiencesFromEnvSplitsCommaSeparatedValues(t *testing.T) {
	got := AudiencesFromEnv(" com.example.ios,com.example.macos,com.example.ios ")
	want := []string{"com.example.ios", "com.example.macos"}
	if len(got) != len(want) {
		t.Fatalf("audiences = %+v, want %+v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("audiences = %+v, want %+v", got, want)
		}
	}
}

func generateKey(t *testing.T) *rsa.PrivateKey {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	return key
}

func serveJWKS(t *testing.T, key *rsa.PrivateKey, kid string) *httptest.Server {
	t.Helper()
	jwks := jwksResponse{Keys: []jwk{{
		KeyType:   "RSA",
		KeyID:     kid,
		Algorithm: "RS256",
		Use:       "sig",
		Modulus:   base64.RawURLEncoding.EncodeToString(key.PublicKey.N.Bytes()),
		Exponent:  base64.RawURLEncoding.EncodeToString(big.NewInt(int64(key.PublicKey.E)).Bytes()),
	}}}
	body, err := json.Marshal(jwks)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write(body)
	}))
	t.Cleanup(server.Close)
	return server
}

func signIdentityToken(t *testing.T, key *rsa.PrivateKey, kid string, claims jwtClaims) string {
	t.Helper()
	header := jwtHeader{Algorithm: "RS256", KeyID: kid}
	headerJSON, err := json.Marshal(header)
	if err != nil {
		t.Fatal(err)
	}
	claimsJSON, err := json.Marshal(claims)
	if err != nil {
		t.Fatal(err)
	}
	signingInput := base64.RawURLEncoding.EncodeToString(headerJSON) + "." + base64.RawURLEncoding.EncodeToString(claimsJSON)
	digest := sha256.Sum256([]byte(signingInput))
	signature, err := rsa.SignPKCS1v15(rand.Reader, key, crypto.SHA256, digest[:])
	if err != nil {
		t.Fatal(err)
	}
	return signingInput + "." + base64.RawURLEncoding.EncodeToString(signature)
}

func TestAudienceAcceptsStringOrArray(t *testing.T) {
	for _, raw := range []string{`"com.example.todolist"`, `["com.example.todolist"]`} {
		var aud audience
		if err := json.Unmarshal([]byte(raw), &aud); err != nil {
			t.Fatal(err)
		}
		if !aud.Contains("com.example.todolist") {
			t.Fatalf("audience %s did not contain expected value", raw)
		}
	}
}

func TestJWKSVerifierRejectsExpiredToken(t *testing.T) {
	privateKey := generateKey(t)
	jwksServer := serveJWKS(t, privateKey, "apple-key")
	verifier := newTestVerifier(t, jwksServer.URL)
	token := signIdentityToken(t, privateKey, "apple-key", jwtClaims{
		Issuer:    issuer,
		Subject:   "apple-subject",
		Audience:  audience{"com.example.todolist"},
		ExpiresAt: time.Now().Add(-10 * time.Minute).Unix(),
		IssuedAt:  time.Now().Add(-time.Hour).Unix(),
	})

	if _, err := verifier.Verify(context.Background(), token); err == nil {
		t.Fatal("expected expired token to fail")
	}
}
