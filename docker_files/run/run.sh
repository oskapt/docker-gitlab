#!/bin/bash

D_VERBOSE=false
D_FOREGROUND=false

# The source directory (on the docker host) for our persistent data
D_WORKSPACE=/opt/docker/docker-gitlab/docker_files/run/data

# IP to assign via Pipework.  Include a netmask, like
#     D_IP=192.168.55.55/24
D_IP=

# Where we can find Redis.  Be sure to include the port number:
#     D_REDIS_HOST=192.168.55.10:6379
D_REDIS_HOST=

# How we want to appear in Gitlab URLs
D_GITLAB_HOST="localhost"

# Start a shell?
D_SHELL=false

# Pipework bridge interface (probably just leave this alone)
D_BRIDGE=br1

# Where do we find pipework script?
PIPEWORK=$(pwd)/pipework

# What is the name (or tag) for the container?
IMAGE="monachus/gitlab"

# Where in the container do we want to mount $WORKSPACE?
MOUNT=/home/git/data

# If you want to map exposed ports to specific ports, set the docker 
# port directive here, like
#    PORTS="-p 80:8080 -p 443:4443"
PORTS=

function usage() {
cat <<EOF

usage: $0 options

OPTIONS: 
  -v    verbose output [${D_VERBOSE}]
  -f    foreground [${D_FOREGROUND}]
  -w    workspace [${D_WORKSPACE}]
  -i    ip [${D_IP}] 
  -s    start shell [${D_SHELL}]
  -b    bridge interface [${D_BRIDGE}]
  -r    redis host [${D_REDIS_HOST}]  
  -g    gitlab host [${D_GITLAB_HOST}] 

EOF
}

function get_ip() {
    # Helper function to return an IP address from a provided interface
    DEV=$1
    ip a sh dev $DEV >/dev/null 2>&1 
    if [[ $? ]]; then
        LOCAL_IP=$( ip a sh dev $1 2>/dev/null | grep inet | grep -v inet6 | awk '{ print $2 }' | awk -F/ '{ print $1 }' )
    fi
}

if [[ $(whoami) != "root" && ! $(groups) =~ docker ]]; then
    echo "Please run this with root privileges or as a user"
    echo "in the 'docker' group."
    exit 1
fi

while getopts "hvfw:i:sbr:g:" OPTION
do
    case $OPTION in
        h)
            usage
            exit
            ;;
        v)
            VERBOSE=0
            ;;
        f)
            OPT_FOREGROUND=0
            ;;
        w)
            OPT_WORKSPACE=$OPTARG
            ;;
        i)
            OPT_IP=$OPTARG
            ;;
        s)
            OPT_SHELL=/bin/bash
            INTERACTIVE="-i -t"
            ;;
        b)
            OPT_BRIDGE=$OPTARG
            ;;
        r)
            OPT_REDIS_HOST=$OPTARG
            ;;
        g)
            OPT_GITLAB_HOST=$OPTARG
            ;;
        ?)
            usage
            exit 1
            ;;
    esac
done

# Assign options or default variables to working variables
WORKSPACE=${OPT_WORKSPACE:-$D_WORKSPACE}
SHELL=${OPT_SHELL:-''}
BRIDGE=${OPT_BRIDGE:-$D_BRIDGE}
REDIS_HOST=${OPT_REDIS_HOST:-$D_REDIS_HOST}
GITLAB_HOST=${OPT_GITLAB_HOST:-$D_GITLAB_HOST}
IP=${OPT_IP:-$D_IP}

# Try to find a local IP on the box.  This is available inside of the
# container for situations where the container has to know what its
# host's IP is (such as a container inside of Vagrant sending traffic
# to the Vagrant IP)
for DEV in eth0 eth1 eth2; do
    get_ip ${DEV}
    if [[ ${LOCAL_IP} =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]];  then
        break
    fi
    LOCAL_IP=
done

# Make a guess that Redis is running locally
if [[ -z ${REDIS_HOST} ]]; then
    LISTEN=$(netstat -an | grep 6379 | grep LIST | awk '{ print $4 }')
    if [[ ! -z ${LISTEN} ]]; then
        # Something is listening
        REDIS_HOST=$( echo ${LISTEN} | awk -F: '{ print $1 }' )
        if [[ -z ${REDIS_HOST} || ${REDIS_HOST} = '0.0.0.0' ]]; then
            # It's listening on all interfaces
            REDIS_HOST="${LOCAL_IP}:6379"
        fi
    fi    
fi

# Make sure we have our persistent data directories
if [[ ! -d ${WORKSPACE} ]]; then
    echo "No workspace directory: ${WORKSPACE}.  Exiting."
    exit 1
else
    for DIR in config repositories; do
        if [[ ! -d ${WORKSPACE}/${DIR} ]]; then
            mkdir ${WORKSPACE}/${DIR}
        fi
    done
fi

# Configure permissions in the repositories directory under $MOUNT
if [[ -d ${MOUNT}/repositories ]]; then
    chmod -R ug+rwX,o-rwx ${MOUNT}/repositories/ > /dev/null
    chmod -R ug-s ${MOUNT}/repositories/ > /dev/null
    find ${MOUNT}/repositories/ -type d -print0 | xargs -0 chmod g+s > /dev/null
fi

# Set our ENV vars for docker
ENVVARS="-e MOUNT=${MOUNT} -e REDIS_HOST=${REDIS_HOST} -e GITLAB_HOST=${GITLAB_HOST} -e IP=$( echo ${IP} | awk -F/ '{ print $1 }' )"

# Add any extra environment variables here, like
# ENVVARS="${ENVVARS} -e X=Y -e A=B"
ENVVARS="${ENVVARS}"

# Create our command
CMD="docker run ${ENVVARS} -d ${PORTS} -v ${WORKSPACE}:${MOUNT} ${INTERACTIVE} ${IMAGE} ${SHELL}" 

if [[ ${VERBOSE} ]]; then
	echo "Starting container with command:"
	echo "    ${CMD}"
fi

# Launch the container
CID=$($CMD)

# Set up static IP with pipework (if provided)
if [[ ! -z ${IP} ]]; then
    if [[ ! -e ${PIPEWORK} ]]; then
    	echo "Unable to execute ${PIPEWORK}" 1>&2
    elif [ ! -z ${CID} ]; then
        sleep 1
        ${PIPEWORK} ${BRIDGE} ${CID} ${IP}
        if [[ $? -eq 0 ]]; then
        	if [[ ${VERBOSE} ]]; then
            	echo "Pipework IP running on ${IP}"
        	fi 
        else
            echo "Error setting up pipework." 1>&2
        fi
    else
        echo "Error setting up pipework." 1>&2
    fi        
fi

# If we're running in the foreground, attach to the container.  Otherwise
# just print out our container's ID.
if [[ ${OPT_FOREGROUND} ]]; then
    echo "If you don't see a prompt, press enter to activate your session."
    docker attach ${CID}
    echo
else
    echo ${CID}
fi

