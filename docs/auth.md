# Authorization Logic

Permission model, centralized in the backend.

## Reading Data

1. Data in the "public" group (id=1) — anyone, no auth required
2. Data in a group with `can_read=true` — any user whose `group_ids` contains that group
3. Data with no group — owner only

## Writing/Updating/Deleting Data

1. Only the owner can update or delete their own data entries
2. Group `can_write` is for future use — v1 is owner-only writes

## Group Assignment

- Only the data owner can assign their data to a group (`PUT /api/data/:key/group`)

## Group Membership

- Only the group owner can add/remove members (`POST/DELETE /api/groups/:id/members`)
- Adding a member = appending the group id to that user's `group_ids` array

## Public Group (id=1)

- Seeded on first migration, owner_id=0 (system), `can_read=true`, `can_write=false`
- No one "owns" it; any user can assign their data to it
