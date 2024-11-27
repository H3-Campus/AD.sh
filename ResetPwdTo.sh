#!/bin/bash
password=***********
samba-tool user setpassword $1 --must-change-at-next-login --newpassword=$password
