#!/bin/bash

# Colores para mejor visualización
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${YELLOW}🔍 Iniciando verificaciones...${NC}"

# 1. Verificar estructura de directorios
echo -e "\n${YELLOW}📁 Verificando directorios...${NC}"
echo "configtx/:"
ls -la configtx/
echo -e "\nconfig/:"
ls -la config/
echo -e "\norganizations/:"
ls -la organizations/
echo -e "\nchannel-artifacts/:"
ls -la channel-artifacts/
echo -e "\nscripts/:"
ls -la scripts/
echo -e "\nchaincode/:"
ls -la chaincode/

# 2. Verificar archivos de configuración críticos
echo -e "\n${YELLOW}📄 Verificando archivos de configuración...${NC}"
if [ -f "config/crypto-config.yaml" ] && [ -f "configtx/configtx.yaml" ]; then
    echo -e "${GREEN}✅ Archivos de configuración presentes${NC}"
    # Verificar contenido de directorios críticos
    if [ ! -d "organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp" ] || \
       [ ! -d "organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls" ]; then
        echo -e "${RED}❌ Certificados del orderer no generados${NC}"
        exit 1
    fi
    
    if [ ! -f "channel-artifacts/genesis.block" ] || [ ! -f "channel-artifacts/channel.tx" ]; then
        echo -e "${RED}❌ Artefactos del canal no generados${NC}"
        exit 1
    fi

    if [ ! -f "config/core.yaml" ] || [ ! -f "config/orderer.yaml" ]; then
        echo -e "${RED}❌ Faltan archivos de configuración core.yaml o orderer.yaml${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Faltan archivos de configuración${NC}"
    exit 1
fi

# 3. Verificar scripts necesarios
echo -e "\n${YELLOW}📜 Verificando scripts...${NC}"
if [ -x "scripts/generateCerts.sh" ] && [ -x "scripts/generateChannelArtifacts.sh" ]; then
    echo -e "${GREEN}✅ Scripts con permisos correctos${NC}"
else
    echo -e "${RED}❌ Problemas con los scripts${NC}"
    exit 1
fi

# 4. Verificar docker-compose.yaml
echo -e "\n${YELLOW}🐳 Verificando docker-compose.yaml...${NC}"
if [ -f "docker-compose.yaml" ]; then
    echo -e "${GREEN}✅ docker-compose.yaml presente${NC}"
    echo "Servicios definidos:"
    grep "container_name:" docker-compose.yaml
    
    # Verificar que el docker-compose contiene todos los servicios necesarios
    for service in orderer.example.com peer0.org1.example.com peer0.org2.example.com couchdb0.org1.example.com couchdb0.org2.example.com; do
        if grep -q "container_name: $service" docker-compose.yaml; then
            echo -e "${GREEN}✅ Servicio $service encontrado${NC}"
        else
            echo -e "${RED}❌ Servicio $service no encontrado en docker-compose.yaml${NC}"
        fi
    done
else
    echo -e "${RED}❌ Falta docker-compose.yaml${NC}"
    exit 1
fi

# 5. Verificar herramientas Fabric
echo -e "\n${YELLOW}🛠️ Verificando herramientas Fabric...${NC}"
if command -v cryptogen &> /dev/null && command -v configtxgen &> /dev/null; then
    echo -e "${GREEN}✅ Herramientas Fabric disponibles${NC}"
    echo "cryptogen version:"
    cryptogen version
    echo "configtxgen version:"
    configtxgen --version
else
    echo -e "${RED}❌ Faltan herramientas Fabric${NC}"
    exit 1
fi

# 6. Verificar imágenes Docker
echo -e "\n${YELLOW}🐋 Verificando imágenes Docker...${NC}"
echo "Imágenes Hyperledger necesarias:"
REQUIRED_IMAGES=("hyperledger/fabric-peer:2.2" "hyperledger/fabric-orderer:2.2" "hyperledger/fabric-couchdb:0.4.22" "hyperledger/fabric-tools:2.2")
MISSING_IMAGES=0

