# Elaro Quickstart

## Prerequisites
- Node.js 20+
- Salesforce CLI (`sf`)
- A Salesforce DevHub org (for scratch orgs)

## Setup (One Command)

    git clone <repo-url> && cd elaro
    npm run setup

This creates a scratch org, deploys all metadata, assigns permissions, loads sample data, and opens the app.

## Common Commands

| Command | Description |
|---------|-------------|
| `npm run setup` | Full environment setup |
| `npm run sf:deploy` | Deploy to scratch org |
| `npm run test:unit` | Run LWC Jest tests |
| `npm run test:apex` | Run Apex tests with coverage |
| `npm run lint` | Run ESLint |
| `npm run fmt` | Format code with Prettier |
| `npm run org:open` | Open scratch org in browser |
| `npm run org:create` | Create new scratch org |
| `npm run precommit` | Run all pre-commit checks |

## Platform CLI

    npm run cli:install
    elaro scan --framework SOC2 --target-org elaro-dev
    elaro status

## Project Structure

- `force-app/` — Main Elaro managed package (Apex, LWC, objects)
- `force-app-healthcheck/` — Separate Health Check 2GP
- `platform/` — TypeScript monorepo (CLI, API client, masking engine)
- `scripts/` — Automation scripts
- `config/` — Salesforce project config
