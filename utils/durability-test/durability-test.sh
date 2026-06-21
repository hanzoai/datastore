#!/bin/bash

: '
A simple test for durability. It starts up datastore server in qemu VM and runs
inserts via datastore benchmark tool. Then it kills VM in random moment and
checks whether table contains broken parts. With enabled fsync no broken parts
should be appeared.

Usage:

./install.sh
./durability-test.sh <table name> <file with create query> <file with insert query>
'

URL=http://cloud-images.ubuntu.com/bionic/current
IMAGE=bionic-server-cloudimg-amd64.img
SSH_PORT=11022
PASSWORD=root

TABLE_NAME=$1
CREATE_QUERY=$2
INSERT_QUERY=$3

if [[ -z $TABLE_NAME || -z $CREATE_QUERY || -z $INSERT_QUERY ]]; then
    echo "Required 3 arguments: table name, file with create query, file with insert query"
    exit 1
fi

function run()
{
    sshpass -p $PASSWORD ssh -p $SSH_PORT root@localhost "$1" 2>/dev/null
}

function copy()
{
    sshpass -p $PASSWORD scp -r -P $SSH_PORT "$1" "root@localhost:$2" 2>/dev/null
}

function wait_vm_for_start()
{
    echo "Waiting until VM started..."
    started=0
    for _ in {0..100}; do
        if run "exit"; then
            started=1
            break
        fi
        sleep 1s
    done

    if ((started == 0)); then
        echo "Can't start or connect to VM."
        exit 1
    fi

    echo "Started VM"
}

function wait_clickhouse_for_start()
{
    echo "Waiting until Datastore started..."
    started=0
    for _ in {0..30}; do
        if run "datastore client --query 'select 1'" > /dev/null; then
            started=1
            break
        fi
        sleep 1s
    done

    if ((started == 0)); then
        echo "Can't start Datastore."
    fi

    echo "Started Datastore"
}

echo "Downloading image"
curl -O $URL/$IMAGE

qemu-img resize $IMAGE +10G
virt-customize -a $IMAGE --root-password password:$PASSWORD > /dev/null 2>&1
virt-copy-in -a $IMAGE sshd_config /etc/ssh

echo "Starting VM"

chmod +x ./startup.exp
./startup.exp > qemu.log 2>&1 &

wait_vm_for_start

echo "Preparing VM"

# Resize partition
run "growpart /dev/sda 1 && resize2fs /dev/sda1"

if [[ -z $DATASTORE_BINARY ]]; then
    DATASTORE_BINARY=/usr/bin/datastore
fi

if [[ -z $DATASTORE_CONFIG_DIR ]]; then
    DATASTORE_CONFIG_DIR=/etc/datastore-server
fi

echo "Using Datastore binary: $DATASTORE_BINARY"
echo "Using Datastore config from: $DATASTORE_CONFIG_DIR"

copy "$DATASTORE_BINARY" /usr/bin
copy "$DATASTORE_CONFIG_DIR" /etc
run "mv /etc/$DATASTORE_CONFIG_DIR /etc/datastore-server"

echo "Prepared VM"
echo "Starting Datastore"

run "datastore server --config-file=/etc/datastore-server/config.xml > datastore-server.log 2>&1" &
wait_clickhouse_for_start

query=$(cat "$CREATE_QUERY")
echo "Executing query: $query"
run "datastore client --query '$query'"

query=$(cat "$INSERT_QUERY")
echo "Will run in a loop query:  $query"
run "datastore benchmark <<< '$query' -c 8" &
echo "Running queries"

pid=$(pidof qemu-system-x86_64)
sec=$(( (RANDOM % 5) + 25 ))
ms=$(( RANDOM % 1000 ))

echo "Will kill VM in $sec.$ms sec"

sleep $sec.$ms
kill -9 "$pid"

echo "Restarting"

sleep 5s

./startup.exp > qemu.log 2>&1 &
wait_vm_for_start

run "rm -r *data/system"
run "datastore server --config-file=/etc/datastore-server/config.xml > datastore-server.log 2>&1" &
wait_clickhouse_for_start

pid=$(pidof qemu-system-x86_64)
result=$(run "grep $TABLE_NAME datastore-server.log | grep 'Caught exception while loading metadata'")
if [[ -n $result ]]; then
    echo "FAIL. Can't attach table:"
    echo "$result"
    kill -9 "$pid"
    exit 1
fi

result=$(run "grep $TABLE_NAME datastore-server.log | grep 'Considering to remove broken part'")
if [[ -n $result ]]; then
    echo "FAIL. Have broken parts:"
    echo "$result"
    kill -9 "$pid"
    exit 1
fi

kill -9 "$pid"
echo OK
