# Data Model

Four Postgres tables.

## users

| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| name | TEXT NOT NULL | |
| email | TEXT UNIQUE NOT NULL | |
| password_hash | TEXT NOT NULL | bcrypt |
| group_ids | INTEGER[] DEFAULT '{}' | Groups the user belongs to |

## groups

| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| owner_id | INTEGER NOT NULL REFERENCES users | |
| name | TEXT UNIQUE NOT NULL | |
| can_read | BOOLEAN DEFAULT TRUE | |
| can_write | BOOLEAN DEFAULT FALSE | |

## data

| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| owner_id | INTEGER NOT NULL REFERENCES users | |
| group_id | INTEGER REFERENCES groups | Nullable — unassigned data has no group |
| key | TEXT NOT NULL | Indexed, unique per owner |
| data_type | TEXT NOT NULL | "csv", "txt", "md", "tex", "scripta", "json", "yaml",  "bib",  "sql", "html"   |
| created_at | TIMESTAMPTZ DEFAULT now() | |
| modified_at | TIMESTAMPTZ DEFAULT now() | |
| properties | TEXT DEFAULT '' | Freeform "date:1929, ..." |
| description | TEXT DEFAULT '' | |
| value | TEXT DEFAULT '' | |

**Unique constraint**: `(owner_id, key)` — keys are unique per user, not globally.

## refresh_tokens

For JWT refresh.

| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| user_id | INTEGER NOT NULL REFERENCES users | |
| token | TEXT NOT NULL | |
| expires_at | TIMESTAMPTZ NOT NULL | |
