#!/usr/bin/env bash

# errors shouldn't cause script to exit
set +e

# add rserver user account
useradd -r rstudio-server
groupadd -r rstudio-server

# create softlink to admin script in /usr/sbin
ln -f -s /usr/lib/rstudio-server/bin/rstudio-server /usr/sbin/rstudio-server

# create config directory and default config files
mkdir -p /etc/rstudio
if ! test -f /etc/rstudio/rserver.conf
then
  bash -c "printf '# Server Configuration File\n\n' > /etc/rstudio/rserver.conf"
fi
if ! test -f /etc/rstudio/rsession.conf
then
  bash -c "echo '# R Session Configuration File\n\n' > /etc/rstudio/rsession.conf"
fi

# create var directories
mkdir -p /var/run/rstudio-server
mkdir -p /var/lock/rstudio-server
mkdir -p /var/log/rstudio-server
mkdir -p /var/lib/rstudio-server
mkdir -p /var/lib/rstudio-server/conf
mkdir -p /var/lib/rstudio-server/body
mkdir -p /var/lib/rstudio-server/proxy

# suspend all sessions
rstudio-server force-suspend-all

# check lsb release and init system
source /etc/lsb-release
case "${DISTRIB_CODENAME}" in
  vivid|wily|xenial|yakkety|zesty|artful)
    INIT_SYSTEM='systemd'
    echo "Ubuntu init system set to INIT_SYSTEM=${INIT_SYSTEM}"
    ;;
  trusty)
    INIT_SYSTEM='upstart'
    echo "Ubuntu init system set to INIT_SYSTEM=${INIT_SYSTEM}"
    ;;
  *)
    echo "Ubuntu init system NOT set."
    ;;
esac

# add apparmor profile (but don't for systemd as this borks up process management)
if test -d /etc/apparmor.d/ && ! test "$INIT_SYSTEM" = "systemd"
then
   cp /usr/lib/rstudio-server/extras/apparmor/rstudio-server /etc/apparmor.d/
   apparmor_parser -r /etc/apparmor.d/rstudio-server 2>/dev/null
elif test -e /etc/apparmor.d/rstudio-server
then
   rm -f /etc/apparmor.d/rstudio-server
   invoke-rc.d apparmor reload 2>/dev/null
fi

# add systemd, upstart, or init.d script and start the server
if test "$INIT_SYSTEM" = "systemd"
then
   systemctl stop rstudio-server.service 2>/dev/null
   systemctl disable rstudio-server.service 2>/dev/null
   cp /usr/lib/rstudio-server/extras/systemd/rstudio-server.service /etc/systemd/system/rstudio-server.service
   systemctl daemon-reload
   systemctl enable rstudio-server.service
#   systemctl start rstudio-server.service
#   sleep 1
#   systemctl --no-pager status rstudio-server.service
elif test "$INIT_SYSTEM" = "upstart"
then
   cp /usr/lib/rstudio-server/extras/upstart/rstudio-server.conf /etc/init/
   initctl reload-configuration
   initctl stop rstudio-server 2>/dev/null
   initctl start rstudio-server
else
   cp /usr/lib/rstudio-server/extras/init.d/debian/rstudio-server /etc/init.d/
   chmod +x /etc/init.d/rstudio-server
   update-rc.d rstudio-server defaults
   /etc/init.d/rstudio-server stop  2>/dev/null
   /etc/init.d/rstudio-server start
fi

# clear error termination state
set -e
