#!/bin/bash
 
# Set the initial password using neo4j-admin
neo4j-admin dbms set-initial-password testtest
 
# Start Neo4j
neo4j start &
 
# Wait for Neo4j to start (you're already doing this)
while ! nc -z localhost 7474; do
  sleep 1
done

python3 setup.py build_ext --inplace

# Run your Python script
python3 main.py

tail -f /dev/null