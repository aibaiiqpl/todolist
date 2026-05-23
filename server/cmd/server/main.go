package main

import (
	"context"
	"database/sql"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"

	"todolist/server/internal/ai"
	"todolist/server/internal/apple"
	"todolist/server/internal/auth"
	"todolist/server/internal/httpapi"
	"todolist/server/internal/store"
)

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() error {
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		return errors.New("DATABASE_URL is required")
	}

	db, err := sql.Open("pgx", databaseURL)
	if err != nil {
		return err
	}
	defer db.Close()

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	if err := db.PingContext(ctx); err != nil {
		return err
	}

	jwtSigner, err := auth.NewJWT(os.Getenv("JWT_SECRET"))
	if err != nil {
		return err
	}

	appleAudiences := apple.AudiencesFromEnv(os.Getenv("APPLE_BUNDLE_IDS"))
	if len(appleAudiences) == 0 {
		appleAudiences = apple.AudiencesFromEnv(os.Getenv("APPLE_BUNDLE_ID"))
	}
	if len(appleAudiences) == 0 {
		return errors.New("APPLE_BUNDLE_IDS is required")
	}
	appleVerifier, err := apple.NewJWKSVerifier(appleAudiences)
	if err != nil {
		return err
	}

	organizer, err := ai.NewDeepSeekClientFromEnv()
	if err != nil {
		return err
	}

	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}

	api := httpapi.New(store.NewPostgresStore(db), jwtSigner, appleVerifier, organizer)
	server := &http.Server{
		Addr:              addr,
		Handler:           api.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		log.Printf("listening on %s", addr)
		errCh <- server.ListenAndServe()
	}()

	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		return server.Shutdown(shutdownCtx)
	case err := <-errCh:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	}
}
