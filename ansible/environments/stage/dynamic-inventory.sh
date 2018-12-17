#!/bin/sh
./dynamic-inventory/gce.py --list | sed 's/tag_reddit-db/db/g; s/tag_reddit-app/app/g; s/reddit-db/db/g; s/reddit-app/app/g'
