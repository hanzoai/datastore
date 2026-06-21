(ns jepsen.datastore.server.utils
  (:require [jepsen.datastore.utils :as chu]
            [jepsen.datastore.constants :refer :all]
            [jepsen.datastore.server.client :as chc]
            [clojure.tools.logging :refer :all]
            [clojure.java.jdbc :as jdbc]))

(defn datastore-alive?
  [node test]
  (try
    (let [c (chc/open-connection node)]
      (jdbc/query c "SELECT 1")
      (chc/close-connection c))
    (catch Exception e false)))

(defn start-datastore!
  [node test]
  (chu/start-datastore!
    node
    test
    datastore-alive?
    :server
    :--config (str configs-dir "/config.xml")
    :--
    :--logger.log (str logs-dir "/datastore.log")
    :--logger.errorlog (str logs-dir "/datastore.err.log")
    :--path data-dir))
