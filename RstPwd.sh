#!/bin/bash
password=*************
samba-tool user setpassword $1 --newpassword=$password
