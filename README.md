README
======

This will build out a [GitLab](http://gitlab.org) container within 
[Docker](http://docker.io).  This isn't your normal _up in a flash_
container...the gems are pretty heavy.  

Pre-Build Configuration
-----------------------

There are a number of pre-configuration steps that you'll need to carry
out, mostly around setting up config files.  Some of these files have
data that is needed during the install.  Others have data that is used
when the software is running.  Configure everything now, and it will be
installed in the `config` directory.  When you launch and run the
container the first time, this directory will be copied and 
symlinked to your persistent data directory.  This will allow you to make
any changes afterward, according to your site's needs.

### config.yml

This is used for gitlab-shell.  If you have an external Redis server
(see below), then you'll want to put that information here.  If you 
don't have one or its IP will change, you can leave this alone and it will
be set by `/start` when the container boots. The `gitlab_url` directive
should stay at localhost.  This appears to be for API calls, so have it
hit the local instance of unicorn.

### gitlab.yml

This is the configuration file for the main Gitlab process.

Edit `host` (line 18) and `email_from` (line 36) to reflect your site's
information.  If you don't have that information now, don't stress.  Leave
it with `YOUR_URL_HERE` and the `/start` script will change it when
the container boots.

### unicorn.rb

Since we're running in a container, it's not likely that you'll need to
change any of the settings here, but you can take a look if you'd like.

### Database Configuration

1. You'll need to have the database already up and running.  Take a peek at
[the docs](https://github.com/gitlabhq/gitlabhq/blob/master/doc/install/databases.md) 
for more info on that.  Once you've built your preferred database backend,
edit the appropriate config file under `docker_files`:
    * `database.yml.mysql`
    * `database.yml.postgresql`
2. After editing, save the file as `database.yml`.
3. Edit `Dockerfile` and set the `ENV` variable to your chosen
database backend (either 'mysql' or 'postgresql').  This tells the 
install script which options to pass to the gem during install.

### Redis configuration

Gitlab's use of Redis is rather vague, and the documentation (as of 09/21/2013)
is pretty sparse.  If we were building this on a standalone server, it seems
to want Redis running locally, although afterward it appears to allow you to 
configure it to point at a remote installation.  We're going to have to do
some massaging to make it work.

#### External Redis Server

If you already have a Redis server running somewhere else, then cool.  Put
that IP into `resque.yml` and you're set.

#### Redis container

We're building a container, and we don't need Redis for anything other 
than Gitlab.  We're going to use [another container](https://github.com/oskapt/docker-redis)
as our Redis host.  At launch time we'll configure these with known IPs
via [pipework](https://github.com/oskapt/pipework), but for now we just need
the Redis server to be available.  

##### Start your Redis container with an interactive shell

If you're using [my container](https://github.com/oskapt/docker-redis), you'll
do this by launching `./run.sh -sf` from the `docker_files/run` directory.  
Determine its docker IP with `ip a sh`.  This will be the `172.17.x.x` 
address.  Afterward you can run `/start` to initialize Redis, but don't exit 
the container.

##### Start your Redis container and inspect it with Docker

If your Redis container is already running in detached mode, you can find its IP with
`sudo docker inspect <container id> | grep IPAddress`.

##### Configure `resque.yml`

Put this address into all of the config sections of `resque.yml`.  From what
I'm able to determine, it doesn't pay attention to the `RAILS_ENV=production` setting 
during the install, so we need to just hit it with a shotgun blast.

### Supervisor Configuration

Supervisor will start with an HTTP server listening on port 9999 with the
username of `docker` and the password of `d0ck3r`.  If you want to change these,
edit `docker.conf` and make the necessary changes.  

### SSL Configuration

Replace `gitlab.crt` and `gitlab.key` with your own SSL key and 
certificate.  If you need a certificate chain, read 
[the docs](http://nginx.org/en/docs/http/configuring_https_servers.html#chains)
on the nginx site before continuing.
  
Building The Container
----------------------

Once you've completed all of the pre-build tasks, you can build the 
container with:

    sudo docker build -t <username>/gitlab .

Replace <username> with your username or replace the entire tag with 
whatever works for your installation.  

This is going to do a whole bunch of stuff that goes against the model of
package management and containers, but just let it do its thing.  It will
take you back to the days when you used to compile all software from source
(Gentoo - I'm looking at you, here), and you'll remember why you stopped 
doing it.  Leave it alone, and it will finish in 15 or 30 minutes.

    Successfully built 85cc29045023

    real    37m41.481s
    user    0m0.032s
    sys     0m0.408s
    
*Yuck.*  I love you, Vagrant.

    Successfully built e0004df90309

    real    17m54.119s
    user    0m0.128s
    sys     0m0.252s
    
<3 you too, Xen Server.

Running The Container
---------------------

The container environment is configured and run from `run.sh` in the
`docker_files/run` directory.  This directory also contains a directory
called `repositories` that will be mounted at `/home/git/repositories` and
contain the persistent repository data.

### Options

You can edit the script to set permanent values for `REDIS_HOST` and
`GITLAB_HOST` or you can set them when running by using `-r` and `-g`
respectively.  

#### REDIS_HOST

This is the hostname or IP for your Redis server.  Include the port
number after a colon.  If you don't provide this, the script will check
for a Redis server running locally and use that IP.  Fancy!

#### GITLAB_HOST

This is the hostname that you use to connect to your Gitlab instance.
It can be the host itself or a URL for a top-level load balancer that
directs traffic to the correct port.  This is used by `/start` to set 
the hostname for nginx and Gitlab.

#### Pipework

The script is integrated with [Pipework](https://github.com/oskapt/pipework),
which configures a static IP inside of the containers.  I do this because
I run a lot of containers within Vagrant, and I want them to reliably
talk to each other.  If you'd like the same functionality, you can set
`D_IP` or use the `-i` option to run.sh.

#### Ports

The Dockerfile set this up to expose 80 on 8888, 443 on 8443, and 9999 on 
whatever dynamic port is available.  If you want to change these, set the
`PORTS` variable to the docker ports directive you would like
to see.  For example, to expose 80 and 443 on their actual ports, use:

    PORTS="-p 80:80 -p 443:443"

### Execution

If you want to start the container interactively, use `-sf` to start a
shell.  From there you can run `/start` and background it to look around
at the system.

For general production use, simply set all of your variables and 
execute `run.sh` with no options.  It will perform the following actions:

* start the container, mounting the `data` directory under
`/home/git/data`
* execute `/start`
    * copies the `config` directory contents to `data/config` if they 
      are missing; otherwise only rsyncs missing content.
    * copies and symlinks `/etc/nginx/conf.d/gitlab.conf` to `data/config/nginx.conf`
    * moves the `log` directory and symlinks it
    * symlinks gitlab-shell's `config.yml`
    * sets permissions for content under `data`
    * executes supervisor
* supervisor will
    * start unicorn
    * start sidekiq
    * start nginx

Accessing the system
--------------------

By default, according to the `Dockerfile`, you will find Gitlab running on
port 8888 for HTTP and port 8443 for HTTPS (which isn't configured by 
this setup guide).  You will find the web interface for supervisor running on port
9999, using `docker/d0ck3r` for access.

You can log into Gitlab with the username `admin@local.host` and the password
`5iveL!fe`.

Post-build changes
------------------

Hopefully we've captured all of the data that you might want to view or
change under the `data` directory.  If not, open an issue or submit a
pull request, and we'll review it for inclusion.  You can change anything
under the `config` directory and restart unicorn to have your changes
take effect.

Not Tested / Known Not To Work
==============================

I'm pushing this up to the community without fully testing every feature
of Gitlab.  I'm able to log in, create users, create a project, clone it
via HTTP and push content from my local repository back up to it via
HTTP.  I have not configured or tested any of the following:

* Notifications via Sidekiq (or whatever it's used for)


