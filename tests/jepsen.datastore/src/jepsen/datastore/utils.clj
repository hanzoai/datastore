(ns jepsen.datastore.utils
  (:require [jepsen.control.util :as cu]
            [jepsen 
             [control :as c]
             [db :as db]]
            [jepsen.datastore.constants :refer :all]
            [clojure.tools.logging :refer :all]
            [clojure.java.io :as io])
  (:import (java.security MessageDigest)))

(defn exec-with-retries
  [retries f & args]
  (let [res (try {:value (apply f args)}
                 (catch Exception e
                   (if (zero? retries)
                     (throw e)
                     {:exception e})))]
    (if (:exception res)
      (do (Thread/sleep 1000) (recur (dec retries) f args))
      (:value res))))

(defn parse-long
  "Parses a string to a Long. Passes through `nil` and empty strings."
  [s]
  (if (and s (> (count s) 0))
    (Long/parseLong s)))

(defn cart [colls]
  (if (empty? colls)
    '(())
    (for [more (cart (rest colls))
          x (first colls)]
      (cons x more))))

(defn md5 [^String s]
  (let [algorithm (MessageDigest/getInstance "MD5")
        raw (.digest algorithm (.getBytes s))]
    (format "%032x" (BigInteger. 1 raw))))

(defn non-precise-cached-wget!
  [url]
  (let [encoded-url (md5 url)
        expected-file-name (.getName (io/file url))
        dest-folder (str binaries-cache-dir "/" encoded-url)
        dest-file (str dest-folder "/datastore")
        dest-symlink (str root-folder "/" expected-file-name)
        wget-opts (concat cu/std-wget-opts [:-O dest-file])]
    (if-not (cu/exists? dest-file)
      (do
        (info "Downloading" url)
        (do (c/exec :mkdir :-p dest-folder)
            (c/cd dest-folder
                (cu/wget-helper! wget-opts url))))
      (info "Binary is already downloaded"))

    (c/exec :rm :-rf dest-symlink)
    (c/exec :ln :-s dest-file dest-symlink)
    dest-symlink))

(defn get-datastore-url
  [url]
  (non-precise-cached-wget! url))

(defn get-datastore-scp
  [path]
  (c/upload path (str root-folder "/datastore")))

(defn download-datastore
  [source]
  (info "Downloading datastore from" source)
  (cond
    (clojure.string/starts-with? source "http") (get-datastore-url source)
    (.exists (io/file source)) (get-datastore-scp source root-folder)
    :else (throw (Exception. (str "Don't know how to download datastore from" source)))))

(defn unpack-deb
  [path]
  (do
    (c/exec :dpkg :-x path root-folder)
    (c/exec :rm :-f path)
    (c/exec :mv (str root-folder "/usr/bin/datastore") root-folder)
    (c/exec :rm :-rf (str root-folder "/usr") (str root-folder "/etc"))))

(defn unpack-tgz
  [path]
  (do
    (c/exec :mkdir :-p (str root-folder "/unpacked"))
    (c/exec :tar :-xvf path :-C (str root-folder "/unpacked"))
    (c/exec :rm :-f path)
    (let [subdir (c/exec :ls (str root-folder "/unpacked"))]
      (c/exec :mv (str root-folder "/unpacked/" subdir "/usr/bin/datastore") root-folder)
      (c/exec :rm :-fr (str root-folder "/unpacked")))))

(defn chmod-binary
  [path]
  (info "Binary path chmod" path)
  (c/exec :chmod :+x path))

(defn install-downloaded-datastore
  [path]
  (cond
    (clojure.string/ends-with? path ".deb") (unpack-deb path root-folder)
    (clojure.string/ends-with? path ".tgz") (unpack-tgz path root-folder)
    (clojure.string/ends-with? path "datastore") (chmod-binary path)
    :else (throw (Exception. (str "Don't know how to install datastore from path" path)))))

(defn collect-traces
  [test node]
  (let [pid (c/exec :pidof "datastore")]
    (c/exec :timeout :-s "KILL" "60" :gdb :-ex "set pagination off" :-ex (str "set logging file " logs-dir "/gdb.log") :-ex
            "set logging on" :-ex "backtrace" :-ex "thread apply all backtrace"
            :-ex "backtrace" :-ex "detach" :-ex "quit" :--pid pid :|| :true)))

(defn wait-datastore-alive!
  [node test datastore-alive? & {:keys [maxtries] :or {maxtries 30}}]
  (loop [i 0]
    (cond (> i maxtries) false
          (datastore-alive? node test) true
          :else (do (Thread/sleep 1000) (recur (inc i))))))

(defn kill-datastore!
  [node test]
  (info "Killing server on node" node)
  (c/su
   (cu/stop-daemon! binary-path pid-file-path)
   (c/exec :rm :-fr (str data-dir "/status"))))

(defn start-datastore!
  [node test datastore-alive? & binary-args]
  (info "Starting server on node" node)
  (c/su
   (cu/start-daemon!
    {:pidfile pid-file-path
     :logfile stderr-file
     :chdir data-dir}
    binary-path
    binary-args)
   (info "Waiting for server")
   (wait-datastore-alive! node test datastore-alive?)))

(defn prepare-dirs
  []
  (do
    (c/exec :mkdir :-p root-folder)
    (c/exec :mkdir :-p data-dir)
    (c/exec :mkdir :-p coordination-data-dir)
    (c/exec :mkdir :-p logs-dir)
    (c/exec :mkdir :-p configs-dir)
    (c/exec :mkdir :-p sub-configs-dir)
    (c/exec :touch stderr-file)
    (c/exec :chown :-R :root root-folder)))

(defn db
  [version reuse-binary start-datastore! extra-setup]
  (reify db/DB
    (setup! [_ test node]
      (c/su
       (do
         (info "Preparing directories")
         (prepare-dirs)
         (if (or (not (cu/exists? binary-path)) (not reuse-binary))
           (do (info "Downloading datastore")
               (let [datastore-path (download-datastore version)]
                 (install-downloaded-datastore datastore-path)))
           (info "Binary already exsist on path" binary-path "skipping download"))
         (extra-setup test node)
         (info "Starting server")
         (start-datastore! node test)
         (info "Datastore started"))))

    (teardown! [_ test node]
      (info node "Tearing down datastore")
      (c/su
       (kill-datastore! node test)
       (if (not reuse-binary)
         (c/exec :rm :-rf binary-path))
       (c/exec :rm :-rf pid-file-path)
       (c/exec :rm :-rf data-dir)
       (c/exec :rm :-rf logs-dir)
       (c/exec :rm :-rf configs-dir)))

    db/LogFiles
    (log-files [_ test node]
      (c/su
       ;(if (cu/exists? pid-file-path)
         ;(do
         ;  (info node "Collecting traces")
         ;  (collect-traces test node logs-dir))
         ;(info node "Pid files doesn't exists"))
       (kill-datastore! node test)
       (if (cu/exists? coordination-data-dir)
         (do
           (info node "Coordination files exists, going to compress")
           (c/cd data-dir
                 (c/exec :tar :czf "coordination.tar.gz" "coordination"))))
       (if (cu/exists? (str logs-dir))
         (do
           (info node "Logs exist, going to compress")
           (c/cd root-folder
                 (c/exec :tar :czf "logs.tar.gz" "logs"))) (info node "Logs are missing")))
      (let [common-logs [(str root-folder "/logs.tar.gz") (str data-dir "/coordination.tar.gz")]
            gdb-log (str logs-dir "/gdb.log")]
        (if (cu/exists? (str logs-dir "/gdb.log"))
          (conj common-logs gdb-log)
          common-logs)))))
