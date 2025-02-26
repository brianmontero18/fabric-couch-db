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
