FROM ubuntu

MAINTAINER Adrian Goins "monachus@arces.net"

RUN echo "deb http://us.archive.ubuntu.com/ubuntu/ precise main restricted universe" > /etc/apt/sources.list
RUN apt-get -y update

ENV DEBIAN_FRONTEND noninteractive
ENV GITLAB_DATABASE mysql

RUN apt-get -qq install postfix python-software-properties sudo git build-essential libicu-dev libxml2-dev libxslt-dev libmysqlclient-dev redis-server openssh-server nginx supervisor

RUN add-apt-repository ppa:brightbox/ruby-ng-experimental
RUN apt-get -qq update

RUN apt-get -qq install ruby2.0 ruby2.0-dev

RUN gem install --no-ri --no-rdoc bundler

RUN adduser --disabled-login --gecos 'GitLab' git

# Gitlab shell
RUN cd /home/git && sudo -u git -H git clone https://github.com/gitlabhq/gitlab-shell.git && cd /home/git/gitlab-shell && sudo -u git -H git checkout v1.7.1

# Gitlab
RUN cd /home/git && sudo -u git -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab && cd /home/git/gitlab && sudo -u git -H git checkout 6-1-stable

ADD docker_files/gemrc /home/git/.gemrc
ADD docker_files/gemrc /root/.gemrc
ADD docker_files/config.yml /home/git/gitlab-shell/
ADD docker_files/gitlab.yml /home/git/gitlab/config/
ADD docker_files/resque.yml /home/git/gitlab/config/
ADD docker_files/unicorn.rb /home/git/gitlab/config/
ADD docker_files/database.yml /home/git/gitlab/config/

ADD docker_files/configure-gitlab.sh /home/git/
RUN /home/git/configure-gitlab.sh

# Nginx
RUN rm /etc/nginx/sites-enabled/default
ADD docker_files/nginx.conf /etc/nginx/nginx.conf
#ADD docker_files/gitlab.nginx.conf /etc/nginx/conf.d/gitlab.conf
#ADD docker_files/gitlab.key /home/git/gitlab.key
#ADD docker_files/gitlab.crt /home/git/gitlab.crt

# Supervisor
ADD docker_files/docker.conf /etc/supervisor/conf.d/
ADD docker_files/start /start

EXPOSE 9999 8888:80 4443:443 2222:22

CMD ["/start"]


