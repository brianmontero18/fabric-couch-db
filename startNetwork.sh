#!/bin/bash

# Colores para mejor visualización
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Verificar que todo esté listo
if [ ! -d "organizations/ordererOrganizations" ] || \
   [ ! -f "channel-artifacts/genesis.block" ]; then
    echo -e "${RED}Error: Ejecuta primero ./setup.sh${NC}"
    exit 1
fi

echo -e "${YELLOW}Iniciando la red...${NC}"
docker-compose down --volumes --remove-orphans 2>/dev/null
docker-compose up -d

# Función para verificar si un servicio está en ejecución
check_service() {
    local service=$1
    local max_attempts=30
    local attempt=1
    
    echo -e "${YELLOW}Esperando a que $service esté listo...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if docker ps | grep -q $service; then
            echo -e "${GREEN}$service está en ejecución${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt+1))
    done
    
    echo -e "\n${RED}$service no se inició correctamente después de $(($max_attempts*2)) segundos${NC}"
    return 1
}

# Verificar servicios críticos
check_service "orderer.example.com"
check_service "peer0.org1.example.com"
check_service "peer0.org2.example.com"
check_service "couchdb0.org1.example.com"

echo -e "${YELLOW}Esperando a que los servicios inicialicen completamente...${NC}"
sleep 30

# Función para mejorar logging
log_message() {
    local level=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# Verificar CouchDB con los puertos correctos
echo -e "${YELLOW}Verificando CouchDB...${NC}"
check_couchdb() {
    local name=$1
    local port=$2
    echo -e "${YELLOW}Verificando $name en puerto $port...${NC}"
    if ! curl -s http://localhost:$port > /dev/null; then
        echo -e "${RED}Error: $name no responde en puerto $port${NC}"
        return 1
    else
        echo -e "${GREEN}$name está respondiendo correctamente${NC}"
        return 0
    fi
}

check_couchdb "couchdb0.org1.example.com" 5984
check_couchdb "couchdb1.org1.example.com" 6984
check_couchdb "couchdb0.org2.example.com" 7984
check_couchdb "couchdb1.org2.example.com" 8984

echo -e "${YELLOW}Configurando variables de entorno...${NC}"
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

# Función para registrar un error y continuar
log_error() {
    local message=$1
    echo -e "${RED}ERROR: $message${NC}"
    # Agregar al log de errores
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $message" >> network_errors.log
}

echo -e "${YELLOW}Creando canal...${NC}"
peer channel create -o localhost:7050 -c mychannel \
    --ordererTLSHostnameOverride orderer.example.com \
    -f ./channel-artifacts/channel.tx --outputBlock ./channel-artifacts/mychannel.block \
    --tls --cafile $ORDERER_CA

# Si la creación del canal falla, intentar diagnosticar
if [ $? -ne 0 ]; then
    log_error "Error al crear el canal, intentando diagnosticar..."
    
    # Verificar si el orderer está respondiendo
    if ! curl -k https://localhost:7050 > /dev/null 2>&1; then
        log_error "El orderer no está respondiendo en puerto 7050"
        docker logs orderer.example.com | tail -n 50 >> network_errors.log
    fi
    
    # Verificar si el archivo genesis.block está correctamente montado
    docker exec orderer.example.com ls -la /var/hyperledger/orderer/orderer.genesis.block >> network_errors.log 2>&1
    
    # Continuar con el resto del script intentando unir al canal
    echo -e "${YELLOW}Intentando continuar con la unión al canal...${NC}"
else
    echo -e "${GREEN}Canal creado correctamente${NC}"
fi

# Unir peer0.org1 al canal
echo -e "${YELLOW}Uniendo peer0.org1 al canal...${NC}"
peer channel join -b ./channel-artifacts/mychannel.block

if [ $? -ne 0 ]; then
    log_error "Error al unir peer0.org1 al canal"
    docker logs peer0.org1.example.com | tail -n 50 >> network_errors.log
else
    echo -e "${GREEN}peer0.org1 unido al canal correctamente${NC}"
fi

# Unir peer1.org1 al canal
echo -e "${YELLOW}Uniendo peer1.org1 al canal...${NC}"
export CORE_PEER_ADDRESS=localhost:8051
peer channel join -b ./channel-artifacts/mychannel.block

if [ $? -ne 0 ]; then
    log_error "Error al unir peer1.org1 al canal"
    docker logs peer1.org1.example.com | tail -n 50 >> network_errors.log
else
    echo -e "${GREEN}peer1.org1 unido al canal correctamente${NC}"
fi

# Cambiar a org2
echo -e "${YELLOW}Cambiando a Org2...${NC}"
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

# Unir peer0.org2 al canal
echo -e "${YELLOW}Uniendo peer0.org2 al canal...${NC}"
peer channel join -b ./channel-artifacts/mychannel.block

if [ $? -ne 0 ]; then
    log_error "Error al unir peer0.org2 al canal"
    docker logs peer0.org2.example.com | tail -n 50 >> network_errors.log
else
    echo -e "${GREEN}peer0.org2 unido al canal correctamente${NC}"
fi

# Unir peer1.org2 al canal
echo -e "${YELLOW}Uniendo peer1.org2 al canal...${NC}"
export CORE_PEER_ADDRESS=localhost:10051
peer channel join -b ./channel-artifacts/mychannel.block

if [ $? -ne 0 ]; then
    log_error "Error al unir peer1.org2 al canal"
    docker logs peer1.org2.example.com | tail -n 50 >> network_errors.log
else
    echo -e "${GREEN}peer1.org2 unido al canal correctamente${NC}"
fi

# Actualizar anclajes para Org1
echo -e "${YELLOW}Actualizando anclajes para Org1...${NC}"
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c mychannel -f ./channel-artifacts/Org1MSPanchors.tx --tls --cafile $ORDERER_CA

if [ $? -ne 0 ]; then
    log_error "Error al actualizar anclajes para Org1"
else
    echo -e "${GREEN}Anclajes de Org1 actualizados correctamente${NC}"
fi

# Actualizar anclajes para Org2
echo -e "${YELLOW}Actualizando anclajes para Org2...${NC}"
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c mychannel -f ./channel-artifacts/Org2MSPanchors.tx --tls --cafile $ORDERER_CA

if [ $? -ne 0 ]; then
    log_error "Error al actualizar anclajes para Org2"
else
    echo -e "${GREEN}Anclajes de Org2 actualizados correctamente${NC}"
fi

echo -e "${GREEN}Red iniciada correctamente${NC}"
echo -e "${GREEN}===============================${NC}"
echo -e "${GREEN}Resumen de la red:${NC}"
echo -e "${YELLOW}Canal mychannel creado${NC}"
echo -e "${YELLOW}4 peers unidos al canal:${NC}"
echo -e "  - peer0.org1.example.com (puerto 7051)"
echo -e "  - peer1.org1.example.com (puerto 8051)"
echo -e "  - peer0.org2.example.com (puerto 9051)"
echo -e "  - peer1.org2.example.com (puerto 10051)"
echo -e "${YELLOW}4 instancias de CouchDB funcionando:${NC}"
echo -e "  - Para peer0.org1: puerto 5984"
echo -e "  - Para peer1.org1: puerto 6984"
echo -e "  - Para peer0.org2: puerto 7984"
echo -e "  - Para peer1.org2: puerto 8984"
echo -e "${GREEN}La red está lista para desplegar chaincodes${NC}"