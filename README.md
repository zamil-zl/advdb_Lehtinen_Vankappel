# docker_python
 
## import de la base de donnée 
Le choix du language s'est porté sur le python à cause des librairies pour se connecter et uploader les données dans la db neo4j.

Le code pour l'import se trouve dans le dossier "app".

Le script principal est "main.py", "import_db.py" est le script qui a permis de développer en python et rendre la tâche plus facile dans un ide.
"import_db_cython.pyx" permet au module cython de transformer le code en c pour les raisons expliquées dans la partie "Optimisation".  

La lecture du fichier s'est faite grâce à la commande "/usr/bin/wget -O - http://vmrum.isc.heia-fr.ch/dblpv13.json 2>/dev/null" car...

Le résultat de la lecture est un article sous forme de string qui est donné à la partie qui publie dans la db neo4j. 

Chaque article est publié à partir du moment ou il est lu.

Les relations sont créées après la fin de la publication de la totalité de la db, car le code se base sur les propriétés de chaque noeuds pour déterminer les relations. Les relations "AUTHORED" sont créées en inspectant chaque id d'article dans la liste "Iwrote", pour chaque noeuds avec le label "AUTHOR".
Les relations "CITE" sont créées en inspectant chaque id d'article dans la liste "reference", pour chaque noeuds avec le label "ARTICLE".



## Déploiement sur kubernetes

La première étape était de transformer notre code python en container docker.
Le Dockerfile nous permet de faire ceci. Il se base sur l'image officielle de neo4j, puis installe python pour executer notre code, netcat pour vérifier le statut de la db neo4j, et cython. 

Le script neo4j-init.sh est executé qui permet de lancer la db. Il change le mot de passe, et attend un moment avant de lancer le script python

## Optimisation

Si la lecture du fichier du fichier de 17G est executée seule elle met 30 à 40 minutes. 
Cependant la publication dans la database nous prend beaucoup plus de temps. Du coup nous avons essayer de paralléliser les 2 étapes principales du code, la lecture et l'upload, en créant des subprocess. 
En observant que cela ne changeait pas grand chose nous avons essayer d'utiliser "cython", qui permet après une étape de compilation de transformer le code python en extension c, et de l'utiliser depuis le script princpal. Le but était d'executer notre code au niveau le plus bas possible afin d'être le plus efficace, mais nous mettons toujours beaucoup trop de temps. 

## Problèmes rencontrés

Nous avons plusieurs fois vu notre pods disparaitre de notre namespace totalement. Ce qui a coupé notre import sans possibilité de reprendre la ou cela s'était arreter. 
Au final, pour être sur de garder une trace de notre travail dans rancher nous avons décider de faire un "deployment" plutôt qu'un pod. 
