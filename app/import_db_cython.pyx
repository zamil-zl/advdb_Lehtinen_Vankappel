from neo4j import GraphDatabase
import json
import time
import subprocess
import multiprocessing
from datetime import datetime


class neo4jConnector:
    def __init__(self, uri, user, password):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))

    def close(self):
        self.driver.close()

    def retrieve_data(self):
        with self.driver.session() as session:
            query = "MATCH (a:AUTHOR) RETURN a"
            result = session.run(query)
            authors = [record["a"] for record in result]
            query = "MATCH (a:ARTICLE) RETURN a"
            result = session.run(query)
            articles = [record["a"] for record in result]
            return authors,articles

    def author_exists(self, author_id):
        with self.driver.session() as session:
            query = "MATCH (a:AUTHOR {id: $authorId}) RETURN COUNT(a) > 0 AS authorExists"
            result = session.run(query, authorId=author_id)
            return result.single()["authorExists"]


    def execute_query(self, query, label, message):
        with self.driver.session() as session:
            if query == "CREATE_NODE":
                session.execute_write(self._create_node, label, message)
            elif query == "CREATE_RELATION":
                session.execute_write(self._create_relation, label, message)
            elif query == "UPDATE_AUTHOR":
                session.execute_write(self._add_ref, label, message)
    # Node syntax : CREATE (n:LabelName {propertyName: 'propertyValue'})
    @staticmethod
    def _create_node(tx, label, message):
        if label == "ARTICLE" :
            result = tx.run("CREATE (a:" + label + ") "
                                                   "SET a.id = $message['_id'] "
                                                   "SET a.title =  $message['title'] "
                                                   "SET a.references = $message['references'] "
                                                   "RETURN a.id, a.title + ', from node ' + id(a)", message=message)

        elif label == "AUTHOR" :

            result = tx.run("CREATE (a:" + label + ") "
                                                   "SET a.id = $message['id'] "
                                                   "SET a.name = $message['name'] "
                                                   "SET a.Iwrote = [$message['article_id']] "
                                                   "RETURN a.message + ', from node ' + id(a)", message=message)
        elif label == "UPDATE_AUTHOR":
            result = tx.run("MATCH (a:AUTHOR {id: $message['author_id']}) "
                            "SET a.Iwrote = $message['article_id'] "
                            "RETURN a.message + ', from node ' + id(a)", message=message)

        return result.single()[0]

    @staticmethod
    def _create_relation(tx, label, message):

        one_author = message[0]
        article_id = message[1]

        if label == "AUTHOR":
            author_id = message[0]
            article_id = message[1]
            # print("ONE AUTHOR", one_author)
            # Assuming a relationship type of "AUTHOR_OF"
            #message 0 = author ID
            #message 1 = all the article ID
            for one_article_id in article_id:
                if one_article_id is not None and author_id is not None:
                    query = "MATCH (a:ARTICLE), (b:AUTHOR) WHERE a.id = '" + one_article_id + "' AND b.id = '" + author_id + "' CREATE (b)-[:AUTHORED]->(a)"
                    result = tx.run(query)
                    #print(query)

        elif label == "ARTICLE":
            # [article["id"], article["references"], article["n_citation"]]
            if message[2] is not None:
                reference = {"id" : message[0], "allReferences" : message[1]}
                # print(reference['id'])
                # print(reference['allReferences'])
                for oneRef in reference['allReferences']:
                    the_link = {"id" : reference['id'], "reference" : oneRef}
                    query = "MATCH (a:ARTICLE), (b:ARTICLE) WHERE a.id = '" + the_link['id'] + "' AND b.id = '" + the_link['reference'] + "'CREATE (a)-[:CITE]->(b)"
                    result = tx.run(query)
                    # print("my query:", query)

    @staticmethod
    def _add_ref(tx, label, message):
        """Adds an article id that this author wrote"""
        # print(message)
        author_id = message['author_id']
        article_id = message['article_id']
        if label == "AUTHOR":
            query = "MATCH (a:AUTHOR {id: \"" + author_id + "\"}) SET a.Iwrote = a.Iwrote + \"" + str(article_id) + "\" RETURN a"
            result = tx.run(query)
            # print(query)

def parse_json(filePath):
    """
        :param filePath: path of json file (string) to be parsed.
        :return: list of all objects in the json file.
    """
    try:
        with open(filePath, 'r') as json_file:
            data = json.load(json_file)
    except FileNotFoundError:
        print(f"File '{filePath}' not found.")
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON: {e}")

    return data


