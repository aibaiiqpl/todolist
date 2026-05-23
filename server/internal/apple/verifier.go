package apple

import (
	"context"
	"errors"
)

var ErrInvalidIdentityToken = errors.New("invalid apple identity token")

type Claims struct {
	Subject string
	Email   *string
}

type Verifier interface {
	Verify(ctx context.Context, identityToken string) (Claims, error)
}

type UnimplementedVerifier struct{}

func (UnimplementedVerifier) Verify(ctx context.Context, identityToken string) (Claims, error) {
	return Claims{}, ErrInvalidIdentityToken
}
