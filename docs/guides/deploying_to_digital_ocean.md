# Deploying to digital ocean

While there are multiple ways one can deploy to Digital Ocean, for this guide we're choosing to use Docker Swarm (installed as a one-click app). This choice was made because it is easy to get started with on Digital Ocean, and makes for a good foundation for small production applications due to it's convenience and feature set.
(note: while it's possible to use docker-compose it's generally not recommended for production.)

## single machine with docker

### deploying

Prerequisites:

- Make sure you have completed the guide related to building a docker image (you'll need the image and the docker-compose.yml file)
- You know how to create a 'one-click app' droplet
- You know how to ssh in a Digital Ocean droplet
- You have published your image to Docker Hub

Start by creating a new droplet. Click on the 'one-click apps' and choose Docker. It will create a droplet for you with docker already installed

Ssh into your droplet and start by upgrading it `apt-get upgrade`. It might be missing some security upgrades

Create a directory for your configuration files for example `mkdir /etc/opt/app` (etc is the directory mainly used for storing config files on linux, opt is generally used for things not necessary to the OS). Then cd into that directory

Copy over your `.env` files and your docker-compose.yml file. on your droplet run `mkdir config`. on your computer run `scp ./config/docker.env root@my_droplet_ip:/etc/opt/app/config` and `scp docker-compose.yml root@my_droplet_ip:/etc/opt/app`

Login with Docker (needed in order to pull the image from Docker Hub) `docker login` (then follow the instructions)

Start a swarm on your droplet (don't forget to replace my_droplet_ip_address with your droplet's ip address) `docker swarm init --advertise-addr my_droplet_ip_address --listen-addr my_droplet_ip_address`

Deploy your stack with `docker stack deploy -c docker-compose.yml my_app_name`

### upgrading

If you have tagged your image with `latest`, the chances are, when you want to upgrade to the next version of your app, it won't pull the new image. Here is how to force the upgrade

- pull the latest image version `docker pull dockerhub_username/my_repo:latest`

- update your service `docker service update --image dockerhub_username/my_repo:latest --force my_service_name`. (to find out your service name, user `docker service ls`. Basically it will be something like my_app_name_web if you have followed exactly the docker deploy guide)
