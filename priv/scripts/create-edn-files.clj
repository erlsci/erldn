#!/usr/bin/env clojure -M

;;;; EDN Test File Generator
;;;; Executes the commented code from the edn-format examples
;;;; Creates files in priv/edn directory

(require '[clojure.java.io :as io]
         '[clojure.string :as str])

;; Since we don't have the actual edn-format libraries, we'll create simplified versions
;; that generate valid EDN data for testing the Erlang implementation

(defn ensure-dir [path]
  (let [dir (io/file path)]
    (when-not (.exists dir)
      (.mkdirs dir))))

(defn write-edn-file [path data]
  (ensure-dir "priv/edn")
  (with-open [writer (io/writer (str "priv/edn/" path))]
    (binding [*out* writer]
      (if (coll? data)
        (doseq [item data]
          (prn item))
        (prn data)))))

;; Simple data generators to replace the missing libraries
(defn gen-int []
  (- (rand-int 2000) 1000))

(defn gen-float []
  (- (* (rand) 2000.0) 1000.0))

(defn gen-ratio []
  (let [num (inc (rand-int 100))
        den (inc (rand-int 100))]
    (symbol (str num "/" den))))

(defn gen-number []
  (case (rand-int 4)
    0 (gen-int)
    1 (gen-float)
    2 (gen-ratio)
    3 (if (< (rand) 0.5) 
        (symbol (str (gen-int) "N"))  ; BigInt
        (symbol (str (gen-float) "M"))))) ; BigDecimal

(defn gen-keyword []
  (keyword (str "key" (rand-int 1000))))

(defn gen-namespaced-keyword []
  (keyword (str "ns" (rand-int 10)) (str "key" (rand-int 100))))

(defn gen-any-keyword []
  (if (< (rand) 0.3)
    (gen-namespaced-keyword)
    (gen-keyword)))

(defn gen-symbol []
  (symbol (str "sym" (rand-int 1000))))

(defn gen-string []
  (str "string-" (rand-int 1000)))

(defn gen-char []
  (char (+ 32 (rand-int 95))))

(defn gen-boolean []
  (< (rand) 0.5))

(defn gen-nil []
  nil)

(defn gen-uuid []
  (java.util.UUID/randomUUID))

(defn gen-instant []
  (str (java.time.Instant/now)))

(defn gen-instant-tagged []
  (str "#inst \"" (gen-instant) "\""))

(defn gen-uuid-tagged []
  (str "#uuid \"" (gen-uuid) "\""))

(defn gen-scalar []
  (case (rand-int 8)
    0 (gen-int)
    1 (gen-float)
    2 (gen-keyword)
    3 (gen-symbol)
    4 (gen-string)
    5 (gen-char)
    6 (gen-boolean)
    7 (gen-nil)))

(defn gen-list [gen n]
  (repeatedly n gen))

(defn gen-vector [gen n]
  (vec (repeatedly n gen)))

(defn gen-set [gen n]
  (set (repeatedly (* n 2) gen)))  ; Generate more to account for duplicates

(defn gen-map [key-gen val-gen n]
  (into {} (repeatedly n #(vector (key-gen) (val-gen)))))

(defn gen-mixed-collection []
  (case (rand-int 4)
    0 (gen-list gen-scalar (rand-int 10))
    1 (gen-vector gen-scalar (rand-int 10))
    2 (gen-set gen-scalar (rand-int 8))
    3 (gen-map gen-keyword gen-scalar (rand-int 8))))

(defn gen-hierarchical [depth max-depth]
  (if (or (zero? depth) (< (rand) 0.3))
    (gen-scalar)
    (case (rand-int 4)
      0 (gen-list #(gen-hierarchical (dec depth) max-depth) (inc (rand-int 5)))
      1 (gen-vector #(gen-hierarchical (dec depth) max-depth) (inc (rand-int 5)))
      2 (gen-set #(gen-hierarchical (dec depth) max-depth) (inc (rand-int 4)))
      3 (gen-map gen-keyword #(gen-hierarchical (dec depth) max-depth) (inc (rand-int 4))))))

(defn gen-tagged-element []
  (let [tag (symbol (str "myapp/Tag" (rand-int 10)))
        data (gen-mixed-collection)]
    (list tag data)))

(defn gen-comment []
  (str "; Comment " (rand-int 1000)))

(defn write-file-of-many [gen n filename]
  (println (str "Creating " filename " with " n " items..."))
  (let [data (repeatedly n gen)]
    (write-edn-file filename data)))

(defn write-single-file [data filename]
  (println (str "Creating " filename "..."))
  (write-edn-file filename data))

;; Execute the examples from the commented code
(defn -main [& args]
  (println "Creating EDN test files in priv/edn directory...")
  (println "=" (apply str (repeat 50 "=")))
  
  ;; Basic type files
  (write-file-of-many gen-int 100 "ints.edn")
  (write-file-of-many gen-float 100 "floats.edn")
  (write-file-of-many gen-number 100 "numbers.edn")
  (write-file-of-many gen-any-keyword 100 "keywords.edn")
  
  ;; Hierarchical data with newline separation
  (ensure-dir "priv/edn")
  (with-open [writer (io/writer "priv/edn/hierarchical.edn")]
    (binding [*out* writer]
      (dotimes [_ 10]
        (prn (gen-hierarchical 3 3))
        (println))))
  
  ;; Date/time types - write as raw strings since they're tagged elements
  (ensure-dir "priv/edn")
  (with-open [writer (io/writer "priv/edn/instants.edn")]
    (binding [*out* writer]
      (dotimes [_ 10]
        (println (gen-instant-tagged)))))
  
  (with-open [writer (io/writer "priv/edn/uuids.edn")]
    (binding [*out* writer]
      (dotimes [_ 10]
        (println (gen-uuid-tagged)))))
  
  ;; Files with comments (simulated)
  (ensure-dir "priv/edn")
  (with-open [writer (io/writer "priv/edn/ints-with-comments.edn")]
    (binding [*out* writer]
      (dotimes [_ 100]
        (when (< (rand) 0.2)
          (println (gen-comment)))
        (prn (gen-int)))))
  
  ;; Files with newlines
  (with-open [writer (io/writer "priv/edn/ints-with-newline.edn")]
    (binding [*out* writer]
      (dotimes [_ 100]
        (prn (gen-int))
        (println))))
  
  ;; Single collection files
  (write-single-file (gen-list gen-int 100) "list-of-ints.edn")
  
  ;; File with discard elements
  (ensure-dir "priv/edn")
  (with-open [writer (io/writer "priv/edn/ints-with-discard.edn")]
    (binding [*out* writer]
      (let [ints (gen-list gen-int 100)]
        (doseq [int-val ints]
          (when (< (rand) 0.1)
            (print "#_ ")
            (prn (gen-scalar)))
          (prn int-val)))))
  
  ;; Noisy file with various EDN elements
  (with-open [writer (io/writer "priv/edn/ints-with-noise.edn")]
    (binding [*out* writer]
      (let [ints (gen-list gen-int 100)]
        (doseq [int-val ints]
          ; Random comments
          (when (< (rand) 0.05)
            (println (gen-comment)))
          ; Random whitespace
          (when (< (rand) 0.1)
            (println))
          ; Random tagged elements  
          (when (< (rand) 0.05)
            (print "#custom/tag ")
            (prn (gen-scalar)))
          ; Random discard
          (when (< (rand) 0.05)
            (print "#_ ")
            (prn (gen-scalar)))
          (prn int-val)))))
  
  ;; Complex data structures
  (write-file-of-many #(gen-hierarchical 4 4) 20 "complex-hierarchical.edn")
  
  ;; Mixed type collections
  (write-single-file (gen-map gen-any-keyword gen-mixed-collection 50) "mixed-map.edn")
  (write-single-file (gen-set gen-scalar 30) "mixed-set.edn")
  (write-single-file (gen-vector #(gen-hierarchical 2 2) 25) "mixed-vector.edn")
  
  ;; Character literals
  (write-file-of-many gen-char 50 "characters.edn")
  
  ;; Special character literals - write as raw strings to file
  (ensure-dir "priv/edn")
  (with-open [writer (io/writer "priv/edn/special-chars.edn")]
    (binding [*out* writer]
      (println "\\newline")
      (println "\\return") 
      (println "\\space")
      (println "\\tab")
      (println "\\c")
      (println "\\A")
      (println "\\9")))
  
  ;; Boolean and nil values
  (write-file-of-many #(if (< (rand) 0.5) (gen-boolean) (gen-nil)) 50 "booleans-nils.edn")
  
  ;; Symbols with various formats
  (write-file-of-many #(case (rand-int 4)
                         0 (gen-symbol)
                         1 (symbol (str "ns" (rand-int 5)) (str "name" (rand-int 10)))
                         2 (symbol "/")
                         3 (symbol (str "+" (rand-int 100))))
                       50 "symbols.edn")
  
  ;; Edge cases
  (write-single-file [0 -0 +42 -42 0.0 -0.0 Double/POSITIVE_INFINITY Double/NEGATIVE_INFINITY Double/NaN] "edge-numbers.edn")
  
  (println "=" (apply str (repeat 50 "=")))
  (println "EDN test files created successfully in priv/edn/")
  (println "Files created:")
  (doseq [file (sort (.list (io/file "priv/edn")))]
    (println (str "  - " file))))

;; Execute when run as script
(-main)