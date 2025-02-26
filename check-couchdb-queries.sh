# Verificar si la interfaz web de CouchDB está funcionando
function check_web_interface() {
  local port=$1
  echo "Verificando interfaz web en puerto $port..."
  curl -s -I http://localhost:$port/_utils | head -n 1
}

# Verificar la información básica de la base de datos
function check_db_info() {
  local port=$1
  echo "Obteniendo información de la base de datos en puerto $port..."
  curl -s -u admin:adminpw http://localhost:$port/_all_dbs
}

# Ejecutar una consulta rica en CouchDB directamente
function run_rich_query() {
  local port=$1
  local db=$2
  local query=$3
  echo "Ejecutando consulta enriquecida en la base de datos $db..."
  curl -s -u admin:adminpw \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$query" \
    http://localhost:$port/$db/_find
}

# Verificar todas las instancias de CouchDB
echo "== Verificando todas las instancias de CouchDB =="
check_web_interface 5984
check_web_interface 6984
check_web_interface 7984
check_web_interface 8984

# Verificar bases de datos en peer0.org1
echo -e "\n== Verificando bases de datos en peer0.org1 =="
check_db_info 5984

# Ejecutar una consulta enriquecida de ejemplo
echo -e "\n== Ejecutando consulta enriquecida de ejemplo =="
# Primero debemos identificar el nombre exacto de la base de datos del canal+chaincode
CHANNEL_DB=$(curl -s -u admin:adminpw http://localhost:5984/_all_dbs | grep mychannel | grep asset-transfer)

if [ ! -z "$CHANNEL_DB" ]; then
  echo "Base de datos del chaincode encontrada: $CHANNEL_DB"
  # Consulta para encontrar vehículos con valor entre 300 y 800
  QUERY='{
    "selector": {
      "Type": "Vehicle",
      "AppraisedValue": {
        "$gte": 300,
        "$lte": 800
      }
    },
    "sort": [{"AppraisedValue": "desc"}]
  }'
  
  run_rich_query 5984 "$CHANNEL_DB" "$QUERY"
else
  echo "No se encontró la base de datos del chaincode"
fi

echo -e "\n== Verificación completa =="