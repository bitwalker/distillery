# Docker deployment

In this guide we will cover how to deploy with docker. We will deploy on our local machine, just in the same fashion that you should deploy in production. However to deploy on a particular machine, commands will change slightly. (for these commands for a specific provider, check the specific provider section, for example digital ocean)

In order to deploy with docker, you need a docker image, if you don't have one, check the docker-image section.

add a config file in `./config/docker.env` with your configuration for example (these are common settings, fill in the ones for your app)
```
HOSTNAME=my_hostname
SECRET_KEY_BASE=something_very_long_that_cannot_be_guessed_even_in_a_very_long_time
DB_HOSTNAME=my_db_hostname
DB_USER=my_db_username
DB_PASSWORD=my_db_username_password
DB_DB=my_db_name
PORT=4000
LANG=en_US.UTF-8
REPLACE_OS_VARS=true
ERLANG_COOKIE=my_erlang_cookie
```

add a `docker-compose.yml` file with the following
```
version: '3.5'

networks:
  webnet:
    driver: overlay
    attachable: true # this will be needed run particular commands in a container, for migrations for example


services:
  web:
    image: "my_image_name"
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
    ports:
      - "80:4000" # provided that we chose to run our app on port 4000 and we want to map to port 80
      - "443:443"
    volumes:
    - .:/app # your volumes if needed, for exemple if you have ssl certificates
    env_file:
     - ./config/docker.env # your env var file
    networks:
      - webnet
```

if you have external dependencies this is the place to add them. For example if you have a database, change your file to the following

```
version: '3.5'

volumes:
    prometheus_data: {}
    grafana_data: {}

networks:
  webnet:
    driver: overlay
    attachable: true


services:
  web:
    image: "my_image_name"
    depends_on:
      - db # note that the depends_on condition was added
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
    ports:
      - "80:4000"
      - "443:443"
    volumes:
    - .:/app
    env_file:
     - ./config/docker.dev.env
    networks:
      - webnet

# careful what you name your service here, these will be your database hostname in your env vars
  db:
    image: postgres:10-alpine
    deploy:
      replicas: 1
      placement:
        constraints: [node.role == manager]
      restart_policy:
        condition: on-failure
    volumes:
      - "./volumes/postgres:/var/lib/postgresql/data"
    ports:
      - "5432:5432"
    env_file:
     - ./config/docker.env
    networks:
      - webnet
```

now verify that your deployment works
to deploy with docker swarm, you need to initialize the swarm with
`docker swarm init`

then deploy your stack with
`docker stack deploy -c docker-compose.yml my_app_name`

go to localhost in your browser and verify that your app is working!
