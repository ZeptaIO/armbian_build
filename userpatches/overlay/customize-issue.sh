#!/bin/bash
rm -f /etc/issue

# Wait for network device to become ready.
while ip addr show dev end0 | grep DOWN; do
	sleep 1
done

# Show welcome message before logging in.
for i in /etc/update-motd.d/*; do
    bash $i >> /etc/issue
done
