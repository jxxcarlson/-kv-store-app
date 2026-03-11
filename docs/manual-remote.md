# Status of backend

1. curl the API:  http://localhost:3000/status                                                                                                       
2. Check the process: `ps aux | grep kv-store-backend`
3. Check if anything is listening on port 300
4. Check the port: `ss -tlnp | grep 3000`
                                                                                                                                                   
# Run the backend

`stack exec kv-store-backend`
                                                                                                                                                   
