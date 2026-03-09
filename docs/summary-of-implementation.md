 All 14 tasks complete. Both backend and frontend build successfully. Here's a summary:                                                                     
                                                                                                                                                             
  Backend (Haskell/Servant/Persistent):                                                                                                                      
  - 9 commits, full REST API with auth, data CRUD, groups, public browsing                                                                                   
  - JWT auth with bcrypt, refresh tokens                                                                                                                     
  - PostgreSQL via Persistent with auto-migration and public group seeding                                                                                   
  - CORS configured for frontend integration                                                                                                                 
                                                                                                                                                             
  Frontend (Elm):                                                                                                                                            
  - SPA with 5 routes: public, login, register, my-data, groups                                                                                              
  - Sortable table with search, auth forms, data CRUD UI
  - JWT persistence via localStorage ports

  To run:
  1. createdb kvstore (if not done)
  2. cd backend && stack exec kv-store-backend (starts on port 3000)
  3. Open frontend/index.html in a browser (or serve it)
