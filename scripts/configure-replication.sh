#!/bin/bash
set -e

# FreshBox - Configuracion automatica de replicacion MariaDB
# Se ejecuta desde la instancia SECONDARY.

PRIMARY_IP="$1"
DB_PASSWORD="$2"
REPLICATION_PASSWORD="$3"

if [ -z "$PRIMARY_IP" ]; then
  echo "ERROR: Debes indicar la IP privada de la PRIMARY."
  echo "Uso: ./configure-replication.sh <PRIMARY_IP>"
  exit 1
fi

echo "=== Configurando replicacion FreshBox ==="
echo "PRIMARY: $PRIMARY_IP"

# Esperar hasta que MariaDB PRIMARY este disponible
echo "Esperando PRIMARY..."

until mariadb -h "$PRIMARY_IP" \
  -u replicator -p"$REPLICATION_PASSWORD" \
  -e "SELECT 1;" >/dev/null 2>&1
do
  echo "PRIMARY aun no disponible. Reintentando..."
  sleep 10
done

echo "PRIMARY disponible."

# Obtener posicion actual del Binary Log
MASTER_STATUS=$(mariadb -h "$PRIMARY_IP" \
  -u replicator -p"$REPLICATION_PASSWORD" \
  -N -e "SHOW MASTER STATUS;")

MASTER_FILE=$(echo "$MASTER_STATUS" | awk '{print $1}')
MASTER_POS=$(echo "$MASTER_STATUS" | awk '{print $2}')

if [ -z "$MASTER_FILE" ] || [ -z "$MASTER_POS" ]; then
  echo "ERROR: No se pudo obtener MASTER_FILE o MASTER_POS."
  exit 1
fi

echo "Binary Log: $MASTER_FILE"
echo "Position: $MASTER_POS"

# Copiar la base FreshBox desde PRIMARY hacia SECONDARY
echo "Copiando base FreshBox..."

sudo mariadb -e "SET GLOBAL read_only=OFF;"

mariadb-dump \
  -h "$PRIMARY_IP" \
  -u alumno -p"$DB_PASSWORD" \
  --single-transaction \
  freshbox |
sudo mariadb freshbox

# Configurar replicacion
sudo mariadb <<SQL
STOP SLAVE;

CHANGE MASTER TO
  MASTER_HOST='$PRIMARY_IP',
  MASTER_USER='replicator',
  MASTER_PASSWORD='$REPLICATION_PASSWORD',
  MASTER_LOG_FILE='$MASTER_FILE',
  MASTER_LOG_POS=$MASTER_POS;

SET GLOBAL read_only=ON;

START SLAVE;
SQL

sleep 5

echo ""
echo "=== Estado de replicacion ==="

sudo mariadb -e "SHOW SLAVE STATUS\G" |
grep -E "Slave_IO_Running:|Slave_SQL_Running:|Seconds_Behind_Master:"

echo ""
echo "=== Replicacion FreshBox configurada ==="

