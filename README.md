# docker_compose_biotestmine
Intermine's biotestmine complete build within Docker containers

# Download
~~~bash
git clone git@github.com:nauer/docker_compose_biotestmine.git
~~~

# Start Container
~~~bash
cd docker_compose_biotestmine
docker-compose up
~~~

# Run Build Script
~~~bash
docker-compose exec build build.sh
~~~

# Browse your Mine
[http://localhost:8080/biotestmine]([http://localhost:8080/biotestmine)

# Configure
It is very easy to test the mine with different software versions of your tools. For example to use a differnt postgres
version in your mine you only have to change the `PSQL_VERSION` tag in the `.env` file for the postgres conatiner and 
restart the docker container.

