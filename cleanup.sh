#!/bin/bash

# Colores para mejor visualización
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${YELLOW}Limpiando el entorno...${NC}"

# 1. Detener todos los contenedores y eliminar volúmenes
echo -e "${YELLOW}Deteniendo contenedores...${NC}"
docker-compose down --volumes --remove-orphans

# 2. Eliminar todos los contenedores relacionados con Fabric
echo -e "${YELLOW}Eliminando contenedores de Hyperledger...${NC}"
docker rm -f $(docker ps -a | grep hyperledger | awk '{print $1}') 2>/dev/null || true

# 3. Eliminar volúmenes
echo -e "${YELLOW}Eliminando volúmenes...${NC}"
docker volume rm $(docker volume ls -q | grep "orderer\|peer") 2>/dev/null || true
docker volume prune -f

# 4. Eliminar directorios generados
echo -e "${YELLOW}Eliminar directorios generados...${NC}"
rm -rf organizations/ordererOrganizations
rm -rf organizations/peerOrganizations
rm -rf channel-artifacts/*
rm -rf configtx/genesis.block
rm -rf config/core.yaml config/orderer.yaml

# 5. Recrear estructura de directorios
echo -e "${YELLOW}Recreando estructura de directorios...${NC}"
mkdir -p organizations/ordererOrganizations
mkdir -p organizations/peerOrganizations
mkdir -p channel-artifacts
mkdir -p configtx
mkdir -p config
mkdir -p scripts
mkdir -p chaincode/asset-transfer/javascript

# 7. Dar permisos de ejecución a los scripts
echo -e "${YELLOW}Configurando permisos de scripts...${NC}"
chmod +x *.sh
chmod +x scripts/*.sh 2>/dev/null || true

echo -e "${GREEN}Limpieza completada. El entorno está listo para iniciar.${NC}"
echo -e "${YELLOW}Ahora puedes ejecutar:${NC}"
echo -e "${GREEN}./setup.sh${NC}"
echo -e "${GREEN}./startNetwork.sh${NC}" 