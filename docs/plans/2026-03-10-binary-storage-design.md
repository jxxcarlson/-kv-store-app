# Binary File Storage Design

Date: 2026-03-10

## Goal

Support storing and displaying binary files (pdf, jpg, png, mp3) in the key-value store alongside existing text-based entries.

## Approach

Binary data stored in a new `blob_value BYTEA` column. Text entries continue using the existing `value TEXT` column. Separate upload/download endpoints serve raw bytes with correct Content-Type. The frontend displays binary content by pointing HTML elements directly at server URLs — no base64 encoding.

## Database

Add nullable `blob_value` column to `data` table:

```
DataEntry sql=data
    ...
    value      Text default=''
    blobValue  ByteString Maybe   -- NEW: nullable BYTEA for binary data
```

## Backend Endpoints

### New endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/data/:key/blob` | JWT | Upload binary file (octet-stream body) |
| GET | `/api/data/:key/blob` | JWT | Download binary file with correct Content-Type |
| GET | `/api/public/:key/blob` | No | Download public binary file |

### Content-Type mapping

| data_type | Content-Type |
|-----------|-------------|
| pdf | application/pdf |
| jpg | image/jpeg |
| png | image/png |
| mp3 | audio/mpeg |

### Create flow for binary entries

1. Create entry via existing `POST /api/data` (key, data_type, description — value can be empty)
2. Upload blob via `POST /api/data/:key/blob` with raw bytes body

## Frontend

### Upload

- File input in create form (shown for binary data types)
- JS FileReader reads file, sends via fetch to blob endpoint
- Elm coordinates via ports: `uploadBlob : { key: String, token: String, file: File }`

### Display

Binary entries rendered by pointing src attributes at server URLs:

- `pdf` → `<iframe src="/api/data/:key/blob">`
- `jpg`, `png` → `<img src="/api/data/:key/blob">`
- `mp3` → `<audio src="/api/data/:key/blob" controls>`

Public entries use `/api/public/:key/blob`. Auth entries include JWT in URL or use fetch + object URL.

### Unchanged

Text types (txt, md, tex, scripta, html, csv, json) use existing `value` field and JSON API.
