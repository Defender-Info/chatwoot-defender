# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Stack

- **Backend**: Ruby on Rails (REST API + Action Cable WebSockets)
- **Frontend**: Vue 3 (Composition API, `<script setup>`) + Pinia + Vue Router
- **Build**: Vite + vite-plugin-ruby (multiple entry points)
- **Styling**: Tailwind CSS only
- **Queue**: Sidekiq
- **DB**: PostgreSQL
- **Ruby**: 3.4.4 (rbenv, see `.ruby-version`)
- **Node**: 23.7.0 (see `.nvmrc`), package manager: pnpm 10.2.0+

## Commands

```bash
# Setup
bundle install && pnpm install

# Dev server (runs Rails + Sidekiq + Vite)
pnpm dev                            # or: overmind start -f Procfile.dev

# Lint
pnpm eslint                         # check JS/Vue
pnpm eslint:fix                     # auto-fix JS/Vue
bundle exec rubocop -a              # auto-fix Ruby

# Test JS (Vitest)
pnpm test
pnpm test:watch
pnpm test -- path/to/file.spec.js   # single file

# Test Ruby (RSpec)
bundle exec rspec spec/path/to/file_spec.rb
bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER  # single test

# Database
make db           # db:chatwoot_prepare
make db_migrate
make db_seed
make db_reset
```

Always use `bundle exec` for Ruby CLI tasks. Init rbenv before running them: `eval "$(rbenv init -)"`.

## Architecture

### Backend (`app/`)

Rails follows a layered structure:
- `controllers/` → `services/` → `models/` (business logic lives in services, not controllers)
- `policies/` — Pundit authorization
- `presenters/` — API response formatting
- `jobs/` — Sidekiq async jobs
- `channels/` — Action Cable (real-time)
- `builders/`, `dispatchers/`, `listeners/` — domain events and object construction
- `mailboxes/` — inbound email ingestion (ActionMailbox)
- `lib/custom_exceptions/` — centralized error types

### Frontend (`app/javascript/`)

Multiple Vite entry points, each a separate app:
- `dashboard/` — main agent/admin UI (being progressively migrated to `v3/`)
- `widget/` — embeddable chat widget (bundle limit: 300KB)
- `portal/` — public help center
- `survey/` — customer surveys
- `sdk/` — standalone JS SDK (bundle limit: 40KB, builds as IIFE)
- `v3/` — next-gen components (use `components-next/` for message bubbles)
- `shared/` — composables, helpers, constants shared across apps
- `design-system/` — component library

### Enterprise Edition (`enterprise/`)

An overlay that extends/overrides OSS code without forking it:
- Always search both trees before editing: `rg -n "ClassName" app enterprise`
- Add Enterprise behavior via `prepend_mod_with`/`include_mod_with` modules, not by editing OSS files directly
- New endpoints/services may need a corresponding override or extension point in `enterprise/`
- Mirror renamed/moved OSS files in `enterprise/` to prevent drift
- Enterprise specs live under `spec/enterprise/`, mirroring OSS spec layout
- Reference: https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38

## Code Style

- **Ruby**: RuboCop rules apply (150 char max line length); compact `module/class` definitions
- **Vue**: Composition API with `<script setup>` always; PascalCase components; camelCase events
- **Tailwind only**: no custom CSS, no scoped CSS, no inline styles; see `tailwind.config.js` for color tokens
- **I18n**: no bare strings in templates; backend → `en.yml`, frontend → `en.json` (other locales handled by community)
- **Error handling**: use `lib/custom_exceptions/`

## Commit Messages

Conventional Commits format: `type(scope): subject` (scope optional).
Do not reference Claude in commit messages.

## Development Philosophy

- MVP focus: least code change, happy-path first
- No unnecessary defensive programming or premature abstractions
- Break complex tasks into small, testable units; iterate after confirmation
- Avoid writing specs unless explicitly asked
- Remove dead/unreachable/unused code
- Don't write multiple versions of the same logic — pick one and commit
- In specs: prefer `with_modified_env` over stubbing `ENV` directly; compare `error.class.name` over constant class equality in parallel/reloading environments
