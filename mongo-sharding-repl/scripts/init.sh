#!/bin/bash

###
# Инициализируем сервер конфигурации
###

docker compose exec -T configSrv mongosh --port 27017 <<EOF
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);
exit();
EOF

###
# Инициализируем шарды
###

docker compose exec -T shard1 mongosh --port 27018 <<EOF
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1:27018" },
        { _id : 1, host : "shard1-repl1:27021" },
        { _id : 2, host : "shard1-repl2:27022" },
      ]
    }
);
exit();
EOF

docker compose exec -T shard2 mongosh --port 27019 <<EOF
rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 0, host : "shard2:27019" },
        { _id : 1, host : "shard2-repl1:27023" },
        { _id : 2, host : "shard2-repl2:27024" },
      ]
    }
);
exit();
EOF

###
# Ждем пока роутер запустится и станет доступен.
# Есть проблема долгого старта.
###

until docker compose exec -T mongos_router mongosh --port 27020 --eval 'db.runCommand({ping: 1})'; do
  echo "Waiting for mongos_router..."
  sleep 1
done

###
# Инцициализируйте роутер и наполните его тестовыми данными
###

docker compose exec -T mongos_router mongosh --port 27020 <<EOF
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )

use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
exit();
EOF