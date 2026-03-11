# Binary File Storage Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Support storing and displaying binary files (pdf, jpg, png, mp3) via a BYTEA column, with upload/download endpoints and frontend file picker.

**Architecture:** Add nullable `blobValue` BYTEA column to DataEntry. New Servant endpoints serve/accept raw bytes with correct Content-Type. Frontend uses JS file input + fetch for upload, and points `<iframe>`, `<img>`, `<audio>` src attributes directly at server blob URLs.

**Tech Stack:** Haskell (Servant, Persistent), PostgreSQL BYTEA, Elm 0.19.1, JavaScript ports

---

### Task 1: Add blobValue column to schema

**Files:**
- Modify: `backend/src/Db/Schema.hs`

**Step 1: Add the column**

In `Db/Schema.hs`, add `blobValue` to the DataEntry model:

```haskell
DataEntry sql=data
    ownerId UserId
    groupId GroupId Maybe
    key Text
    dataType Text sql=data_type
    createdAt UTCTime sql=created_at
    modifiedAt UTCTime sql=modified_at
    properties Text default=''
    description Text default=''
    value Text default=''
    blobValue ByteString Maybe sql=blob_value
    UniqueOwnerKey ownerId key
    deriving Show
```

Add import: `import Data.ByteString (ByteString)`

**Step 2: Build to verify**

Run: `cd backend && stack build 2>&1 | tail -5`
Expected: successful compilation. Persistent auto-migration will add the column on next server start.

**Step 3: Commit**

```bash
git add backend/src/Db/Schema.hs
git commit -m "feat: add blob_value BYTEA column to data_entry schema"
```

---

### Task 2: Add blob serving endpoints to API type

**Files:**
- Modify: `backend/src/Api.hs`

**Step 1: Add BlobAPI type and public blob endpoint**

Add `OctetStream` content type and new endpoint types. The blob endpoints return raw bytes:

```haskell
type DataAPI =
       "data" :> Get '[JSON] [DataEntrySummary]
  :<|> "data" :> Capture "key" Text :> Get '[JSON] DataValueResponse
  :<|> "data" :> ReqBody '[JSON] CreateDataRequest :> Post '[JSON] DataEntrySummary
  :<|> "data" :> Capture "key" Text :> ReqBody '[JSON] UpdateDataRequest :> Put '[JSON] DataEntrySummary
  :<|> "data" :> Capture "key" Text :> Delete '[JSON] NoContent
  :<|> "data" :> Capture "key" Text :> "group" :> ReqBody '[JSON] AssignGroupRequest :> Put '[JSON] NoContent
  :<|> "data" :> Capture "key" Text :> "blob" :> ReqBody '[OctetStream] ByteString :> Post '[JSON] NoContent
  :<|> "data" :> Capture "key" Text :> "blob" :> Get '[OctetStream] (Headers '[Header "Content-Type" Text] ByteString)

type PublicDataAPI = "public" :>
  (    QueryParam "search" Text :> QueryParam "sort" Text :> Get '[JSON] [DataEntrySummary]
  :<|> Capture "key" Text :> Get '[JSON] DataValueResponse
  :<|> Capture "key" Text :> "blob" :> Get '[OctetStream] (Headers '[Header "Content-Type" Text] ByteString)
  )
```

Add imports: `import Data.ByteString (ByteString)`, `import Servant` already covers `OctetStream` and `Headers`.

**Step 2: Build to verify types compile**

