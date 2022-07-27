#!/bin/bash

# sed command to add export to beginning of each line and quote values
env | sed 's/^/export /;s/=/&"/;s/$/"/' > /apps/fes/env.variables

# set fes user crontab
su -c 'crontab /apps/fes/cron/crontab.txt' fes

# Start cron
crond -n