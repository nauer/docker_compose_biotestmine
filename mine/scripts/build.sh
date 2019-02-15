#!/bin/bash

set -e

cd /home/intermine/

# Empty log
echo "" > /home/intermine/logs/progress

# Check if mine exists
if [ ! -d biotestmine ]; then
    echo "$(date +%Y/%m/%d-%H:%M) Clone biotestmine" >> /home/intermine/logs/progress
    git clone https://github.com/intermine/biotestmine
    echo "$(date +%Y/%m/%d-%H:%M) Update keyword_search.properties to use http://solr" >> /home/intermine/logs/progress
    sed -i "s/localhost/solr/g" ./biotestmine/dbmodel/resources/keyword_search.properties
else
    echo "$(date +%Y/%m/%d-%H:%M) Update biotestmine to newest version" >> /home/intermine/logs/progress
    cd biotestmine
    git pull
    cd /home/intermine/
fi

if [ ! -f /home/intermine/.intermine/biotestmine.properties ]; then
    echo "$(date +%Y/%m/%d-%H:%M) Copy biotestmine.properties to ~/.intermine/biotestmine.properties" >> /home/intermine/logs/progress
    cp /home/intermine/biotestmine/data/biotestmine.properties /home/intermine/.intermine/

    echo -e "$(date +%Y/%m/%d-%H:%M) Set properties in .intermine/biotestmine.properties to\nPSQL_DB_NAME\tbiotestmine\nPSQL_USER\t$PSQL_USER\nPSQL_PWD\t$PSQL_PWD\nTOMCAT_USER\t$TOMCAT_USER\nTOMCAT_PWD\t$TOMCAT_PWD" >> /home/intermine/logs/progress

    #sed -i "s/PSQL_PORT/$PGPORT/g" /home/intermine/.intermine/biotestmine.properties
    sed -i "s/PSQL_DB_NAME/{mine_name}/g" /home/intermine/.intermine/biotestmine.properties
    sed -i "s/PSQL_USER/$PSQL_USER/g" /home/intermine/.intermine/biotestmine.properties
    sed -i "s/PSQL_PWD/$PSQL_PWD/g" /home/intermine/.intermine/biotestmine.properties
    sed -i "s/TOMCAT_USER/$TOMCAT_USER/g" /home/intermine/.intermine/biotestmine.properties
    sed -i "s/TOMCAT_PWD/$TOMCAT_PWD/g" /home/intermine/.intermine/biotestmine.properties
    sed -i "s/webapp.deploy.url=http:\/\/localhost:8080/webapp.deploy.url=http:\/\/tomcat:$TOMCAT_PORT/g" /home/intermine/.intermine/biotestmine.properties
    sed -i "s/serverName=localhost/serverName=postgres:$PGPORT/g" /home/intermine/.intermine/biotestmine.properties


    echo "project.rss=http://localhost:$WORDPRESS_PORT/?feed=rss2" >> /home/intermine/.intermine/biotestmine.properties
    echo "links.blog=https://localhost:$WORDPRESS_PORT" >> /home/intermine/.intermine/biotestmine.properties
fi

if [ ! -f /home/intermine/biotestmine/project.xml ]; then
    echo "$(date +%Y/%m/%d-%H:%M) Copy project.xml to ~/biotestmine/project.xml" >> /home/intermine/logs/progress
    cp /home/intermine/biotestmine/data/project.xml /home/intermine/biotestmine/

    echo "$(date +%Y/%m/%d-%H:%M) Set correct source path in project.xml" >> /home/intermine/logs/progress
    sed -i 's/DATA_DIR/\/home\/intermine\/data/g' /home/intermine/biotestmine/project.xml
fi

if [ ! -d /home/intermine/data/malaria ]; then
    echo "$(date +%Y/%m/%d-%H:%M) Copy malria-data to ~/data" >> /home/intermine/logs/progress
    cp /home/intermine/biotestmine/data/malaria-data.tar.gz /home/intermine/data/
    cd /home/intermine/data/
    tar -xf malaria-data.tar.gz
    rm malaria-data.tar.gz
    cd /home/intermine/
