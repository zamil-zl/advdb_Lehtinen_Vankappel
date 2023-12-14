#!binsh
set -e

host=$1
shift
cmd=$@

until cypher-shell -a bolt${host} -u neo4j -p testtest RETURN 1 devnull 2&1; do
  &2 echo Neo4j is unavailable - sleeping
  sleep 1
done

&2 echo Neo4j is up - executing command
exec $cmd
