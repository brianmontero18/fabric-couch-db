#!/bin/bash

# Crear directorio para logs
LOG_DIR="network_logs_$(date +%Y%m%d_%H%M%S)"
mkdir -p $LOG_DIR

# Función para guardar logs de un contenedor
save_container_logs() {
    container=$1
    echo "Recopilando logs de $container..."
    docker logs $container > "$LOG_DIR/${container}_logs.txt" 2>&1
    docker inspect $container > "$LOG_DIR/${container}_inspect.json" 2>&1
}

# Recopilar logs de todos los contenedores
save_container_logs "peer0.org1.example.com"
save_container_logs "peer1.org1.example.com"
save_container_logs "peer0.org2.example.com"
save_container_logs "peer1.org2.example.com"
save_container_logs "orderer.example.com"
save_container_logs "couchdb0.org1.example.com"
save_container_logs "couchdb1.org1.example.com"
save_container_logs "couchdb0.org2.example.com"
save_container_logs "couchdb1.org2.example.com"

# Guardar estado de la red Docker
echo "Guardando estado de la red..."
docker network inspect fabric_test > "$LOG_DIR/network_inspect.json"

# Guardar lista de contenedores
echo "Guardando lista de contenedores..."
docker ps -a > "$LOG_DIR/containers_list.txt"

# Comprimir todos los logs
tar czf "${LOG_DIR}.tar.gz" $LOG_DIR
rm -rf $LOG_DIR

echo "Logs recopilados en ${LOG_DIR}.tar.gz" 