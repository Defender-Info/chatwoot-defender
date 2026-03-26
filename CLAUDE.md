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

## Deployment

### Infrastructure
- **Runtime**: Docker Swarm no VPS (`manager1`)
- **Image registry**: `ghcr.io/defender-info/chatwoot-defender`
- **Services**: `chatdef_chatwoot_app` (Rails) e `chatdef_chatwoot_worker` (Sidekiq)
- **Proxy/SSL**: Traefik
- **WhatsApp**: Evolution API (`evo.defenderinfo.com`) integrado via API channel

### CI/CD (`.github/workflows/deploy-vps.yml`)
- Roda em push para `feat/custom-branding`, `develop` ou `master`
- **Build** da imagem Docker → push para GHCR (sempre)
- **Deploy automático** no VPS via SSH → apenas quando a branch é `develop`
- O deploy: faz pull da imagem, atualiza a stack Swarm, limpa o volume `chatwoot_public`, força recreate dos serviços

### Fluxo para subir alterações em produção
```bash
# 1. Commit e push na branch de trabalho
git add <arquivos>
git commit -m "tipo: descrição"
git push origin feat/custom-branding

# 2. Merge para develop (dispara o deploy automático)
git checkout develop
git merge feat/custom-branding
git push origin develop --no-verify   # --no-verify pula o hook husky local
git checkout feat/custom-branding
```

O hook husky (`bin/validate_push`) bloqueia push direto em `develop` e `master` localmente — use `--no-verify` para contornar. O GitHub não tem branch protection configurado.

### Deploy manual no VPS (se necessário)
```bash
docker service update --image ghcr.io/defender-info/chatwoot-defender:develop chatdef_chatwoot_app
docker service update --image ghcr.io/defender-info/chatwoot-defender:develop chatdef_chatwoot_worker
```

## Evolution API / WhatsApp

A inbox do WhatsApp usa `Channel::Api` apontando para a Evolution API (`evo.defenderinfo.com`).

### Fluxo de mensagens outgoing
1. Agente envia mensagem no Chatwoot → `WebhookListener` dispara webhook para a Evolution API
2. O payload usa `Message#webhook_data` → `MessageContentPresenter#outgoing_content`
3. `MessageContentPresenter` prefixa o nome do agente (formato `*Nome:*\n`) em mensagens outgoing de usuários humanos em `Channel::Api`
4. Evolution API envia para o WhatsApp

### Echo (deduplicação)
A Evolution API v2.3.7 não tem opção de ignorar mensagens `fromMe`. Quando o WhatsApp confirma entrega, a Evolution reenvia a mensagem de volta ao Chatwoot via API, criando duplicata.

O `Messages::MessageBuilder` detecta isso: se chegar uma mensagem `outgoing` em `Channel::Api` com o mesmo conteúdo de uma mensagem criada nos últimos 30 segundos na mesma conversa, retorna a mensagem existente sem criar nova.

### Formatação bold no WhatsApp
WhatsApp usa `*texto*` (asterisco simples) para **negrito**. `**texto**` não funciona corretamente. O prefixo do agente usa `*Nome:*\n#{texto}`.

## Development Philosophy

- MVP focus: least code change, happy-path first
- No unnecessary defensive programming or premature abstractions
- Break complex tasks into small, testable units; iterate after confirmation
- Avoid writing specs unless explicitly asked
- Remove dead/unreachable/unused code
- Don't write multiple versions of the same logic — pick one and commit
- In specs: prefer `with_modified_env` over stubbing `ENV` directly; compare `error.class.name` over constant class equality in parallel/reloading environments