for image in "${REQUIRED_IMAGES[@]}"; do
    if docker images | grep -q "${image%%:*}" | grep -q "${image#*:}"; then
        echo -e "${GREEN}✅ Imagen $image encontrada${NC}"
    else
        echo -e "${RED}❌ Imagen $image NO encontrada${NC}"
        MISSING_IMAGES=1
    fi
done

if [ $MISSING_IMAGES -eq 0 ]; then
    echo -e "${GREEN}✅ Todas las imágenes requeridas están presentes${NC}"
else
    echo -e "${RED}❌ Faltan algunas imágenes requeridas${NC}"
fi

# 7. Verificar contenedores en ejecución
echo -e "\n${YELLOW}🔄 Verificando contenedores en ejecución...${NC}"
if docker ps | grep hyperledger; then
    echo -e "${YELLOW}⚠️  Hay contenedores Fabric ejecutándose${NC}"
else
    echo -e "${GREEN}✅ No hay contenedores Fabric ejecutándose${NC}"
fi

# 8. Verificar resolución de nombres
echo -e "\n${YELLOW}🔍 Verificando resolución de nombres...${NC}"
# Verificar si el archivo docker-compose tiene extra_hosts
if grep -q "extra_hosts:" docker-compose.yaml; then
    echo -e "${GREEN}✅ Configuración extra_hosts presente en docker-compose.yaml${NC}"
else
    echo -e "${YELLOW}⚠️ No se encontró configuración extra_hosts en docker-compose.yaml${NC}"
    echo -e "${YELLOW}⚠️ Puede causar problemas de resolución de nombres entre contenedores${NC}"
fi

# 9. Verificar espacio en disco
echo -e "\n${YELLOW}💾 Verificando espacio en disco...${NC}"
MIN_SPACE_GB=10
AVAILABLE_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
if [ $AVAILABLE_SPACE -lt $MIN_SPACE_GB ]; then
    echo -e "${RED}⚠️ Poco espacio en disco: $AVAILABLE_SPACE GB (recomendado: $MIN_SPACE_GB GB)${NC}"
else
    echo -e "${GREEN}✅ Espacio en disco suficiente: $AVAILABLE_SPACE GB${NC}"
fi

# 10. Verificar red Docker
echo -e "\n${YELLOW}🌐 Verificando red Docker...${NC}"
if docker network ls | grep -q "fabric_test"; then
    echo -e "${GREEN}✅ Red fabric_test encontrada${NC}"
else
    echo -e "${YELLOW}⚠️ Red fabric_test no encontrada, será creada al iniciar la red${NC}"
fi

# 11. Verificar configuración de CouchDB
echo -e "\n${YELLOW}🗃️ Verificando configuración de CouchDB...${NC}"
if grep -q "CORE_LEDGER_STATE_STATEDATABASE=CouchDB" docker-compose.yaml; then
    echo -e "${GREEN}✅ CouchDB está configurado como base de datos de estado${NC}"
    
    # Verificar puertos de CouchDB
    if grep -q "5984:5984" docker-compose.yaml && \
       grep -q "6984:5984" docker-compose.yaml && \
       grep -q "7984:5984" docker-compose.yaml && \
       grep -q "8984:5984" docker-compose.yaml; then
        echo -e "${GREEN}✅ Puertos de CouchDB configurados correctamente${NC}"
    else
        echo -e "${RED}❌ Problema con la configuración de puertos de CouchDB${NC}"
    fi
else
    echo -e "${RED}❌ CouchDB no está configurado como base de datos de estado${NC}"
fi

echo -e "\n${GREEN}✨ Verificación completa${NC}"
if [ -d "organizations/ordererOrganizations" ] && \
   [ -d "organizations/peerOrganizations" ] && \
   [ -f "channel-artifacts/genesis.block" ] && \
   [ -f "channel-artifacts/channel.tx" ] && \
   [ -f "channel-artifacts/Org1MSPanchors.tx" ] && \
   [ -f "channel-artifacts/Org2MSPanchors.tx" ]; then
    echo -e "${GREEN}✅ Todo está listo para iniciar la red${NC}"
    echo -e "${GREEN}✅ Puedes ejecutar ./startNetwork.sh${NC}"
else
    echo -e "${RED}❌ Faltan archivos necesarios. Ejecuta ./setup.sh para generarlos${NC}"
    exit 1
fi