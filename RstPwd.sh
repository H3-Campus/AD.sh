#!/bin/bash
password=H3campus@2023
samba-tool user setpassword $1 --newpassword=$password
