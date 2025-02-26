#!/bin/bash

# Script para desplegar una red Hyperledger Fabric con CouchDB
# ============================================================

# Colores para mejor visualización
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================================${NC}"
echo -e "${BLUE}  Despliegue de Red Hyperledger Fabric con CouchDB     ${NC}"
echo -e "${BLUE}=======================================================${NC}"

# Agregar al inicio del script
echo -e "${YELLOW}Limpiando instalación previa si existe...${NC}"
docker-compose down --volumes --remove-orphans 2>/dev/null
rm -rf organizations channel-artifacts

# Usar el directorio actual
PROJECT_DIR=$(pwd)

# Verificar y configurar PATH de binarios de manera más robusta
setup_binaries() {
    if [ -d "./fabric-samples/bin" ]; then
        export PATH=$PATH:$PWD/fabric-samples/bin
        echo -e "${GREEN}Usando binarios locales en ./fabric-samples/bin${NC}"
    elif [ -d "../bin" ]; then
        export PATH=$PATH:$PWD/../bin
        echo -e "${GREEN}Usando binarios locales en ../bin${NC}"
    elif [ -d "$HOME/fabric-samples/bin" ]; then
        export PATH=$PATH:$HOME/fabric-samples/bin
        echo -e "${GREEN}Usando binarios en $HOME/fabric-samples/bin${NC}"
    else
        echo -e "${YELLOW}Binarios de Fabric no encontrados, descargando...${NC}"
        curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.2.2 1.4.9
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error al descargar Hyperledger Fabric.${NC}"
            exit 1
        fi
        
        # Verificar de nuevo después de la descarga
        if [ -d "./fabric-samples/bin" ]; then
            export PATH=$PATH:$PWD/fabric-samples/bin
        elif [ -d "../bin" ]; then
            export PATH=$PATH:$PWD/../bin
        elif [ -d "$HOME/fabric-samples/bin" ]; then
            export PATH=$PATH:$HOME/fabric-samples/bin
        else
            echo -e "${RED}No se pudo encontrar los binarios de Fabric después de la descarga.${NC}"
            exit 1
        fi
    fi

    # Verificar que los binarios están disponibles
    if ! command -v configtxgen &> /dev/null || ! command -v cryptogen &> /dev/null; then
        echo -e "${RED}Error: Binarios de Fabric no encontrados en el PATH${NC}"
        echo -e "${RED}Ubicaciones buscadas: ./fabric-samples/bin, ../bin, $HOME/fabric-samples/bin${NC}"
        exit 1
    fi
}

# Verificar prerequisitos
check_prerequisites() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker no está instalado${NC}"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Error: Docker Compose no está instalado${NC}"
        exit 1
    fi

    # Verificar espacio en disco
    MIN_SPACE_GB=10
    AVAILABLE_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ $AVAILABLE_SPACE -lt $MIN_SPACE_GB ]; then
        echo -e "${RED}Error: Se requieren al menos ${MIN_SPACE_GB}GB de espacio libre${NC}"
        exit 1
    fi
}

# Crear estructura de directorios
create_directories() {
    echo -e "${YELLOW}Creando estructura de directorios...${NC}"
    mkdir -p organizations/ordererOrganizations
    mkdir -p organizations/peerOrganizations
    mkdir -p channel-artifacts
    mkdir -p configtx
    mkdir -p config
    mkdir -p scripts
    mkdir -p chaincode/asset-transfer/javascript
}

# Ejecutar verificaciones de prerequisitos
check_prerequisites

# Configurar binarios
setup_binaries

# Consistentemente usar configtx para configuración
export FABRIC_CFG_PATH=$PWD/configtx

# Crear directorios
create_directories

# Crear archivo configtx.yaml
echo -e "${YELLOW}Creando archivo configtx.yaml...${NC}"
cat > configtx/configtx.yaml << 'EOF'
---
Organizations:
    - &OrdererOrg
        Name: OrdererOrg
        ID: OrdererMSP
        MSPDir: ../organizations/ordererOrganizations/example.com/msp
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('OrdererMSP.member')"
            Writers:
                Type: Signature
                Rule: "OR('OrdererMSP.member')"
            Admins:
                Type: Signature
                Rule: "OR('OrdererMSP.admin')"
        OrdererEndpoints:
            - orderer.example.com:7050

    - &Org1
        Name: Org1MSP
        ID: Org1MSP
        MSPDir: ../organizations/peerOrganizations/org1.example.com/msp
        AnchorPeers:
            - Host: peer0.org1.example.com
              Port: 7051
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('Org1MSP.admin', 'Org1MSP.peer', 'Org1MSP.client')"
            Writers:
                Type: Signature
                Rule: "OR('Org1MSP.admin', 'Org1MSP.client')"
            Admins:
                Type: Signature
                Rule: "OR('Org1MSP.admin')"
            Endorsement:
                Type: Signature
                Rule: "OR('Org1MSP.peer')"

    - &Org2
        Name: Org2MSP
        ID: Org2MSP
        MSPDir: ../organizations/peerOrganizations/org2.example.com/msp
        AnchorPeers:
            - Host: peer0.org2.example.com
              Port: 9051
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('Org2MSP.admin', 'Org2MSP.peer', 'Org2MSP.client')"
            Writers:
                Type: Signature
                Rule: "OR('Org2MSP.admin', 'Org2MSP.client')"
            Admins:
                Type: Signature
                Rule: "OR('Org2MSP.admin')"
            Endorsement:
                Type: Signature
                Rule: "OR('Org2MSP.peer')"