fi

echo "$(date +%Y/%m/%d-%H:%M) Connect and create Postgres databases" >> /home/intermine/logs/progress

# Wait for database
dockerize -wait tcp://postgres:$PGPORT -timeout 60s

# Close all open connections to database
psql -U postgres -h postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid();"

echo "$(date +%Y/%m/%d-%H:%M) Database is now available ..." >> /home/intermine/logs/progress
echo "$(date +%Y/%m/%d-%H:%M) Reset databases and roles" >> /home/intermine/logs/progress

# Delete Databases if exist
psql -U postgres -h postgres -c "DROP DATABASE IF EXISTS \"biotestmine\";"
psql -U postgres -h postgres -c "DROP DATABASE IF EXISTS \"items-biotestmine\";"
psql -U postgres -h postgres -c "DROP DATABASE IF EXISTS \"userprofile-biotestmine\";"

psql -U postgres -h postgres -c "DROP ROLE IF EXISTS $PSQL_USER;"

# Create Databases
echo "$(date +%Y/%m/%d-%H:%M) Creating postgres database tables and roles.." >> /home/intermine/logs/progress
psql -U postgres -h postgres -c "CREATE USER $PSQL_USER WITH PASSWORD '$PSQL_PWD';"
psql -U postgres -h postgres -c "ALTER USER $PSQL_USER WITH SUPERUSER;"
psql -U postgres -h postgres -c "CREATE DATABASE \"biotestmine\";"
psql -U postgres -h postgres -c "CREATE DATABASE \"items-biotestmine\";"
psql -U postgres -h postgres -c "CREATE DATABASE \"userprofile-biotestmine\";"
psql -U postgres -h postgres -c "GRANT ALL PRIVILEGES ON DATABASE biotestmine to $PSQL_USER;"
psql -U postgres -h postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"items-biotestmine\" to $PSQL_USER;"
psql -U postgres -h postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"userprofile-biotestmine\" to $PSQL_USER;"


cd biotestmine

echo "$(date +%Y/%m/%d-%H:%M) Gradle: buildDB" >> /home/intermine/logs/progress
./gradlew buildDB --stacktrace >> /home/intermine/logs/progress

echo "$(date +%Y/%m/%d-%H:%M) Gradle: integrate uniprot-malaria" >> /home/intermine/logs/progress
./gradlew integrate -Psource=uniprot-malaria --stacktrace

echo "$(date +%Y/%m/%d-%H:%M) Gradle: integrate malaria-gff" >> /home/intermine/logs/progress
./gradlew integrate -Psource=malaria-gff --stacktrace

echo "$(date +%Y/%m/%d-%H:%M) Gradle: integrate malaria-chromosome-fasta" >> /home/intermine/logs/progress
./gradlew integrate -Psource=malaria-chromosome-fasta --stacktrace

echo "$(date +%Y/%m/%d-%H:%M) Gradle: integrate entrez-organism" >> /home/intermine/logs/progress
./gradlew integrate -Psource=entrez-organism --stacktrace

echo "$(date +%Y/%m/%d-%H:%M) Gradle: integrate update-publications" >> /home/intermine/logs/progress
./gradlew integrate -Psource=update-publications --stacktrace >> /home/intermine/logs/progress

echo "$(date +%Y/%m/%d-%H:%M) Gradle: run post_processess" >> /home/intermine/logs/progress
./gradlew postProcess --stacktrace >> /home/intermine/logs/progress

echo "$(date +%Y/%m/%d-%H:%M) Gradle: build userDB" >> /home/intermine/logs/progress
./gradlew buildUserDB --stacktrace >> /home/intermine/logs/progress

echo "$(date +%Y/%m/%d-%H:%M) Gradle: build webapp" >> /home/intermine/logs/progress
./gradlew clean
./gradlew cargoRedeployRemote  --stacktrace >> /home/intermine/logs/progress
