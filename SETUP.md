[200~# Install                                                                                                                                         
  sudo apt update
  sudo apt install postgresql postgresql-contrib                                                                                                    
                                                            
  # Start the service
  sudo systemctl start postgresql
  sudo systemctl enable postgresql

  # Create the database
  sudo -u postgres createdb kvstore

  By default, the backend connects to postgresql://localhost/kvstore. If you need password auth, create a user and set DATABASE_URL:

  sudo -u postgres createuser --pwprompt kvuser
  sudo -u postgres psql -c "GRANT ALL ON DATABASE kvstore TO kvuser;"
  export DATABASE_URL="postgresql://kvuser:yourpassword@localhost/kvstore"


[200~  # Create the database                                                                                                                             
  createdb kvstore                                          

-----------------------

[200~ do I need to set up password auth for kvstore?                                                                                                    
                                                                                                                                                    
⏺ It depends on your backend's connection string. The default is:                                                                                   
                                         
  postgresql://localhost/kvstore                                                                                                                    
                                                                                                                                                    
  That uses peer auth (Unix socket, no password), which works if the backend runs as the postgres OS user. If your backend runs as root or another  
  user, you'll either need to:                              

  Option A: Set up password auth (simpler for deployment)
  sudo -u postgres psql -c "CREATE USER kvuser WITH PASSWORD 'yourpassword';"
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE kvstore TO kvuser;"
  export DATABASE_URL="postgresql://kvuser:yourpassword@localhost/kvstore"

  Option B: Run the backend as the postgres user
  sudo -u postgres stack exec kv-store-backend

  Option A is the more standard approach. Which do you prefer?[201~

[200~echo $DATABASE_UR[201~



[200~  cd ~/kv-store-app/backend                                                                                                                         
  stack build                                                                                                                                       
  stack exec kv-store-backend[201~


❯ I am running nginx:                                                                                                                               
                                                                                                                                                    
 sudo lsof -i :80                                                                                                                                   
COMMAND  PID     USER   FD   TYPE DEVICE SIZE/OFF NODE NAME                                                                                         
nginx   1009     root    9u  IPv4  19910      0t0  TCP *:http (LISTEN)                                                                              
nginx   1010 www-data    9u  IPv4  19910      0t0  TCP *:http (LISTEN)                                                                              

⏺ Good — nginx is on port 80. The standard setup is to run the backend on a different port and use nginx as a reverse proxy.

  Run the backend on port 3000:                                                                                                                     
   
  PORT=3000 bash start.sh                                                                                                                           
                                                                                                                                                  
  Then add an nginx config to proxy requests to it. What domain or subdomain do you want to use for kv-store?

root@rose:~/kv-store-app# lsof -i :3000
COMMAND   PID USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME
pdfServer 974 root    4u  IPv4   19538      0t0  TCP *:3000 (LISTEN)
pdfServer 974 root    6u  IPv4 3626603      0t0  TCP localhost:3000->localhost:42668 (CLOSE_WAIT)
pdfServer 974 root    7u  IPv4 5602829      0t0  TCP localhost:3000->localhost:42826 (CLOSE_WAIT)
pdfServer 974 root    9u  IPv4 5603001      0t0  TCP localhost:3000->localhost:60696 (CLOSE_WAIT)
pdfServer 974 root   18u  IPv4 5604552      0t0  TCP localhost:3000->localhost:33448 (CLOSE_WAIT)
root@rose:~/kv-store-app# lsof -i :3001

Find the nginx conf:

  ls /etc/nginx/sites-enabled/
  dataserver  pdfserver


-----------

The reverse proxy setup for pdfserver:

server {
    server_name pdfserv.app;

    location / {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }


    location /a/ {
        proxy_pass http://127.0.0.1:3001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }


    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/pdfserv.app/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/pdfserv.app/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

    # add_header Access-Control-Allow-Origin *;
    # add_header Access-Control-Max-Age 3600;
    # add_header Access-Control-Expose-Headers Content-Length;
    # add_header Access-Control-Allow-Headers Range;



}
server {
    if ($host = pdfserv.app) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    if ($host = pdfserv.app) {
        return 301 https://$host$request_uri;
    } # managed by Certbot

    listen 80;
    server_name pdfserv.app;
    return 404; # managed by Certbot


}
root@rose:~/kv-store-app# cat /etc/nginx/sites-enabled/dataserver
server {
    server_name dataserv.app;

    location / {
        proxy_pass http://127.0.0.1:3002/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        access_log /var/log/nginx/access.log main;

    }


    location /b/ {
        proxy_pass http://127.0.0.1:3001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }


    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/dataserv.app/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/dataserv.app/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

    # add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Max-Age 3600;
    add_header Access-Control-Expose-Headers Content-Length;
    add_header Access-Control-Allow-Headers Range;




}
server {
    if ($host = dataserv.app) {
        return 301 https://$host$request_uri;
    } # managed by Certbot

    root /var/www/dataserver/data ;

    listen 80;
    server_name dataserv.app;
    return 404; # managed by Certbot


}

----------

root@rose:~/kv-store-app# cat  /etc/nginx/sites-enabled/dataserver                                                                                 
server {                                                                                                                                           
    server_name dataserv.app;                                                                                                                      
                                                                                                                                                   
    location / {                                                                                                                                   
        proxy_pass http://127.0.0.1:3001/;                                                                                                         
        proxy_set_header Host $host;                                                                                                               
        proxy_set_header X-Real-IP $remote_addr;                                                                                                   
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;                                                                               
        proxy_set_header X-Forwarded-Proto $scheme;                                                                                                
    }                                                                                                                                              
                                                                                                                                                   
                                                                                                                                                   
    listen 443 ssl; # managed by Certbot                                                                                                           
    ssl_certificate /etc/letsencrypt/live/dataserv.app/fullchain.pem; # managed by Certbot                                                         
    ssl_certificate_key /etc/letsencrypt/live/dataserv.app/privkey.pem; # managed by Certbot                                                       
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot                                                                          
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot                                                                            
                                                                                                                                                   
    # add_header Access-Control-Allow-Origin *;                                                                                                    
    add_header Access-Control-Max-Age 3600;                                                                                                        
    add_header Access-Control-Expose-Headers Content-Length;                                                                                       
    add_header Access-Control-Allow-Headers Range;                                                                                                 
                                                                                                                                                   
}                                                                                                                                                  
server {                                                                                                                                           
    if ($host = dataserv.app) {                                                                                                                    
        return 301 https://$host$request_uri;                                                                                                      
    } # managed by Certbot                                                                                                                         
                                                                                                                                                   
    root /var/www/dataserver/data ;                                                                                                                
                                                                                                                                                   
    listen 80;                                                                                                                                     
    server_name dataserv.app;                                                                                                                      
    return 404; # managed by Certbot                                                                                                               
                                                                                                                                                   
                                                                                                                                                   
}                                                                                                                                                  

⏺ Looks good. Test and reload:

  sudo nginx -t && sudo systemctl reload nginx                                                                                                     
   
───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
❯ root@rose:~/kv-store-app# sudo nginx -t && sudo systemctl reload nginx                                                                         
  nginx: the configuration file /etc/nginx/nginx.conf syntax is ok                                                                                 
  nginx: configuration file /etc/nginx/nginx.conf test is successful


 Config is live. Now start the backend:                                                                                                           
                                                                                                                                                 
  PORT=3001 bash start.sh                                                                                                                          
   
  Then test it from your local machine:                                                                                                            
                                                            
  https://dataserv.app/api/public

❯ I got the response []                                                                                                                            
                        
⏺ That's correct — the public endpoint returned an empty JSON array, meaning the backend is running and connected to the database. There's just no 
  public data yet.                       
                                                                                                                                                   
  Your backend is deployed and working at https://dataserv.app.
