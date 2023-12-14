# docker_python
 
## import de la base de donnée 
Le choix du language s'est porté sur le python car il intègre des librairies qui permettent de se connecter et uploader des données dans une base de donnée neo4j.

Le code pour l'import se trouve dans le dossier "app".

Le script principal est "main.py", "import_db.py" est le script qui a permis de développer en python et rendre la tâche plus facile dans un ide.
"import_db_cython.pyx" permet au module cython de transformer le code python en code C pour les raisons expliquées dans la partie "Optimisation".  

La lecture du fichier est faite avec la commande "/usr/bin/wget -O - http://vmrum.isc.heia-fr.ch/dblpv13.json 2>/dev/null". Elle nous permet de lire le fichier petit à petit.

Les articles présent dans le fichier JSON sont envoyés un à un sous forme de string à la partie qui publie les données dans la base de donnée. 

Chaque article est publié après avoir été lu dans le fichier JSON. La lecture du fichier et la publication dans la base de donnée sont faites dans 2 subprocess différents. Les données transittent d'un à l'autre à travers un buffer FIFO.

Les relations sont créées après la fin de la publication de la totalité de la db, car le code se base sur les propriétés de chaque noeuds pour déterminer les relations. Les relations "AUTHORED" sont créées en inspectant chaque id d'article dans la liste "Iwrote", pour chaque noeuds avec le label "AUTHOR".
Les relations "CITE" sont créées en inspectant chaque id d'article dans la liste "reference", pour chaque noeuds avec le label "ARTICLE".



## Déploiement sur kubernetes

La première étape était de transformer notre code python en container docker.
Le Dockerfile nous permet de faire ceci. Il se base sur l'image officielle de neo4j, puis installe python pour executer notre code, netcat pour vérifier le statut de la db neo4j, et cython. 

Le script neo4j-init.sh est executé qui permet de lancer la db. Il change le mot de passe, et attend un moment avant de lancer le script python

## Optimisation

Si la lecture du fichier du fichier de 17G est executée seule, sans importer les données dans la base de donnée, elle met 30 à 40 minutes avec le fichier stocké en local. 
Cependant la publication dans la base de donnée nous prend beaucoup plus de temps. Nous avons alors essayé de paralléliser les 2 étapes principales du code, la lecture et l'upload, en créant des subprocess. Le temps total n'est cependant pas significativement baissé car les temps d'exécution des deux tâches ne sont pas équilibrés. Nous avons ensuite essayé d'utiliser "cython", qui permet après une étape de compilation de transformer le code python en extension c, et de l'utiliser depuis le script princpal. Le but était d'executer notre code au niveau le plus bas possible afin d'être le plus efficace, mais nous mettons toujours beaucoup trop de temps. Nous n'avons pas pu importer l'entièreté des données en raison des problèmes rencontrés décrits dans le prochain point. 

## Problèmes rencontrés

Nous avons plusieurs fois vu notre pods disparaitre de notre namespace totalement. Ce qui a coupé notre import sans possibilité de reprendre là ou cela s'était arreté. 
Au final, pour être sur de garder une trace de notre travail dans rancher nous avons décidé de faire un "deployment" plutôt qu'un pod. 
