# ADR 001: Architecture Decisions for Autenticación JWT y Creación de Pedidos en Rails 7 API

## Status
Accepted

## Context
Project requiring structured implementation matching Gherkin specification.

## Decisions
- **Architecture Style**: Monolith Architecture (MVC / Monolithic) (monolith)
- **Primary Backend Language**: ruby
- **Backend Framework**: rails (Ruby 3.3+)
- **ORM / Persistence**: ruby-orm (active_record ^7.1)
- **Validation**: active-model (active_model)
- **Authentication**: jwt-bcrypt (bcrypt cost factor 12, JWT TTL 3600s)
- **Backend Testing Framework**: rspec (rspec-rails ^6.1)
- **Frontend Framework**: react
- **Frontend Language**: javascript
- **Frontend Bundler**: vite
- **Frontend Unit Testing**: vitest
- **Frontend E2E Testing**: cypress

## Prohibited Layer Dependencies
Domain core must NOT import:
- `direct SQL string interpolation`
- `global state mutation`