def import_jsonToNeo(articleString, connector):
    """
            :param data_file_path: path to json file containing data to import to db.
            :param connector: connector object to db
            :return: list of author objects.
    """
    finalArticle = json.loads(articleString)
    index = 1
    # Node creation
    for oneObject in finalArticle:
        article_id = oneObject['_id']
        if 'title' in oneObject and oneObject['title'] is not None:
            message = {"_id" : oneObject['_id'], "title" : oneObject['title']}
        elif 'title' not in oneObject or oneObject['title'] is None:
            message = {"_id" : oneObject['_id'], "title" : "No Title"}
        # print(oneObject)
        if 'references' in oneObject and oneObject['references'] is not None:
            message.update({"references" : oneObject['references']})
        connector.execute_query("CREATE_NODE", "ARTICLE", message)

        if "authors" in oneObject:
            for oneAuthor in oneObject["authors"]:
                # print("AUTHOR", oneAuthor)
                if "_id" in oneAuthor and connector.author_exists(oneAuthor["_id"]):
                    # print("Author already exists")
                    message = {"author_id" : str(oneAuthor["_id"]), "article_id" : str(oneObject["_id"])}
                    connector.execute_query("UPDATE_AUTHOR", "AUTHOR", message)
                elif "name" in oneAuthor and connector.author_exists(oneAuthor["name"]):
                    # print("Author already exists")
                    message = {"author_id" : str(oneAuthor["name"]), "article_id" : str(oneObject["_id"])}
                    connector.execute_query("UPDATE_AUTHOR", "AUTHOR", message)
                else:
                    message = {"article_id" : article_id}
                    if "_id" in oneAuthor:
                        message.update({"id": oneAuthor["_id"]})
                    if "name" in oneAuthor:
                        message.update({"name": oneAuthor["name"]})
                    connector.execute_query("CREATE_NODE", "AUTHOR", message)

        # print("\n\nArticle :", index)
        index += 1


def create_relations(connector):
    """

            :param connector: connector object to db
            :return: list of author objects.
    """
    authors, articles = connector.retrieve_data()
    for author in authors:
        connector.execute_query("CREATE_RELATION", "AUTHOR", [author["id"], author["Iwrote"]])

    for article in articles:
        connector.execute_query("CREATE_RELATION", "ARTICLE", [article["id"], article["references"], article["references"]])



def subprocess1(pipe):      # mon code
    # Code du premier subprocess
    # read command
    command = "/usr/bin/wget -O - http://vmrum.isc.heia-fr.ch/dblpv13.json 2>/dev/null"

    # execute read command and process data progressivly
    process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1, universal_newlines=True)

    line = ""
    bloc = ""
    det = 0

    percent = 4091293
    percentage = 0
    p = 0

    articleCount = 0
    
    print("BEGIN OF IMPORT", datetime.now() )

    # process lines progressivly
    for i, line in enumerate(process.stdout):
        
        if line.strip().startswith('{') or line.strip().endswith('{'):
            det += 1
            bloc += line.strip()
        elif line.strip().endswith('}') or line.strip().endswith('},'):
            det -= 1
            bloc += line.strip()
        elif det > 0:
            bloc += line.strip()

        if det == 0 and len(bloc) > 5:
            bloc = bloc[:-1]
            articleCount += 1
            
            oneArticle = "["
            oneArticle += str(bloc)
            oneArticle += "]"
            
            # Replace NumberInt() with a plain integer
            oneArticle = oneArticle.replace("NumberInt(", "").replace(")", "")
            

            # put oneArticle in pipe 
            pipe.send(oneArticle)
            # processArticle(bloc)
            # do next line in a subprocess
            # import_jsonToNeo(oneArticle, neo4jCo)
            

            if i >= p:
                print(f"{percentage} % done - {i} lines - {articleCount} articles ", datetime.now())
                p += percent
                percentage += 1
            bloc = ""


    # end of read
    stdout_data, stderr_data = process.communicate()

    # check for error code
    if process.returncode != 0:
        print(f"Error {process.returncode}")
        print(stderr_data)
    
    #fin de mon code
    pipe.close()


def subprocess2(pipe):      # ton code
    print("connector created")

    neo4jCo = neo4jConnector("neo4j://localhost:7687", "neo4j", "testtest")


    while True:         #réception de la fifo
        try:
            data = pipe.recv()
            import_jsonToNeo(data, neo4jCo)
        except EOFError:
            break

    print("END OF IMPORT", datetime.now())
    print("BEGIN OF RELATION CREATION", datetime.now())
    create_relations(neo4jCo)

    neo4jCo.close()

    print("END OF RELATION CREATION", datetime.now())

     


def main():
    
    # listOfObjects = parse_json(json_file_path)
    # listOfObjects = json.loads(twoObjects)
    # half = len(listOfObjects) // 2
    # firstList = listOfObjects[:half]
    # secondHalf = listOfObjects[half:]
    # upload based on what is given
    # import_jsonToNeo(listOfObjects, neo4jCo)

    # function to create relations, with retrieve data function that use only data existing in the db
    # do next line in a subprocess
    # Créer un fifo
    parent_conn, child_conn = multiprocessing.Pipe()

    # Créer les deux subprocess
    process1 = multiprocessing.Process(target=subprocess1, args=(child_conn,))
    process2 = multiprocessing.Process(target=subprocess2, args=(parent_conn,))

    # Démarrer les subprocess
    process1.start()
    process2.start()

    # Attendre la fin des subprocess
    process1.join()
    process2.join()