#!/bin/sh
# Bring the base system to the latest 14.5 patch level, so the box ships
# errata and security fixes rather than the bare -RELEASE.
set -eux

# freebsd-update exits 2 when there is nothing to install.
env PAGER=cat freebsd-update --not-running-from-cron fetch || [ $? -eq 2 ]
env PAGER=cat freebsd-update --not-running-from-cron install || [ $? -eq 2 ]

pkg upgrade -y
freebsd-version -ku
