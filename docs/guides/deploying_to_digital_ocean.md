# Deploying to Digital Ocean

While there are multiple ways one can deploy to Digital Ocean, for this guide
we're choosing to use Docker Swarm (installed as a one-click app). This choice
was made because it is easy to get started with on Digital Ocean, and makes for
a good foundation for small production applications due to its convenience and
feature set.

For this guide, we're going to assume you have a single VM you wish to deploy
to.

!!! tip
    You should be familiar with how to build a Docker image with your app, see
    the [Working With Docker](working_with_docker.md) guide first if you are not sure how to do so.

## Prerequisites

You will need to have the following prerequisites checked off:

  * Know how to build a Docker image containing your application
  * Be familiar with Docker Compose (this guide uses it, see [Working With Docker](working_with_docker.md))
  * Know how to create a "one-click app" droplet
  * Know how to SSH to a Digital Ocean droplet
  * Know how to publish an image to Docker Hub (covered below)
  * Have published your app's Docker image to Docker Hub (covered below)
  
### Docker Compose

We will be using Docker Compose in conjunction with Docker Swarm - and to do so
we need to make some adjustments to the `docker-compose.yml` file we created in
[Working With Docker](working_with_docker.md).

First, define a network, by adding the following to the top-level of the file:

```docker
networks:
  webnet:
    driver: overlay
    attachable: true # Needed in order to run custom commands in the container

services:
  # snip..
```

We then need to use that network with our `web` service, and add a `deploy` configuration section:

```docker
services:
  web:
    image: "myapp:latest"
    depends_on:
      - db
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
    ports:
      - "80:4000"
    env_file:
      - config/docker.env
    networks:
      - webnet
```

Likewise, our `db` service needs some adjustment:

```docker
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
    - config/docker.env
  networks:
    - webnet
```

Now we're all set!
  
### Publishing to Docker Hub

If you aren't sure how to publish an image to Docker Hub, you're in luck! It's
very simple - first, create an account [here](https://hub.docker.com/).

Then, click "Create Repository" from the dashboard while logged in, set the name
of the repository to the name of the image you have created, give it a
description, and set the visibility to either public or private.

!!! warning
    If you set visibility to `private`, you will need to login to Docker on the
    server in order to pull images. If you set it to `public`, anyone call pull
    your images, so if they contain sensitive information, do not do this!

Once your account is created, you will need to log in with the Docker CLI:

```
$ docker login
```

Then, once you have built your image, publish it like so:

```
$ docker push username/$APP_NAME:$APP_VSN
```

!!! warning
    Make sure you update the tags you are building with to include the full
    repository name, i.e. `username/myapp:0.1.0`, not just `myapp:0.1.0`. If you
    were following the [Working With Docker](working_with_docker.md) guide,
    adjust your `Makefile` by adding the `username/` prefix, where `username`
    should be your Docker Hub username.

Assuming `APP_NAME=myapp` and `APP_VSN=0.1.0`, this will check for a local image
with the tag `myapp:0.1.0`, and if it exists, push it to the Docker Hub repository.

## Setting up the droplet

On Digital Ocean, click on "one-click apps" and choose Docker. It will create a
new droplet for you with Docker pre-installed.

SSH into the new droplet, and upgrade it:

```
$ apt-get upgrade -y
```

Next, create a directory for configuration files:

```
$ mkdir -p /etc/myapp/config
```

Now that the directory has been created, copy up the `docker-compose.yml` and
`docker.env` files you have created (if you didn't follow the [Working With
Docker](working_with_docker.md) guide, I recommend reviewing it to see what is
in these files):

```
$ scp ./config/docker.env root@<droplet host>:/etc/myapp/config/docker.env
$ scp ./docker-compose.yml root@<droplet host>:/etc/myapp/docker-compose.yml
```

If you set the visibility of your image repository to `private`, login to Docker
with `docker login`.

The final step needed to set up our droplet is to initialize Docker Swarm:

```
$ docker swarm init --advertise-addr <ip address of droplet> --listen-addr <ip address of droplet>
```

We now have everything in place to run our application! 

## Deploying the application

All that is needed now to run our application is to deploy a new stack:

```
$ docker stack deploy -c /etc/myapp/docker-compose.yml myapp
```

!!! note
    This command is run on the droplet, _not_ your local machine.

## Deploying new versions of the application

To deploy an update to your application, first publish a new version of your
image to Docker Hub.

Now, SSH to your droplet, and run a service update:

```
$ docker service update --image username/myapp:0.2.0 myapp
```

The above assumes we set `APP_NAME=myapp` and `APP_VSN=0.2.0` in previous steps.

!!! warning
    If you are tagging images with `latest` and deploying that tag instead (not
    recommended), deploying an update this way may not work, as the image will not
    be refreshed if it has already been pulled. You can force an upgrade like so

    ```
    $ docker pull username/myapp:latest
    $ docker service update --image username/myapp:latest --force myapp
    ```
    
## Wrap up

As you can see, deploying an application to Digital Ocean can be very simple
when we make use of some convenient automation tools like Docker Compose and
Docker Swarm.

This is a great way to get an application up fast and be able to experiment with
things without having to do a lot of tedious work by hand. For more complex
applications, or orchestration for all of an organization's services, I
recommend looking at Kubernetes; but Docker Swarm is a great fit when you can
keep things simple.
