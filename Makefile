SHELL := /bin/bash

IOS_PROJECT := apps/ios/TodoList.xcodeproj
IOS_SCHEME := TodoList
IOS_DESTINATION := generic/platform=iOS Simulator

TODO_API_BASE_URL ?= http://127.0.0.1:8080
APP_GROUP_IDENTIFIER ?= group.local.todolist
TODO_APP_BUNDLE_ID ?= local.todolist.ios
TODO_WIDGET_BUNDLE_ID ?= local.todolist.ios.widget
APPLE_DEVELOPMENT_TEAM ?=
SERVER_ADDR ?= :8080
SERVER_JWT_SECRET ?= local-dev-secret
SERVER_APPLE_BUNDLE_IDS ?= local.todolist.ios,local.todolist.macos
SERVER_DEEPSEEK_API_KEY ?= local-dev-key
SERVER_DEEPSEEK_MODEL ?= deepseek-chat
SQLITE_PATH ?= todolist.sqlite

.PHONY: help check server-test server-vet swift-test macos-build ios-build apple-build clean

help:
	@printf '%s\n' \
		'Targets:' \
		'  make check        Run all local checks available on this machine' \
		'  make server-test  Run Go backend tests' \
		'  make server-vet   Run Go vet' \
		'  make server-run   Run the Go backend with local SQLite' \
		'  make swift-test   Run shared Swift tests' \
		'  make macos-build  Build the macOS menu bar app' \
		'  make ios-build    Build the iOS app for simulator' \
		'  make apple-build  Run Swift tests plus macOS and iOS builds' \
		'  make clean        Remove common local build artifacts'

check: server-test server-vet apple-build

server-test:
	cd server && go test ./...

server-vet:
	cd server && go vet ./...

server-run:
	cd server && \
		ADDR="$(SERVER_ADDR)" \
		DATABASE_DRIVER=sqlite \
		SQLITE_PATH="$(SQLITE_PATH)" \
		JWT_SECRET="$(SERVER_JWT_SECRET)" \
		APPLE_BUNDLE_IDS="$(SERVER_APPLE_BUNDLE_IDS)" \
		DEEPSEEK_API_KEY="$(SERVER_DEEPSEEK_API_KEY)" \
		DEEPSEEK_MODEL="$(SERVER_DEEPSEEK_MODEL)" \
		go run ./cmd/server

swift-test:
	cd shared/swift && swift test

macos-build:
	cd apps/macos && swift build

ios-build:
	xcodebuild \
		-project "$(IOS_PROJECT)" \
		-scheme "$(IOS_SCHEME)" \
		-destination "$(IOS_DESTINATION)" \
		CODE_SIGNING_ALLOWED=NO \
		TODO_API_BASE_URL="$(TODO_API_BASE_URL)" \
		APP_GROUP_IDENTIFIER="$(APP_GROUP_IDENTIFIER)" \
		TODO_APP_BUNDLE_ID="$(TODO_APP_BUNDLE_ID)" \
		TODO_WIDGET_BUNDLE_ID="$(TODO_WIDGET_BUNDLE_ID)" \
		APPLE_DEVELOPMENT_TEAM="$(APPLE_DEVELOPMENT_TEAM)" \
		build

apple-build: swift-test macos-build ios-build

clean:
	cd shared/swift && swift package clean || true
	cd apps/macos && swift package clean || true
	rm -rf apps/ios/build
