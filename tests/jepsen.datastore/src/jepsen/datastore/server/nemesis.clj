(ns jepsen.datastore.server.nemesis
  (:require [jepsen.datastore.nemesis :as chnem]
            [jepsen.datastore.server.utils :refer :all]
            [jepsen.nemesis :as nemesis]))

(def custom-nemeses
  {"random-node-killer" {:nemesis (chnem/random-node-killer-nemesis start-datastore!)
                         :generator (chnem/start-stop-generator 5 5)}
   "all-nodes-killer" {:nemesis (chnem/all-nodes-killer-nemesis start-datastore!)
                       :generator (chnem/start-stop-generator 1 10)}
   "simple-partitioner" {:nemesis (nemesis/partition-random-halves)
                         :generator (chnem/start-stop-generator 5 5)}
   "random-node-hammer-time"    {:nemesis (chnem/random-node-hammer-time-nemesis)
                                 :generator (chnem/start-stop-generator 5 5)}
   "all-nodes-hammer-time"    {:nemesis (chnem/all-nodes-hammer-time-nemesis)
                               :generator (chnem/start-stop-generator 1 10)}
   "bridge-partitioner" {:nemesis (chnem/partition-bridge-nemesis)
                         :generator (chnem/start-stop-generator 5 5)}
   "blind-node-partitioner" {:nemesis (chnem/blind-node-partition-nemesis)
                             :generator (chnem/start-stop-generator 5 5)}
   "blind-others-partitioner" {:nemesis (chnem/blind-others-partition-nemesis)
                               :generator (chnem/start-stop-generator 5 5)}})
