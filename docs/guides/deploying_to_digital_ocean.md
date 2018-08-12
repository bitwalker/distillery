# Deploying with digital ocean

There are multiple ways to deploy to digital ocean. We will deploy with docker swarm in this guide for simplicity.
(note: while it's possible to use docker-compose it's generally not recommended for production. Since it's not much more difficult to use docker swarm, that's what we recommend.)

## single machine with docker

### deploying

Prerequisite:

- make sure you have completed the docker deployment guide
- you know how to create a 'one-click app' droplet
- you know how to ssh in a digital ocean droplet
- you have published your image to dockerhub

- Start by creating a new droplet. Click on the 'one-click apps' and choose docker. It will create a droplet for you with docker already installed

- ssh into your droplet and start by upgrading it `apt-get upgrade`. It might be missing some security upgrades

- create a directory for your configuration files for example `mkdir /etc/opt/app` (etc is the directory mainly used for storing config files on linux, opt is generally used for things not necessary to the OS). Then cd into that directory

- copy over your `.env` files and your docker-compose.yml file. on your droplet run `mkdir config`. on your computer run `scp ./config/docker.env root@my_droplet_ip:/etc/opt/app/config` and `scp docker-compose.yml root@my_droplet_ip:/etc/opt/app`

- login with docker (needed in order to pull the image from dockerhub) `docker login` (then follow the instructions)

- start a swarm on your droplet (don't forget to replace my_droplet_ip_address with your droplet's ip address) `docker swarm init --advertise-addr my_droplet_ip_address --listen-addr my_droplet_ip_address`

- then deploy your stack with `docker stack deploy -c docker-compose.yml my_app_name`

### upgrading

if you have tagged your image with `latest`, the chances are, when you want to upgrade to the next version of your app, it won't pull the new image. Here is how to force the upgrade

- pull the latest image version `docker pull dockerhub_usersname/my_repo:latest`

- update your service `docker service update --image dockerhub_usersname/my_repo:latest --force my_service_name`. (to find out your service name, user `docker service ls`. Basically it will be something like my_app_name_web if you have followed exactly the docker deploy guide)
