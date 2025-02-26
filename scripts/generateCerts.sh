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
