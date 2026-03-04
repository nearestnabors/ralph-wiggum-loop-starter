# Spec: User Authentication API

## Overview
A simple REST API with user registration, login, and JWT-based authentication.
This is an example spec for the Ralph Wiggum Loop Starter — replace with your own.

## Tech Stack
- Runtime: Node.js with TypeScript
- Framework: Express
- Database: SQLite via better-sqlite3 (no ORM)
- Auth: JWT (jsonwebtoken)
- Validation: zod
- Testing: vitest + supertest

## Endpoints

### POST /register
- Accepts: `{ email: string, password: string, name: string }`
- Validates email format and password length (min 8 chars)
- Hashes password with bcrypt before storing
- Returns: `{ id, email, name }` with 201 status
- Error: 400 if validation fails, 409 if email already exists

### POST /login
- Accepts: `{ email: string, password: string }`
- Verifies credentials against stored hash
- Returns: `{ token: string }` (JWT valid for 24h)
- Error: 401 if credentials invalid

### GET /me
- Requires: `Authorization: Bearer <token>` header
- Returns: `{ id, email, name }` of authenticated user
- Error: 401 if token missing/invalid

## Conventions
- All responses are JSON
- Error responses use format: `{ error: string }`
- Database file lives at `./data/app.db` (auto-created)
- Tests use an in-memory SQLite database
- No classes — use plain functions and objects
- Each module exports named functions, not default exports

## Directory Structure
```
src/
  index.ts          # Express app setup and routes
  db.ts             # Database connection and queries
  auth.ts           # JWT and password utilities
  middleware.ts      # Auth middleware
  validation.ts     # Zod schemas
tests/
  register.test.ts
  login.test.ts
  me.test.ts
```
