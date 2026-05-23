# TodoList Server

Go REST JSON backend for the AI todo MVP.

## Run

Apply `migrations/001_init.sql` to Postgres, then start:

```sh
cd server
DATABASE_URL='postgres://user:pass@localhost:5432/todolist?sslmode=disable' \
JWT_SECRET='change-me' \
DEEPSEEK_API_KEY='...' \
DEEPSEEK_MODEL='deepseek-chat' \
go run ./cmd/server
```

`ADDR` is optional and defaults to `:8080`. `DEEPSEEK_MODEL` is optional and defaults to `deepseek-chat`.

## API

- `POST /auth/apple`
- `GET /tasks/changes?since_version=0`
- `POST /tasks/sync`
- `POST /ai/organize`

Protocol shape:

- `POST /auth/apple`: `{"identity_token":"..."}` -> `{"user_id":"...","access_token":"...","expires_at":"RFC3339"}`
- `POST /ai/organize`: `{"input":"natural language"}` -> `{"drafts":[...]}`
- `POST /tasks/sync`: `{"operations":[{"id":"operation-id","kind":"create|update|delete","task":{...},"created_at":"RFC3339"}]}` -> `{"acknowledged_operation_ids":[...],"tasks":[...],"server_version":1}`
- `GET /tasks/changes?since_version=0` -> `{"tasks":[...],"server_version":1}`

Apple token verification is isolated behind `apple.Verifier`. The current binary wires an explicit unimplemented verifier boundary; production should replace it with an Apple JWKS verifier without changing handlers or tests.
