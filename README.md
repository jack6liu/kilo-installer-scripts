# kilo-installer-scripts
Shell scripts for installing kilo all-in-one, 1*controller + n*compute

##This is used for offline installation.
1. offline all packages needed by install kilo
2. create a local repository via dpkg-scanpackages or apt-ftpachive
3. run setup-openstack.sh (hardcoded for allinone at current)


##TODO:
1. simplify the configuration steps, use scripts instead of modify configuration files manually.
2. supply the scripts for offline packages, and made a customized ubuntu installation CD with offline repositories.