Run: `cd backend && stack build 2>&1 | tail -10`
Expected: type errors in handler modules (expected — handlers don't match new API shape yet)

**Step 3: Commit**

```bash
git add backend/src/Api.hs
git commit -m "feat: add blob upload/download endpoint types to API"
```

---

### Task 3: Add blob database queries

**Files:**
- Modify: `backend/src/Db/Queries/Data.hs`

**Step 1: Add getBlob and setBlob functions**

```haskell
import Data.ByteString (ByteString)

setBlob :: ConnectionPool -> Key DataEntry -> ByteString -> IO ()
setBlob pool entryId blob = do
  now <- getCurrentTime
  runSqlPool (update entryId [DataEntryBlobValue =. Just blob, DataEntryModifiedAt =. now]) pool

getBlob :: ConnectionPool -> Key DataEntry -> IO (Maybe ByteString)
getBlob pool entryId =
  runSqlPool (do
    mEntry <- get entryId
    return $ mEntry >>= dataEntryBlobValue
  ) pool
```

Export `setBlob` and `getBlob` from module.

**Step 2: Commit**

```bash
git add backend/src/Db/Queries/Data.hs
git commit -m "feat: add blob get/set database queries"
```

---

### Task 4: Add blob handlers to Api.Data

**Files:**
- Modify: `backend/src/Api/Data.hs`

**Step 1: Add uploadBlob and downloadBlob handlers**

```haskell
import Data.ByteString (ByteString)

uploadBlobHandler :: AppConfig -> ConnectionPool -> Text -> Text -> ByteString -> Handler NoContent
uploadBlobHandler config pool authHeader key blob = do
  userId <- extractUserId config authHeader
  mEntry <- liftIO $ Q.getDataByKey pool userId key
  case mEntry of
    Nothing -> throwError err404 { errBody = "Data entry not found" }
    Just (Entity entryId _) -> do
      liftIO $ Q.setBlob pool entryId blob
      return NoContent

downloadBlobHandler :: AppConfig -> ConnectionPool -> Text -> Text -> Handler (Headers '[Header "Content-Type" Text] ByteString)
downloadBlobHandler config pool authHeader key = do
  userId <- extractUserId config authHeader
  mEntry <- liftIO $ Q.getDataByKey pool userId key
  case mEntry of
    Nothing -> throwError err404 { errBody = "Data entry not found" }
    Just (Entity entryId entry) -> do
      mBlob <- liftIO $ Q.getBlob pool entryId
      case mBlob of
        Nothing -> throwError err404 { errBody = "No blob data" }
        Just blob -> return $ addHeader (contentTypeFor (dataEntryDataType entry)) blob

contentTypeFor :: Text -> Text
contentTypeFor dt = case dt of
  "pdf" -> "application/pdf"
  "jpg" -> "image/jpeg"
  "png" -> "image/png"
  "mp3" -> "audio/mpeg"
  _     -> "application/octet-stream"
```

**Step 2: Wire handlers into dataHandlers**

Update `dataHandlers` to include the two new handlers (order must match API type):

```haskell
dataHandlers config pool authHeader =
       listDataHandler config pool authHeader
  :<|> getDataHandler config pool authHeader
  :<|> createDataHandler config pool authHeader
  :<|> updateDataHandler config pool authHeader
  :<|> deleteDataHandler config pool authHeader
  :<|> assignGroupHandler config pool authHeader
  :<|> uploadBlobHandler config pool authHeader
  :<|> downloadBlobHandler config pool authHeader
```

**Step 3: Commit**

```bash
git add backend/src/Api/Data.hs
git commit -m "feat: add blob upload and download handlers"
```

---

### Task 5: Add public blob handler to Api.Public

**Files:**
- Modify: `backend/src/Api/Public.hs`

**Step 1: Add public blob download handler**

```haskell
import Data.ByteString (ByteString)

publicHandlers pool = listPublicHandler pool :<|> getPublicValueHandler pool :<|> getPublicBlobHandler pool

getPublicBlobHandler :: ConnectionPool -> Text -> Handler (Headers '[Header "Content-Type" Text] ByteString)
getPublicBlobHandler pool key = do
  let publicGroupKey = toSqlKey 1 :: Key Group
  entries <- liftIO $ runSqlPool
    (selectList [DataEntryGroupId ==. Just publicGroupKey, DataEntryKey ==. key] [])
    pool
  case entries of
    [Entity entryId entry] ->
      case dataEntryBlobValue entry of
        Nothing -> throwError err404 { errBody = "No blob data" }
        Just blob -> return $ addHeader (contentTypeFor (dataEntryDataType entry)) blob
    _ -> throwError err404 { errBody = "Public entry not found" }

contentTypeFor :: Text -> Text
contentTypeFor dt = case dt of
  "pdf" -> "application/pdf"
  "jpg" -> "image/jpeg"
  "png" -> "image/png"
  "mp3" -> "audio/mpeg"
  _     -> "application/octet-stream"
```

**Step 2: Build and verify everything compiles**

Run: `cd backend && stack build 2>&1 | tail -5`
Expected: successful compilation

**Step 3: Commit**

```bash
git add backend/src/Api/Public.hs
git commit -m "feat: add public blob download endpoint"
```

---

### Task 6: Update createData to accept empty value for binary types

**Files:**
- Modify: `backend/src/Db/Queries/Data.hs`

The existing `createData` function already accepts empty string for `value`, so no change needed. Binary entries are created with `value=""` and the blob is uploaded separately.

---

### Task 7: Add file upload port and JS handler

**Files:**
- Modify: `frontend/src/Main.elm`
- Modify: `frontend/index.html`
- Modify: `frontend/src/Types.elm`

**Step 1: Add port to Main.elm**

```elm
port uploadBlob : { key : String, token : String } -> Cmd msg
```

This port signals JS to read the selected file and POST it to the blob endpoint.

**Step 2: Add incoming port for upload result**

```elm
port blobUploaded : (Bool -> msg) -> Sub msg
```

**Step 3: Add GotBlobUpload message to Types.elm**

```elm
| GotBlobUpload Bool
```

**Step 4: Add JS handler to index.html**

```javascript
app.ports.uploadBlob.subscribe(function(data) {
    var fileInput = document.getElementById('blob-file-input');
    if (!fileInput || !fileInput.files[0]) {
        app.ports.blobUploaded.send(false);
        return;
    }
    var file = fileInput.files[0];
    fetch('http://localhost:3000/api/data/' + encodeURIComponent(data.key) + '/blob', {
        method: 'POST',
        headers: {
            'Authorization': 'Bearer ' + data.token,
            'Content-Type': 'application/octet-stream'
        },
        body: file
    }).then(function(response) {
        app.ports.blobUploaded.send(response.ok);
    }).catch(function() {
        app.ports.blobUploaded.send(false);
    });
});
```

**Step 5: Add subscription in Main.elm**

```elm
subscriptions model =
    blobUploaded GotBlobUpload
```

**Step 6: Commit**

```bash
git add frontend/src/Main.elm frontend/index.html frontend/src/Types.elm
git commit -m "feat: add file upload port and JS handler"
```

---

### Task 8: Add file input to create form for binary types

**Files:**
- Modify: `frontend/src/Page/MyData.elm`
- Modify: `frontend/src/Main.elm`

**Step 1: Add file input to create form**

In `viewCreateForm`, after the data type selector, add a file input that appears for binary types:

```elm
, if List.member form.dataType [ "pdf", "jpg", "png", "mp3" ] then
    div [ class "form-group" ]
        [ label [] [ text "File" ]
        , input [ type_ "file", id "blob-file-input" ] []
        ]
  else
    text ""
```

For binary types, hide the Value textarea (since content comes from file upload).

**Step 2: Update SubmitCreateData handler in Main.elm**

After `GotCreateResponse` succeeds for a binary type, trigger the blob upload:

```elm
GotCreateResponse result ->
    case result of
        Ok newEntry ->
            case model.page of
                MyDataPage myDataModel ->
                    let
                        isBinary = List.member newEntry.dataType [ "pdf", "jpg", "png", "mp3" ]
                        uploadCmd =
                            case ( isBinary, model.token ) of
                                ( True, Just token ) ->
                                    uploadBlob { key = newEntry.key, token = token }
                                _ ->
                                    Cmd.none
                    in
                    ( { model
                        | page = MyDataPage
                            { myDataModel
                                | entries = myDataModel.entries ++ [ newEntry ]
                                , showCreateForm = False
                                , createForm = emptyCreateForm
                            }
                      }
                    , uploadCmd
                    )
                _ -> ( model, Cmd.none )
        Err err -> handleAuthError model "Failed to create entry." err
```

**Step 3: Handle GotBlobUpload in update**

```elm
GotBlobUpload success ->
    if success then
        ( model, Cmd.none )
    else
        ( { model | errorMessage = Just "Failed to upload file." }, Cmd.none )
```

**Step 4: Commit**

```bash
git add frontend/src/Page/MyData.elm frontend/src/Main.elm
git commit -m "feat: add file input for binary types and upload after create"
```

---

### Task 9: Add binary display cases to View/Table.elm

**Files:**
- Modify: `frontend/src/View/Table.elm`
- Modify: `frontend/src/Types.elm`

**Step 1: Add isBinaryType helper**

```elm
isBinaryType : String -> Bool
isBinaryType dataType =
    List.member dataType [ "pdf", "jpg", "png", "mp3" ]
```

**Step 2: Add binary display cases**

Binary types don't use the `value` field — they point at the server blob URL. The `display` function needs access to the key and whether the entry is public. Update the signature:

```elm
display : String -> DisplayMode -> String -> String -> Bool -> Html Msg
display dataType mode key content isPublic =
    let
        blobUrl =
            if isPublic then
                "http://localhost:3000/api/public/" ++ key ++ "/blob"
            else
                "http://localhost:3000/api/data/" ++ key ++ "/blob"
    in
    case ( dataType, mode ) of
        ( "pdf", _ ) ->
            div [ class "content-display rendered-content iframe-content" ]
                [ iframe [ src blobUrl, style "width" "100%", style "height" "calc(100vh - 280px)", style "border" "none" ] [] ]

        ( "jpg", _ ) ->
            div [ class "content-display rendered-content" ]
                [ img [ src blobUrl, style "max-width" "100%" ] [] ]

        ( "png", _ ) ->
            div [ class "content-display rendered-content" ]
                [ img [ src blobUrl, style "max-width" "100%" ] [] ]

        ( "mp3", _ ) ->
            div [ class "content-display rendered-content" ]
                [ audio [ src blobUrl, attribute "controls" "" ] [] ]

        -- existing cases unchanged...
```

Note: For authenticated blob URLs, the browser can't send the JWT in a bare `<img src>`. Two options:
- (a) Make all blob viewing go through public endpoint (user must publish first)
- (b) Use JS fetch + `URL.createObjectURL` via a port

Option (a) is simpler for now. Option (b) can be added later. For the authenticated case, we'll fetch via JS and create an object URL.

**Step 3: Update all callers of display**

Update `expandedPanel`, `myDataExpandedPanel`, and any other callers to pass the new `key` and `isPublic` arguments from the ExpandedEntry.

Add `isPublic` field to `ExpandedEntry` in Types.elm if not already present, or derive it from context.

**Step 4: Commit**

```bash
git add frontend/src/View/Table.elm frontend/src/Types.elm
git commit -m "feat: add binary display cases for pdf, jpg, png, mp3"
```

---

### Task 10: Handle authenticated blob display via object URL

**Files:**
- Modify: `frontend/index.html`
- Modify: `frontend/src/Main.elm`
- Modify: `frontend/src/Types.elm`

**Step 1: Add port for fetching authenticated blobs**

```elm
port fetchBlob : { url : String, token : String } -> Cmd msg
port gotBlobUrl : (String -> msg) -> Sub msg
```

**Step 2: Add JS handler**

```javascript
app.ports.fetchBlob.subscribe(function(data) {
    fetch(data.url, {
        headers: { 'Authorization': 'Bearer ' + data.token }
    }).then(function(r) { return r.blob(); })
      .then(function(blob) {
        var url = URL.createObjectURL(blob);
        app.ports.gotBlobUrl.send(url);
    }).catch(function() {
        app.ports.gotBlobUrl.send('');
    });
});
```

**Step 3: Add GotBlobUrl message and store object URL in ExpandedEntry**

When expanding a binary entry, trigger the fetchBlob port. Store the resulting object URL and use it as the src.

**Step 4: Commit**

```bash
git add frontend/index.html frontend/src/Main.elm frontend/src/Types.elm
git commit -m "feat: fetch authenticated blobs via object URL for display"
```

---

### Task 11: Build, test, and final commit

**Step 1: Build backend**

Run: `cd backend && stack build 2>&1 | tail -5`

**Step 2: Build frontend**

Run: `cd frontend && elm make src/Main.elm --output=elm.js 2>&1 | tail -5`

**Step 3: Manual test**

1. Start backend: `cd backend && stack exec kv-store-backend`
2. Start frontend: `cd frontend && sh start.sh`
3. Create a PDF entry, upload a file, verify it displays
4. Create a PNG entry, verify image displays
5. Publish an entry, verify public blob URL works

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete binary file storage (pdf, jpg, png, mp3) with upload and display"
```