Capabilities:
    Channel: &ChannelCapabilities
        V2_0: true
    Orderer: &OrdererCapabilities
        V2_0: true
    Application: &ApplicationCapabilities
        V2_0: true

Application: &ApplicationDefaults
    Organizations:
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
        LifecycleEndorsement:
            Type: ImplicitMeta
            Rule: "MAJORITY Endorsement"
        Endorsement:
            Type: ImplicitMeta
            Rule: "MAJORITY Endorsement"
    Capabilities:
        <<: *ApplicationCapabilities

Orderer: &OrdererDefaults
    OrdererType: etcdraft
    Addresses:
        - orderer.example.com:7050
    BatchTimeout: 2s
    BatchSize:
        MaxMessageCount: 10
        AbsoluteMaxBytes: 99 MB
        PreferredMaxBytes: 512 KB
    Organizations:
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
        BlockValidation:
            Type: ImplicitMeta
            Rule: "ANY Writers"
    EtcdRaft:
        Consenters:
            - Host: orderer.example.com
              Port: 7050
              ClientTLSCert: ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
              ServerTLSCert: ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt

Channel: &ChannelDefaults
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
    Capabilities:
        <<: *ChannelCapabilities

Profiles:
    TwoOrgsOrdererGenesis:
        <<: *ChannelDefaults
        Orderer:
            <<: *OrdererDefaults
            Organizations:
                - *OrdererOrg
            Capabilities:
                <<: *OrdererCapabilities
        Consortiums:
            SampleConsortium:
                Organizations:
                    - *Org1
                    - *Org2
    TwoOrgsChannel:
        Consortium: SampleConsortium
        <<: *ChannelDefaults
        Application:
            <<: *ApplicationDefaults
            Organizations:
                - *Org1
                - *Org2
            Capabilities:
                <<: *ApplicationCapabilities
EOF

# Crear script para generar los certificados
echo -e "${YELLOW}Creando script de generación de certificados...${NC}"
cat > scripts/generateCerts.sh << 'EOF'
#!/bin/bash

# Usar misma ruta de binarios que el script principal
if [ -d "../bin" ]; then
    export PATH=$PATH:$PWD/../bin
elif [ -d "$HOME/fabric-samples/bin" ]; then
    export PATH=$PATH:$HOME/fabric-samples/bin
fi

# Limpiar certificados anteriores
rm -rf organizations/ordererOrganizations
rm -rf organizations/peerOrganizations

# Generar certificados usando cryptogen
echo "Generando certificados con cryptogen..."
cryptogen generate --config=./config/crypto-config.yaml --output="organizations"

# Verificar que se hayan creado correctamente
if [ ! -d "organizations/ordererOrganizations" ] || [ ! -d "organizations/peerOrganizations" ]; then
    echo "Error al generar los certificados."
    exit 1
fi

echo "Certificados generados con éxito."
EOF
chmod +x scripts/generateCerts.sh

# Crear configuración para cryptogen
echo -e "${YELLOW}Creando configuración para cryptogen...${NC}"
cat > config/crypto-config.yaml << 'EOF'
OrdererOrgs:
  - Name: Orderer
    Domain: example.com
    EnableNodeOUs: true
    Specs:
      - Hostname: orderer
        SANS:
          - localhost
          - 127.0.0.1

PeerOrgs:
  - Name: Org1
    Domain: org1.example.com
    EnableNodeOUs: true
    Template:
      Count: 2
      SANS:
        - localhost
        - 127.0.0.1
    Users:
      Count: 1
  - Name: Org2
    Domain: org2.example.com
    EnableNodeOUs: true
    Template:
      Count: 2
      SANS:
        - localhost
        - 127.0.0.1
    Users:
      Count: 1
EOF

# Crear script para generar el bloque génesis y los artefactos del canal
echo -e "${YELLOW}Creando script para generar artefactos...${NC}"
cat > scripts/generateChannelArtifacts.sh << 'EOF'
#!/bin/bash

# Usar misma ruta de binarios que el script principal
if [ -d "../bin" ]; then
    export PATH=$PATH:$PWD/../bin
elif [ -d "$HOME/fabric-samples/bin" ]; then
    export PATH=$PATH:$HOME/fabric-samples/bin
fi

# Asegurarse que FABRIC_CFG_PATH apunta a configtx
export FABRIC_CFG_PATH=$PWD/configtx

echo "Generando bloque génesis..."
configtxgen -profile TwoOrgsOrdererGenesis -channelID system-channel -outputBlock ./channel-artifacts/genesis.block

echo "Generando transacción del canal..."
configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID mychannel

echo "Generando transacciones de anclaje para Org1..."
configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID mychannel -asOrg Org1MSP

