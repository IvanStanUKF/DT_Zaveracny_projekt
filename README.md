# **DT_Zaveracny_projekt**
Záverečný projekt z predmetu Databázové technológie, Autori: Ivan Stančiak, Maksym Kuryk

Tento repozitár predstavuje implementáciu ELT procesu v Snowflake a vytvorenie dátového skladu so schémou Star Schema. Projekt pracuje s **Credit/Debit Transactions: Fast Food and Quick Service Restaurants** datasetom. Projekt sa zameriava na preskúmanie uskutočnených transakcií.

---
## **1. Úvod a popis zdrojových dát**
V tomto projekte analyzujeme dáta o transakciách, zákazníkoch a obhcodníkoch. Cieľom je porozumieť:
- kde sa transakcie uskutočňujú,
- kedy sa transakcie uskutočňujú,
- v akom množstve sa transakcie uskutočnujú,
- popularite a tržbám obchodníkov,
- transakciám zákazníkov.
  
Zdrojové dáta pochádzajú zo Snowflake marketplace datasetu dostupného [tu](https://app.snowflake.com/marketplace/listing/GZSTZ708I0X/facteus-credit-debit-transactions-fast-food-and-quick-service-restaurants?search=fast%20food). Dataset obsahuje jednu hlavnú tabuľku:
- `QSR_TRANSACTIONS_SAMPLE` - dáta o transakciách (v našej databáze sme to pomenovali `raw_data`)

Účelom ELT procesu bolo tieto dáta pripraviť, transformovať a sprístupniť pre analýzu.

---
### **1.1 Dátová architektúra**

### **ERD diagram**
Surové dáta sú usporiadané v relačnom modeli, ktorý je znázornený na **entitno-relačnom diagrame (ERD)**:

<p align="center">
  <img src="https://github.com/IvanStanUKF/DT_Zaveracny_projekt/blob/main/img/erd_diagram.png" alt="ERD Schema">
  <br>
  <em>Obrázok 1 Entitno-relačná schéma Credit/Debit Transactions: Fast Food and Quick Service Restaurants</em>
</p>

---
## **2 Dimenzionálny model**

V ukážke bola navrhnutá **schéma hviezdy (star schema)** podľa Kimballovej metodológie, ktorá obsahuje 1 tabuľku faktov **`fact_transaction`**, ktorá je prepojená s nasledujúcimi 4 dimenziami:
- **`dim_card`**: Obsahuje podrobné údaje o kartách a ich vlastníkoch (číslo karty, typ karty, id účtu, generácia a vek držiteľa karty).
- **`dim_merchant`**: Obsahuje podrobné údaje o obchodníkoch (názov obchodníka, lokácia prevádzky, kategórie).
- **`dim_date`**: Zahrňuje informácie o dátumoch hodnotení (dátum, deň, deň v týždni, mesiac, rok).
- **`dim_time`**: Obsahuje podrobné časové údaje (čas, hodina, minúta, sekunda).

Štruktúra hviezdicového modelu je znázornená na diagrame nižšie. Diagram ukazuje prepojenia medzi faktovou tabuľkou a dimenziami, čo zjednodušuje pochopenie a implementáciu modelu.

<p align="center">
  <img src="https://github.com/IvanStanUKF/DT_Zaveracny_projekt/blob/main/img/star_shema.png" alt="Star Schema">
  <br>
  <em>Obrázok 2 Schéma hviezdy pre Credit/Debit Transactions: Fast Food and Quick Service Restaurants</em>
</p>

---
## **3. ELT proces v Snowflake**
ETL proces pozostáva z troch hlavných fáz: `extrahovanie` (Extract), `načítanie` (Load) a `transformácia` (Transform). Tento proces bol implementovaný v Snowflake s cieľom pripraviť zdrojové dáta zo staging vrstvy do viacdimenzionálneho modelu vhodného na analýzu a vizualizáciu.

---
### **3.1 Extract (Extrahovanie dát)**
Dáta zo zdrojového datasetu (nachádzajúceho sa na Snowflake marketplace) boli najprv nahraté do Snowflake prostredníctvom Snowflake marketplace (cez tlačidlo Get). Kontrola extrahovania údajov a vytvorenie schémy projektu bolo zabezpečené príkazmi:

#### Príklad kódu:
```sql
USE WAREHOUSE SPIDER_WH;
USE DATABASE CREDITDEBIT_TRANSACTIONS_FAST_FOOD_AND_QUICK_SERVICE_RESTAURANTS;
USE SCHEMA CREDITDEBIT_TRANSACTIONS_FAST_FOOD_AND_QUICK_SERVICE_RESTAURANTS.SNOWFLAKE_MARKETPLACE;

/* Kontrola Extrahovania údajov */
SELECT * FROM QSR_TRANSACTIONS_SAMPLE LIMIT 100;
DESCRIBE TABLE QSR_TRANSACTIONS_SAMPLE;

/* Vytvorenie schémy projektu */
USE DATABASE SPIDER_DB;
CREATE OR REPLACE SCHEMA SPIDER_DB.ZAVERECNY_PROJEKT;
USE SCHEMA SPIDER_DB.ZAVERECNY_PROJEKT;
```

---
### **3.2 Load (Načítanie dát)**

Následne boli tieto dáta nahrané do našej vlastnej databázy (tabuľka: raw_data) a následne skontrolované nasledujúcimi príkazmi:

#### Príklad kódu:
```sql
/* ELT - Load */
CREATE OR REPLACE TABLE raw_data AS
SELECT * FROM CREDITDEBIT_TRANSACTIONS_FAST_FOOD_AND_QUICK_SERVICE_RESTAURANTS.SNOWFLAKE_MARKETPLACE.QSR_TRANSACTIONS_SAMPLE;

SELECT * FROM raw_data LIMIT 100;
DESCRIBE TABLE raw_data;
```

---
### **3.3 Transform (Transformácia dát)**

V tejto fáze boli dáta z pôvodnej tabuľky vyčistené a transformované. Hlavným cieľom bolo pripraviť dimenzie a faktovú tabuľku, ktoré umožnia jednoduchú a efektívnu analýzu. Dimenzie boli navrhnuté na poskytovanie kontextu pre faktovú tabuľku. 

`dim_card` obsahuje podrobné údaje o kartách a ich vlastníkoch (číslo karty, typ karty, id účtu, generácia a vek držiteľa karty). Transformácia zahŕňala získanie jedinečných riadkov pre každú kartu. Táto dimenzia je `typu SCD 0`, čiže neumožňuje sledovať historické zmeny v údajoch o karte a vlastníkovi karty.

#### Príklad kódu:
```sql
/* ELT - Transform */

// dim_card
CREATE OR REPLACE TABLE dim_card AS (
SELECT
    ROW_NUMBER() OVER (ORDER BY card_id ASC) AS dim_cardId,
    card_id AS card_number,
    card_type AS card_type,
    account_id AS account_id,
    card_holder_generation AS cardholder_generation,
    card_holder_vintage AS cardholder_age
FROM (
    SELECT DISTINCT 
        card_id, 
        card_type,
        account_id,
        card_holder_generation,
        card_holder_vintage
    FROM raw_data
    )
ORDER BY dim_cardId
);

-- Kontrola
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT dim_cardId) AS distinct_values FROM dim_card;
SELECT * FROM dim_card ORDER BY dim_cardId ASC LIMIT 100;
DESCRIBE TABLE dim_card;
```

Podobne `dim_merchant` obsahuje podrobné údaje o obchodníkoch (názov obchodníka, lokácia prevádzky, kategórie). Táto dimenzia je `typu SCD 0`, čiže neumožňuje sledovať historické zmeny v údajoch o obchodníkoch a prevádzkach. 

#### Príklad kódu:
```sql
// dim_merchant
CREATE OR REPLACE TABLE dim_merchant AS (
SELECT
    ROW_NUMBER() OVER (ORDER BY merchant_id, merchant_store_id) AS dim_merchantId,
    merchant_id AS merchant_number,
    merchant_name AS merchant_name,
    merchant_store_id AS store_id,
    merchant_store_location AS store_location,
    merchant_store_address AS store_address,
    merchant_category_level_1 AS category1,
    merchant_category_level_2 AS category2,
    merchant_category_level_3 AS category3
FROM (
    SELECT DISTINCT 
        merchant_id, 
        merchant_name,
        merchant_store_id, 
        merchant_store_location,
        merchant_store_address, 
        merchant_category_level_1,
        merchant_category_level_2, 
        merchant_category_level_3
    FROM raw_data
    )
ORDER BY dim_merchantId
);

-- Kontrola
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT dim_merchantId) AS distinct_values FROM dim_merchant;
SELECT * FROM dim_merchant ORDER BY dim_merchantid ASC LIMIT 100;
DESCRIBE TABLE dim_merchant;
```

Dimenzia `dim_date` je navrhnutá tak, aby uchovávala informácie o dátumoch uskutočnenia transakcií. Obsahuje odvodené údaje, ako sú deň, deň v týždni, mesiac, rok. Táto dimenzia je štruktúrovaná tak, aby umožňovala podrobné dátumové analýzy, ako sú počty a sumy transakcií za dni, dni v týždni, mesiace. Z hľadiska SCD je táto dimenzia klasifikovaná ako `SCD Typ 0`. To znamená, že existujúce záznamy v tejto dimenzii sú nemenné a uchovávajú statické informácie.

Dimenzia `dim_time` je navrhnutá tak, aby uchovávala informácie o časoch uskutočnenia transakcií. Obsahuje odvodené údaje, ako sú hodina, minúta, sekunda. Táto dimenzia je štruktúrovaná tak, aby umožňovala podrobné časové analýzy, ako sú počty a sumy transakcií za danú hodinu, minútu, sekundu. Z hľadiska SCD je táto dimenzia klasifikovaná ako `SCD Typ 0`. To znamená, že existujúce záznamy v tejto dimenzii sú nemenné a uchovávajú statické informácie.

#### Príklad kódu:
```sql
// dim_time
CREATE OR REPLACE TABLE dim_time AS (
SELECT
    ROW_NUMBER() OVER (ORDER BY time_distinct ASC) AS dim_timeId,
    time_distinct AS time,
    HOUR(time_distinct) AS hour,
    MINUTE(time_distinct) AS minute,
    SECOND(time_distinct) AS second
FROM (
    SELECT DISTINCT 
        TIME(transaction_date)::TIME(0) AS time_distinct
    FROM raw_data
    )
ORDER BY dim_timeId
);

-- Kontrola
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT dim_timeId) AS distinct_values FROM dim_time;
SELECT * FROM dim_time ORDER BY dim_timeId ASC LIMIT 100;
DESCRIBE TABLE dim_time;



// dim_date
CREATE OR REPLACE TABLE dim_date AS (
SELECT
    ROW_NUMBER() OVER (ORDER BY date_distinct ASC) AS dim_dateId,
    date_distinct AS date,
    DAY(date_distinct) AS day,
    DAYOFWEEKISO(date_distinct) AS weekday,
    CASE DAYOFWEEKISO(date_distinct)
        WHEN 1 THEN 'Pondelok'
        WHEN 2 THEN 'Utorok'
        WHEN 3 THEN 'Streda'
        WHEN 4 THEN 'Štvrtok'
        WHEN 5 THEN 'Piatok'
        WHEN 6 THEN 'Sobota'
        WHEN 7 THEN 'Nedeľa'
    END AS weekday_name,
    MONTH(date_distinct) AS month,
    CASE MONTH(date_distinct)
        WHEN 1 THEN 'Január'
        WHEN 2 THEN 'Február'
        WHEN 3 THEN 'Marec'
        WHEN 4 THEN 'Apríl'
        WHEN 5 THEN 'Máj'
        WHEN 6 THEN 'Jún'
        WHEN 7 THEN 'Júl'
        WHEN 8 THEN 'August'
        WHEN 9 THEN 'September'
        WHEN 10 THEN 'Október'
        WHEN 11 THEN 'November'
        WHEN 12 THEN 'December'
    END AS month_name,
    YEAR(date_distinct) AS year
FROM (
    SELECT DISTINCT 
        DATE(transaction_date) AS date_distinct
    FROM raw_data
    )
ORDER BY dim_dateId
);

-- Kontrola
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT dim_dateId) AS distinct_values FROM dim_date;
SELECT * FROM dim_date ORDER BY dim_dateId ASC;
DESCRIBE TABLE dim_date;
```

Faktová tabuľka `fact_transaction` obsahuje záznamy o transakciách a prepojenia na všetky dimenzie. Obsahuje kľúčové metriky, ako je číslo transakcie, suma transakcie, typ transakcie, miesto transakciel, atď.

#### Príklad kódu:
```sql
// fact_transaction
UPDATE dim_merchant
SET store_id = '-1'
WHERE store_id IS NULL;

CREATE OR REPLACE TABLE fact_transaction AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY rd.transaction_id) AS fact_transactionId,                           -- Vytvorenie jedinečnej hodnoty pre PK
        c.dim_cardId AS cardId,                                                                         -- CK pre PK tabuľky dim_card
        m.dim_merchantId AS merchantId,                                                                 -- CK pre PK tabuľky dim_merchant
        d.dim_dateId AS dateId,                                                                         -- CK pre PK tabuľky dim_date
        t.dim_timeId AS timeId,                                                                         -- CK pre PK tabuľky dim_time
        rd.transaction_id AS transaction_number,
        rd.gross_transaction_amount AS transaction_amount,
        rd.transaction_type AS transaction_type,
        rd.currency_code AS currency_code,
        rd.transaction_city AS city,
        rd.transaction_state AS state,
        rd.transaction_postal_code AS postal_code,
        rd.transaction_msa AS msa,
        rd.transaction_description AS description,
        COUNT(*) OVER (PARTITION BY c.dim_cardId) AS transaction_count,                                 -- Window funkcia pre zistenie počtu transakcií na kartu
        SUM(rd.gross_transaction_amount) OVER (PARTITION BY c.dim_cardId) AS total_spend_by_card,       -- Window funkcia pre zistenie sumy všetkých transakcií na kartu
        AVG(rd.gross_transaction_amount) OVER (PARTITION BY c.dim_cardId) AS average_spend_by_card      -- Window funkcia pre zistenie priemernej výšky transakcií na kartu
    FROM raw_data rd
    INNER JOIN dim_date d ON DATE(rd.transaction_date) = d.date                                         -- Prepojenie na základe dátumu z "transaction_date"
    INNER JOIN dim_time t ON TIME(rd.transaction_date)::TIME(0) = t.time                                -- Prepojenie na základe času z "transaction_date"
    INNER JOIN dim_card c ON rd.card_id = c.card_number                                                 -- Prepojenie na základe čísla karty z "card_id"
    INNER JOIN dim_merchant m ON rd.merchant_id = m.merchant_number AND (rd.merchant_store_id = m.store_id OR (rd.merchant_store_id IS NULL AND m.store_id LIKE '-1'))      -- Prepojenie na základe jedinečnej kombinácie merchant_id a merchant_store_id (NULL hodnota bola prepísaná na '-1' pomocou UPDATE kvôli funkčnosti)
);

-- Kontrola
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT fact_transactionId) AS distinct_values FROM fact_transaction;
SELECT * FROM fact_transaction ORDER BY fact_transactionId ASC;
DESCRIBE TABLE fact_transaction;

SELECT
    transaction_number,
    COUNT(*) AS count
FROM fact_transaction
GROUP BY transaction_number
HAVING COUNT(*) > 1;
```

ELT proces v Snowflake umožnil spracovanie pôvodných dát z pôvodnej tabuľky do viacdimenzionálneho modelu typu hviezda. Tento proces zahŕňal čistenie, obohacovanie a reorganizáciu údajov. Výsledný model umožňuje analýzu ustutočnených transakcií, obchodníkov a zákazníkov.

Po úspešnom vytvorení dimenzií a faktovej tabuľky boli dáta nahraté do finálnej štruktúry. Na záver bola pôvodná tabuľka so surovými dátami (raw_data) odstránená:

#### Príklad kódu:
```sql
// Odstránenie pôvodnej tabuľky
DROP TABLE IF EXISTS raw_data;
```
---

**Autori:** Ivan Stančiak, Maksym Kuryk
