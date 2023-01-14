#!/bin/bash

dest="$1"
if [[ -z "$dest" ]] ; then
    dest='/usr/local/bin'
fi

cp init-cli.sh $dest
cp cli.sh $dest