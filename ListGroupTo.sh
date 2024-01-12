#!/bin/bash

samba-tool user show $1 | grep "memberOf" | cut -d ',' -f1 | cut -d ':' -f2 | cut -d '=' -f2
