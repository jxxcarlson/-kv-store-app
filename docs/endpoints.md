# API Endpoints

Servant API. All JSON unless noted.

## Auth

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/auth/register` | No | Create account, returns JWT |
| POST | `/api/auth/login` | No | Returns JWT + refresh token |
| POST | `/api/auth/refresh` | No | Exchange refresh token for new JWT |

## Data

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/data` | Yes | List user's own data entries (key, data_type, description, created, modified) |
| GET | `/api/data/:key` | Conditional | Get value by key. Public group = no auth. Otherwise requires auth + group membership |
| POST | `/api/data` | Yes | Create a new data entry |
| PUT | `/api/data/:key` | Yes | Update (owner only) |
| DELETE | `/api/data/:key` | Yes | Delete (owner only) |
| PUT | `/api/data/:key/group` | Yes | Assign group to data entry (owner only) |

## Groups

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/groups` | Yes | List groups the user belongs to |
| POST | `/api/groups` | Yes | Create a group (user becomes owner) |
| PUT | `/api/groups/:id` | Yes | Update group (owner only) |
| POST | `/api/groups/:id/members` | Yes | Add user to group (group owner only) |
| DELETE | `/api/groups/:id/members/:uid` | Yes | Remove user from group |

## Public Browsing

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/public` | No | List all public data entries (abbreviated: key, data_type, description) |
| GET | `/api/public?search=term` | No | Search public entries by key/description |
| GET | `/api/public?sort=key\|created\|modified` | No | Sort public entries |
