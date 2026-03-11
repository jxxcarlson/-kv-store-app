
# Manual

## Localhost

### Frontend

Update and run:`sh start.sh`

Then point browser at localhost:8081

### Backend

Update: `stack build`

Run: `stack exec kv-store-backend`

## Digital Ocean

Server: rose (161.35.125.40)

URL: https://dataserv.app

### Frontend

Update and build:

```
cd ~/kv-store-app/frontend
git pull
elm make src/Main.elm --output=elm.js
```

The frontend is served by nginx from `/root/kv-store-app/frontend`.

Note: `config.js` on the server should set `window.API_BASE = "";` (empty string for production).

### Backend

Update and build:

```
cd ~/kv-store-app/backend
git pull
stack build
```

Run:

```
PORT=3001 bash start.sh
```

Make sure `DATABASE_URL` is set (source `.env` or export it):

```
export DATABASE_URL="postgresql://kvuser:<password>@localhost/kvstore"
```

Kill the backend: `kill $(lsof -ti :3001)`

### Nginx

Config: `/etc/nginx/sites-enabled/dataserver`

Test and reload after changes: `sudo nginx -t && sudo systemctl reload nginx`

### Database

PostgreSQL on localhost, database `kvstore`, user `kvuser`.