echo "Generando transacciones de anclaje para Org2..."
configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID mychannel -asOrg Org2MSP

echo "Artefactos generados con éxito."
EOF
chmod +x scripts/generateChannelArtifacts.sh

# Crear core.yaml
echo -e "${YELLOW}Creando core.yaml...${NC}"
cat > config/core.yaml << 'EOF'
peer:
    id: peer0.org1.example.com
    networkId: dev
    listenAddress: 0.0.0.0:7051
    address: 0.0.0.0:7051
    addressAutoDetect: false
    keepalive:
        minInterval: 60s
        client:
            interval: 60s
            timeout: 20s
        deliveryClient:
            interval: 60s
            timeout: 20s
    gossip:
        bootstrap: peer0.org1.example.com:7051
        useLeaderElection: true
        orgLeader: false
        membershipTrackerInterval: 5s
        endpoint:
        maxBlockCountToStore: 100
        maxPropagationBurstLatency: 10ms
        maxPropagationBurstSize: 10
        propagateIterations: 1
        propagatePeerNum: 3
        pullInterval: 4s
        pullPeerNum: 3
        requestStateInfoInterval: 4s
        publishStateInfoInterval: 4s
        stateInfoRetentionInterval:
        publishCertPeriod: 10s
        skipBlockVerification: false
        dialTimeout: 3s
        connTimeout: 2s
        recvBuffSize: 20
        sendBuffSize: 200
        digestWaitTime: 1s
        requestWaitTime: 1s
        responseWaitTime: 2s
        aliveTimeInterval: 5s
        aliveExpirationTimeout: 25s
        reconnectInterval: 25s
        maxConnectionAttempts: 120
        msgExpirationFactor: 20
        externalEndpoint:
    events:
        address: 0.0.0.0:7053
        buffersize: 100
        timeout: 10ms
        timewindow: 15m
        keepalive:
            minInterval: 60s
    tls:
        enabled: true
        clientAuthRequired: false
        cert:
            file: /etc/hyperledger/fabric/tls/server.crt
        key:
            file: /etc/hyperledger/fabric/tls/server.key
        rootcert:
            file: /etc/hyperledger/fabric/tls/ca.crt
        clientRootCAs:
            files:
              - /etc/hyperledger/fabric/tls/ca.crt
    authentication:
        timewindow: 15m
    chaincode:
        builder: $(DOCKER_NS)/fabric-ccenv:$(TWO_DIGIT_VERSION)
        pull: false
        golang:
            runtime: $(DOCKER_NS)/fabric-baseos:$(TWO_DIGIT_VERSION)
EOF

# Crear orderer.yaml
echo -e "${YELLOW}Creando orderer.yaml...${NC}"
cat > config/orderer.yaml << 'EOF'
General:
    ListenAddress: 0.0.0.0
    ListenPort: 7050
    TLS:
        Enabled: true
        PrivateKey: /var/hyperledger/orderer/tls/server.key
        Certificate: /var/hyperledger/orderer/tls/server.crt
        RootCAs:
          - /var/hyperledger/orderer/tls/ca.crt
        ClientAuthRequired: false
    Keepalive:
        ServerMinInterval: 60s
        ServerInterval: 7200s
        ServerTimeout: 20s
    LogLevel: INFO
    LogFormat: '%{color}%{time:2006-01-02 15:04:05.000 MST} [%{module}] %{shortfunc} -> %{level:.4s} %{id:03x}%{color:reset} %{message}'
    GenesisMethod: file
    GenesisFile: /var/hyperledger/orderer/orderer.genesis.block
    LocalMSPDir: /var/hyperledger/orderer/msp
    LocalMSPID: OrdererMSP
    Profile:
        Enabled: false
        Address: 0.0.0.0:6060
    BCCSP:
        Default: SW
        SW:
            Hash: SHA2
            Security: 256
            FileKeyStore:
                KeyStore:
    Operations:
        ListenAddress: 0.0.0.0:9443
EOF

# Generar certificados
echo -e "${YELLOW}Generando certificados...${NC}"
./scripts/generateCerts.sh
if [ $? -ne 0 ]; then
    echo -e "${RED}Error al generar certificados${NC}"
    exit 1
fi

# Generar artefactos del canal
echo -e "${YELLOW}Generando artefactos del canal...${NC}"
./scripts/generateChannelArtifacts.sh
if [ $? -ne 0 ]; then
    echo -e "${RED}Error al generar artefactos del canal${NC}"
    exit 1
fi

# Verificar que todo se generó correctamente
if [ ! -d "organizations/ordererOrganizations" ] || [ ! -d "organizations/peerOrganizations" ]; then
    echo -e "${RED}Error: Certificados no generados correctamente${NC}"
    exit 1
fi

if [ ! -f "channel-artifacts/genesis.block" ] || [ ! -f "channel-artifacts/channel.tx" ]; then
    echo -e "${RED}Error: Artefactos del canal no generados correctamente${NC}"
    exit 1
fi

echo -e "${GREEN}Setup completado con éxito${NC}"
echo -e "${YELLOW}Ahora puedes ejecutar:${NC}"
echo -e "${GREEN}./startNetwork.sh${NC}"