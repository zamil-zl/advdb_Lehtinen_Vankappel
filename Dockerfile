# begin with neo4j image
FROM neo4j:latest
 
# install python in image
RUN apt-get update && apt-get install -y python3 python3-pip netcat vim && pip3 install cython && rm -rf /var/lib/apt/lists/*


# Use the official Python image as the base image
# FROM python:3.10
 
# Set the working directory in the container
WORKDIR /app
 
# Copy the current directory contents into the container at /app
COPY /app .
 
# Install any dependencies specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
 
# Expose the port the app runs on
EXPOSE 7474 7687
 
# Launch neo4j
RUN chmod +rwx neo4j-init.sh

ENV PYTHONUNBUFFERED 1
 
ENTRYPOINT ["./neo4j-init.sh"]
 