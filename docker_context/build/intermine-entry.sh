#!/bin/bash

# Create my user
#gosu root bash -c "groupadd -g $C_GROUP_ID -r $C_USER && useradd -r -u $C_USER_ID -g $C_USER $C_USER"
echo "Run intermine-entry.sh"
# Start Snakemake Gui
Snakefile.BuildChoMine --gui &

# Empty Logs
echo "chomine-build is ready!" > /home/intermine/logs/progress
echo "Snakemake version: $(snakemake --version)" >> /home/intermine/logs/progress

# Show Build Log in docker-compose logs
tail -f /home/intermine/logs/progress
