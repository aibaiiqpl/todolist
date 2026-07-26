# TodoList Server

Go REST JSON backend for the AI todo MVP.

## Run

SQLite is the default local database. Start the server with:

```sh
cd server
JWT_SECRET='change-me' \
APPLE_BUNDLE_IDS='com.yourcompany.todolist.ios,com.yourcompany.todolist.macos' \
DEEPSEEK_API_KEY='...' \
DEEPSEEK_MODEL='deepseek-chat' \
DEEPSEEK_BASE_URL='https://api.deepseek.com/chat/completions' \
go run ./cmd/server
```

This creates `server/todolist.sqlite` when run from the `server` directory. `ADDR` is optional and defaults to `:8080`. `SQLITE_PATH` is optional and defaults to `todolist.sqlite`. `DEEPSEEK_MODEL` is optional and defaults to `deepseek-chat`. `DEEPSEEK_BASE_URL` is optional and defaults to DeepSeek's chat completions endpoint; set it to `https://integrate.api.nvidia.com/v1/chat/completions` when using NVIDIA's compatible API. NVIDIA model IDs include the provider prefix, for example `deepseek-ai/deepseek-v4-flash`. `APPLE_BUNDLE_IDS` is a comma-separated list of Sign in with Apple audiences; `APPLE_BUNDLE_ID` is still accepted for a single client.

To use Postgres later, set `DATABASE_DRIVER=postgres`, apply `migrations/001_init.sql`, and provide `DATABASE_URL`.

## systemd 部署示例

长期持久服务配置统一归 env_tools 管理。本仓库只提供应用级 unit 示例和环境变量说明，实际启停、重启策略和机器级编排应在 env_tools 中落地。

示例环境文件 `/etc/todolist/server.env`：

```env
ADDR=:8080
DATABASE_DRIVER=sqlite
SQLITE_PATH=/var/lib/todolist/todolist.sqlite
JWT_SECRET=change-me
APPLE_BUNDLE_IDS=com.yourcompany.todolist.ios,com.yourcompany.todolist.macos
DEEPSEEK_API_KEY=...
DEEPSEEK_MODEL=deepseek-chat
DEEPSEEK_BASE_URL=https://api.deepseek.com/chat/completions
```

示例 unit：

```ini
[Unit]
Description=TodoList API server
After=network-online.target postgresql.service
Wants=network-online.target

[Service]
Type=simple
User=todolist
WorkingDirectory=/opt/todolist/server
EnvironmentFile=/etc/todolist/server.env
ExecStart=/opt/todolist/server/todolist-server
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

SQLite 本地开发不需要手动迁移。Postgres 部署前先应用 `migrations/001_init.sql`，并确保 `APPLE_BUNDLE_IDS` 覆盖 iOS 与 macOS 客户端 Sign in with Apple 的 audience。

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

Apple token verification is isolated behind `apple.Verifier`. The production binary uses Apple's JWKS endpoint and validates `iss`, `aud`, `exp`, `iat`, and the RS256 signature. `APPLE_BUNDLE_IDS` must include every client bundle ID used as an identity token audience.
