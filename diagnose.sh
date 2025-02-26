#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${YELLOW}Iniciando diagnóstico para el error del orderer...${NC}"

# Verificar los directorios críticos
echo -e "\n${YELLOW}Verificando directorios críticos para el orderer...${NC}"

if [ -f "channel-artifacts/genesis.block" ]; then
    echo -e "${GREEN}✓ channel-artifacts/genesis.block existe${NC}"
    ls -la channel-artifacts/genesis.block
else
    echo -e "${RED}✗ channel-artifacts/genesis.block no existe${NC}"
fi

if [ -d "organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp" ]; then
    echo -e "${GREEN}✓ organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp existe${NC}"
    ls -la organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp
else
    echo -e "${RED}✗ organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp no existe${NC}"
fi

if [ -d "organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls" ]; then
    echo -e "${GREEN}✓ organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls existe${NC}"
    ls -la organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls
else
    echo -e "${RED}✗ organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls no existe${NC}"
fi

if [ -f "config/orderer.yaml" ]; then
    echo -e "${GREEN}✓ config/orderer.yaml existe${NC}"
    ls -la config/orderer.yaml
else
    echo -e "${RED}✗ config/orderer.yaml no existe${NC}"
fi

# Verificar docker-compose.yaml
echo -e "\n${YELLOW}Verificando docker-compose.yaml...${NC}"
grep -A 15 "orderer.example.com:" docker-compose.yaml

# Verificar los directorios de volúmenes
echo -e "\n${YELLOW}Verificando los directorios montados en docker-compose.yaml...${NC}"
volumes_to_check=$(grep -A 15 "volumes:" docker-compose.yaml | grep "source:" | grep -oE "\.\/[^\"]+")

for volume in $volumes_to_check; do
    if [ -e "$volume" ]; then
        echo -e "${GREEN}✓ $volume existe${NC}"
    else
        echo -e "${RED}✗ $volume no existe${NC}"
    fi
done

echo -e "\n${YELLOW}Sugerencia: Si falta algún directorio, ejecuta ./setup.sh de nuevo.${NC}"
echo -e "${YELLOW}Si el problema persiste, revisa manualmente el archivo docker-compose.yaml y asegúrate de que todas las rutas existen.${NC}"