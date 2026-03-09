# Spec for a Key-Value Store App

## Backend

Tech stack: postgres + Haskell

Three tables:  Data, User, Group

### Data Table

| id  | owner| group | key | data type | crea | mod | properties | description | value |
| --- | --- | ---       | ---     | ---      | ---        | ---         |--- | --- | -- |
| PK | FK | FK | Str Indexed | Str | Posix    | Posix   | Str       | Str        | Str         | Str   |
| 761 | 1| public | hubble-red-shift | csv    | * | * | date:1929, ... | Hubble's original red-shift data | S.Mag,0.032,170 + more rows |
| 1234 | 2 | public | gilgamesh| txt | * | * | date:2000 BCE| Oldest known poem | He who has seen the wellspring of the land, I will tell of him... |

### User Table

| id | Name | email | groups FK |  Comment | 
| --- | --- | --- | ---|---|
| 1 | James Carlson | jxxcarlson@gmail.com | 3, 4 | Teaches math 101 |
| 2 | Erkal Selman  | erkal@gmail.com | 4 | scripta-dev (rw)|
| 3 | Katy Lu | klu@foo.edu | 2, 17 | Takes math 101 |


### Group Table

| id | Owner Id | Name | Read | Write | Comments |
| --- | --- | --- | --- | --- | -- | 
| PK | FK | Unique Str | Bool | Bool | 
| 1 | 0| public | True | False | Anyone can read |
| 2 | 1 | math-101 | True | False | Studen grou for math 101 | 
| 3 | 1 | math 101 | True | True | Carlson teaches this |
| 4 | 1 | Scripta-dev | True | True | Carlson, Selman are membgers.
| 17 | 3 | Chinese Cooking | True | True | Katy Lu is full member (rw) |

# Frontend

- language: Elm

- App displays an abbreviated verion of the above table with key, data type, description

- sort on key, created, modfied

- search on key, description

- http GET request with key returns value

- Any authenticated user can create docs and groups.  They become the owner of that doc and group.

- Only the owner of a doc can assign it a group
