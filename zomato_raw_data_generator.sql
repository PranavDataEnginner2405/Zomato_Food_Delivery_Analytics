-- ============================================================
-- ZOMATO RAW DATA GENERATOR (Snowflake) - single script, run top to bottom
-- Scale (adjust the numbers if you want more / fewer rows):
--   customers 1M | restaurants 50K | menu items 1M | delivery partners 100K
--   orders 5M (5 batches x 1M) | order items ~12.5M | payments 5M ...
-- All IDs are derived so that every foreign key matches.
-- ============================================================

CREATE DATABASE IF NOT EXISTS RAW;
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE DBT_WH;
USE DATABASE RAW;
ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS = 86400;

-- Optional (uses more credits, but much faster). Scale back to XSMALL when done.
-- ALTER WAREHOUSE DBT_WH SET WAREHOUSE_SIZE = 'MEDIUM';

CREATE SCHEMA IF NOT EXISTS RAW.ZOMATO_CUSTOMERS;
CREATE SCHEMA IF NOT EXISTS RAW.ZOMATO_TRANSACTIONAL;
CREATE SCHEMA IF NOT EXISTS RAW.ZOMATO_PAYMENTS;
CREATE SCHEMA IF NOT EXISTS RAW.ZOMATO_DELIVERY;
CREATE SCHEMA IF NOT EXISTS RAW.ZOMATO_ENGAGEMENT;
CREATE SCHEMA IF NOT EXISTS RAW.ZOMATO_GEOGRAPHY;
CREATE SCHEMA IF NOT EXISTS RAW.ZOMATO_RESTAURANTS;
CREATE SCHEMA IF NOT EXISTS RAW.ZOMATO_PROMOTIONS;
CREATE SCHEMA IF NOT EXISTS RAW.ZOMATO_SUPPORT;

-- NOTE: In Snowflake RANDOM() returns a huge integer, NOT a 0-1 number.
-- So every probability check below uses UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()).

-- ============================================================
-- STEP 1: TABLES
-- ============================================================

CREATE OR REPLACE TABLE RAW.ZOMATO_GEOGRAPHY.CITIES (
    city_id VARCHAR(10) NOT NULL, city_name VARCHAR(100) NOT NULL, state VARCHAR(100) NOT NULL,
    tier VARCHAR(5) NOT NULL, is_metro BOOLEAN NOT NULL, is_active BOOLEAN NOT NULL,
    launch_date DATE, _fivetran_synced TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_GEOGRAPHY.AREAS (
    area_id VARCHAR(20) NOT NULL, city_id VARCHAR(10) NOT NULL, area_name VARCHAR(200) NOT NULL,
    pin_code VARCHAR(10) NOT NULL, _fivetran_synced TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_RESTAURANTS.RESTAURANTS (
    restaurant_id VARCHAR(20) NOT NULL, restaurant_name VARCHAR(300) NOT NULL, city_id VARCHAR(10) NOT NULL,
    area_id VARCHAR(20), cuisine_type VARCHAR(50) NOT NULL, restaurant_tier VARCHAR(20) NOT NULL,
    is_active BOOLEAN NOT NULL, is_verified BOOLEAN NOT NULL, is_purely_vegetarian BOOLEAN NOT NULL,
    average_prep_time_minutes INTEGER, minimum_order_amount NUMBER(10,2), average_cost_for_two NUMBER(10,2),
    commission_rate FLOAT NOT NULL, overall_rating FLOAT, total_ratings_count INTEGER,
    created_at TIMESTAMP_NTZ NOT NULL, updated_at TIMESTAMP_NTZ NOT NULL, _fivetran_synced TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_RESTAURANTS.MENU_ITEMS (
    menu_item_id VARCHAR(20) NOT NULL, restaurant_id VARCHAR(20) NOT NULL, item_name VARCHAR(300) NOT NULL,
    item_category VARCHAR(100) NOT NULL, base_price NUMBER(10,2) NOT NULL, is_vegetarian BOOLEAN NOT NULL,
    is_available BOOLEAN NOT NULL, _fivetran_synced TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_CUSTOMERS.CUSTOMERS (
    customer_id VARCHAR(20) NOT NULL, customer_name VARCHAR(200) NOT NULL, customer_email VARCHAR(300) NOT NULL,
    customer_phone VARCHAR(15) NOT NULL, city_id VARCHAR(10) NOT NULL, acquisition_channel VARCHAR(50) NOT NULL,
    customer_segment VARCHAR(20) NOT NULL, is_active BOOLEAN NOT NULL, is_pro_subscriber BOOLEAN NOT NULL,
    created_at TIMESTAMP_NTZ NOT NULL, last_login_at TIMESTAMP_NTZ, updated_at TIMESTAMP_NTZ NOT NULL,
    _fivetran_synced TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_CUSTOMERS.CUSTOMER_ADDRESSES (
    address_id VARCHAR(20) NOT NULL, customer_id VARCHAR(20) NOT NULL, address_text VARCHAR(500) NOT NULL,
    area_id VARCHAR(20), is_default BOOLEAN NOT NULL, _fivetran_synced TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_DELIVERY.DELIVERY_PARTNERS (
    delivery_partner_id VARCHAR(20) NOT NULL, partner_name VARCHAR(200) NOT NULL, partner_phone VARCHAR(15) NOT NULL,
    vehicle_type VARCHAR(20) NOT NULL, home_city_id VARCHAR(10) NOT NULL, is_verified BOOLEAN NOT NULL,
    is_active BOOLEAN NOT NULL, total_deliveries_completed INTEGER NOT NULL, average_rating FLOAT,
    acceptance_rate FLOAT, onboarded_at TIMESTAMP_NTZ NOT NULL, updated_at TIMESTAMP_NTZ NOT NULL,
    _fivetran_synced TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_DELIVERY.DELIVERIES (
    delivery_id VARCHAR(20) NOT NULL, order_id VARCHAR(20) NOT NULL, delivery_partner_id VARCHAR(20) NOT NULL,
    delivery_status VARCHAR(30) NOT NULL, failure_reason VARCHAR(100), assigned_at TIMESTAMP_NTZ NOT NULL,
    en_route_restaurant_at TIMESTAMP_NTZ, arrived_restaurant_at TIMESTAMP_NTZ, picked_up_at TIMESTAMP_NTZ,
    delivered_at TIMESTAMP_NTZ, delivery_distance_km FLOAT, route_distance_km FLOAT,
    updated_at TIMESTAMP_NTZ NOT NULL, _fivetran_synced TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_TRANSACTIONAL.ORDERS (
    order_id VARCHAR(20) NOT NULL, customer_id VARCHAR(20) NOT NULL, restaurant_id VARCHAR(20) NOT NULL,
    delivery_partner_id VARCHAR(20), city_id VARCHAR(10) NOT NULL, promo_id VARCHAR(20),
    subtotal_amount NUMBER(12,2) NOT NULL, delivery_fee NUMBER(8,2) NOT NULL, platform_fee NUMBER(8,2) NOT NULL,
    promo_discount_amount NUMBER(10,2) NOT NULL, tax_amount NUMBER(10,2) NOT NULL, total_amount NUMBER(12,2) NOT NULL,
    order_status VARCHAR(20) NOT NULL, cancellation_reason VARCHAR(100), is_contactless_delivery BOOLEAN NOT NULL,
    ordered_at TIMESTAMP_NTZ NOT NULL, accepted_at TIMESTAMP_NTZ, prepared_at TIMESTAMP_NTZ,
    picked_up_at TIMESTAMP_NTZ, delivered_at TIMESTAMP_NTZ, cancelled_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ NOT NULL, _fivetran_synced TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_TRANSACTIONAL.ORDER_ITEMS (
    order_item_id VARCHAR(20) NOT NULL, order_id VARCHAR(20) NOT NULL, menu_item_id VARCHAR(20) NOT NULL,
    restaurant_id VARCHAR(20) NOT NULL, item_name VARCHAR(300) NOT NULL, item_category VARCHAR(100) NOT NULL,
    is_vegetarian BOOLEAN NOT NULL, quantity INTEGER NOT NULL, unit_price NUMBER(10,2) NOT NULL,
    customization_price_delta NUMBER(8,2) NOT NULL, created_at TIMESTAMP_NTZ NOT NULL,
    _fivetran_synced TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_PAYMENTS.PAYMENT_METHODS (
    payment_method_id VARCHAR(20) NOT NULL, payment_method_name VARCHAR(50) NOT NULL,
    payment_method_group VARCHAR(20) NOT NULL, gateway_fee_rate FLOAT NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_PAYMENTS.PAYMENTS (
    payment_id VARCHAR(20) NOT NULL, order_id VARCHAR(20) NOT NULL, payment_status VARCHAR(20) NOT NULL,
    payment_method VARCHAR(50) NOT NULL, payment_amount NUMBER(12,2) NOT NULL, gateway_fee NUMBER(8,2) NOT NULL,
    paid_at TIMESTAMP_NTZ, settlement_date DATE, _loaded_at TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_ENGAGEMENT.RATINGS (
    rating_id VARCHAR(20) NOT NULL, order_id VARCHAR(20) NOT NULL, customer_id VARCHAR(20) NOT NULL,
    restaurant_id VARCHAR(20) NOT NULL, delivery_partner_id VARCHAR(20), food_rating INTEGER NOT NULL,
    delivery_rating INTEGER NOT NULL, overall_rating FLOAT NOT NULL, rated_at TIMESTAMP_NTZ NOT NULL,
    _airbyte_extracted_at TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_ENGAGEMENT.REVIEWS (
    review_id VARCHAR(20) NOT NULL, rating_id VARCHAR(20) NOT NULL, review_text VARCHAR(2000),
    sentiment_label VARCHAR(10), submitted_at TIMESTAMP_NTZ NOT NULL, _airbyte_extracted_at TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_PROMOTIONS.PROMOTIONS (
    promo_id VARCHAR(20) NOT NULL, promo_code VARCHAR(50) NOT NULL, promo_name VARCHAR(200) NOT NULL,
    promo_description VARCHAR(500), discount_type VARCHAR(20) NOT NULL, discount_value NUMBER(10,2) NOT NULL,
    promo_funder VARCHAR(20) NOT NULL, min_order_value NUMBER(10,2), max_redemptions INTEGER,
    max_redemptions_per_customer INTEGER, is_new_customer_only BOOLEAN NOT NULL, eligible_cuisine_types VARIANT,
    valid_from DATE NOT NULL, valid_to DATE NOT NULL, is_active BOOLEAN NOT NULL,
    updated_at TIMESTAMP_NTZ NOT NULL, _fivetran_synced TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_PROMOTIONS.PROMO_REDEMPTIONS (
    redemption_id VARCHAR(20) NOT NULL, order_id VARCHAR(20) NOT NULL, promo_id VARCHAR(20) NOT NULL,
    customer_id VARCHAR(20) NOT NULL, discount_amount_applied NUMBER(10,2) NOT NULL,
    redemption_status VARCHAR(20) NOT NULL, failure_reason VARCHAR(200), redeemed_at TIMESTAMP_NTZ NOT NULL,
    _fivetran_synced TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_SUPPORT.SUPPORT_TICKETS (
    ticket_id VARCHAR(20) NOT NULL, customer_id VARCHAR(20) NOT NULL, order_id VARCHAR(20),
    assigned_agent_id VARCHAR(20), ticket_category VARCHAR(50) NOT NULL, ticket_status VARCHAR(20) NOT NULL,
    priority VARCHAR(10) NOT NULL, resolution_code VARCHAR(50), csat_score INTEGER,
    created_at TIMESTAMP_NTZ NOT NULL, first_response_at TIMESTAMP_NTZ, resolved_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ NOT NULL, _airbyte_extracted_at TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE RAW.ZOMATO_SUPPORT.TICKET_COMMENTS (
    comment_id VARCHAR(20) NOT NULL, ticket_id VARCHAR(20) NOT NULL, commenter_type VARCHAR(10) NOT NULL,
    comment_text VARCHAR(2000), commented_at TIMESTAMP_NTZ NOT NULL, _airbyte_extracted_at TIMESTAMP_NTZ NOT NULL
);

-- ============================================================
-- STEP 2: REFERENCE DATA
-- ============================================================

INSERT INTO RAW.ZOMATO_GEOGRAPHY.CITIES VALUES
('1',  'Mumbai',        'Maharashtra',    '1', TRUE,  TRUE, '2015-01-01', CURRENT_TIMESTAMP()),
('2',  'Delhi',         'Delhi',          '1', TRUE,  TRUE, '2015-01-01', CURRENT_TIMESTAMP()),
('3',  'Bengaluru',     'Karnataka',      '1', TRUE,  TRUE, '2015-03-01', CURRENT_TIMESTAMP()),
('4',  'Chennai',       'Tamil Nadu',     '1', TRUE,  TRUE, '2015-06-01', CURRENT_TIMESTAMP()),
('5',  'Hyderabad',     'Telangana',      '1', TRUE,  TRUE, '2015-06-01', CURRENT_TIMESTAMP()),
('6',  'Kolkata',       'West Bengal',    '1', TRUE,  TRUE, '2015-09-01', CURRENT_TIMESTAMP()),
('7',  'Pune',          'Maharashtra',    '2', FALSE, TRUE, '2016-01-01', CURRENT_TIMESTAMP()),
('8',  'Ahmedabad',     'Gujarat',        '2', FALSE, TRUE, '2016-04-01', CURRENT_TIMESTAMP()),
('9',  'Jaipur',        'Rajasthan',      '2', FALSE, TRUE, '2016-06-01', CURRENT_TIMESTAMP()),
('10', 'Lucknow',       'Uttar Pradesh',  '2', FALSE, TRUE, '2016-06-01', CURRENT_TIMESTAMP()),
('11', 'Surat',         'Gujarat',        '2', FALSE, TRUE, '2017-01-01', CURRENT_TIMESTAMP()),
('12', 'Nagpur',        'Maharashtra',    '2', FALSE, TRUE, '2017-03-01', CURRENT_TIMESTAMP()),
('13', 'Chandigarh',    'Punjab',         '2', FALSE, TRUE, '2017-06-01', CURRENT_TIMESTAMP()),
('14', 'Coimbatore',    'Tamil Nadu',     '2', FALSE, TRUE, '2017-09-01', CURRENT_TIMESTAMP()),
('15', 'Kochi',         'Kerala',         '2', FALSE, TRUE, '2018-01-01', CURRENT_TIMESTAMP()),
('16', 'Bhubaneswar',   'Odisha',         '3', FALSE, TRUE, '2018-06-01', CURRENT_TIMESTAMP()),
('17', 'Indore',        'Madhya Pradesh', '3', FALSE, TRUE, '2018-06-01', CURRENT_TIMESTAMP()),
('18', 'Visakhapatnam', 'Andhra Pradesh', '3', FALSE, TRUE, '2019-01-01', CURRENT_TIMESTAMP()),
('19', 'Patna',         'Bihar',          '3', FALSE, TRUE, '2019-06-01', CURRENT_TIMESTAMP()),
('20', 'Guwahati',      'Assam',          '3', FALSE, TRUE, '2020-01-01', CURRENT_TIMESTAMP());

-- AREAS: 1,000 areas, exactly 50 per city. city_id matches CITIES ('1'..'20')
INSERT INTO RAW.ZOMATO_GEOGRAPHY.AREAS
SELECT
    'AREA' || LPAD(n::VARCHAR, 6, '0'),
    (MOD(n - 1, 20) + 1)::VARCHAR,
    'Area_' || LPAD(n::VARCHAR, 6, '0'),
    LPAD(UNIFORM(100000, 999999, RANDOM())::VARCHAR, 6, '0'),
    CURRENT_TIMESTAMP()
FROM (SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 1000)));

INSERT INTO RAW.ZOMATO_PAYMENTS.PAYMENT_METHODS VALUES
('PM01', 'upi',              'digital', 0.0050),
('PM02', 'credit_card',      'card',    0.0200),
('PM03', 'debit_card',       'card',    0.0150),
('PM04', 'net_banking',      'digital', 0.0100),
('PM05', 'wallet',           'digital', 0.0075),
('PM06', 'cash_on_delivery', 'cash',    0.0000),
('PM07', 'emi',              'credit',  0.0250),
('PM08', 'pay_later',        'credit',  0.0300),
('PM09', 'phonepe',          'digital', 0.0050),
('PM10', 'amazon_pay',       'digital', 0.0060);

-- PROMOTIONS: 10,000 rows (orders reference PRO00000001 .. PRO00010000)
INSERT INTO RAW.ZOMATO_PROMOTIONS.PROMOTIONS
WITH p AS (
    SELECT
        SEQ4() + 1                                           AS n,
        UNIFORM(1, 3, RANDOM())                              AS dtype,
        DATEADD(DAY, UNIFORM(0, 1460, RANDOM()), '2020-01-01'::DATE) AS vfrom
    FROM TABLE(GENERATOR(ROWCOUNT => 10000))
)
SELECT
    'PRO'  || LPAD(n::VARCHAR, 8, '0'),
    'CODE' || LPAD(n::VARCHAR, 8, '0'),
    'Promotion ' || n::VARCHAR,
    'Auto-generated promotion ' || n::VARCHAR,
    CASE dtype WHEN 1 THEN 'percentage' WHEN 2 THEN 'flat' ELSE 'free_delivery' END,
    CASE dtype WHEN 1 THEN UNIFORM(10, 50, RANDOM())
               WHEN 2 THEN UNIFORM(20, 200, RANDOM())
               ELSE 0 END::NUMBER(10,2),
    IFF(UNIFORM(1, 2, RANDOM()) = 1, 'zomato', 'restaurant'),
    UNIFORM(0, 300, RANDOM())::NUMBER(10,2),
    UNIFORM(100, 100000, RANDOM()),
    UNIFORM(1, 5, RANDOM()),
    UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.20,
    PARSE_JSON('null'),
    vfrom,
    DATEADD(DAY, UNIFORM(30, 180, RANDOM()), vfrom),
    UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.70,
    DATEADD(SECOND, UNIFORM(0, 126144000, RANDOM()), '2020-01-01'::TIMESTAMP_NTZ),
    CURRENT_TIMESTAMP()
FROM p;

-- ============================================================
-- STEP 3: RESTAURANTS (50,000) and MENU_ITEMS (20 per restaurant = 1,000,000)
-- Restaurant city/area are derived from the id so they always agree with AREAS.
-- ============================================================

INSERT INTO RAW.ZOMATO_RESTAURANTS.RESTAURANTS
SELECT
    'RST' || LPAD(n::VARCHAR, 8, '0'),
    'Restaurant_' || LPAD(n::VARCHAR, 8, '0'),
    (MOD(n - 1, 20) + 1)::VARCHAR,
    'AREA' || LPAD((MOD(n - 1, 1000) + 1)::VARCHAR, 6, '0'),
    CASE UNIFORM(1, 14, RANDOM())
        WHEN 1 THEN 'north_indian' WHEN 2 THEN 'south_indian' WHEN 3 THEN 'chinese'
        WHEN 4 THEN 'fast_food'    WHEN 5 THEN 'pizza'        WHEN 6 THEN 'biryani'
        WHEN 7 THEN 'desserts'     WHEN 8 THEN 'beverages'    WHEN 9 THEN 'continental'
        WHEN 10 THEN 'mughlai'     WHEN 11 THEN 'thai'        WHEN 12 THEN 'italian'
        WHEN 13 THEN 'mexican'     ELSE 'other' END,
    CASE UNIFORM(1, 4, RANDOM()) WHEN 1 THEN 'platinum' WHEN 2 THEN 'gold' WHEN 3 THEN 'silver' ELSE 'bronze' END,
    UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.92,
    UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.85,
    UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.15,
    UNIFORM(10, 60, RANDOM()),
    UNIFORM(50, 300, RANDOM())::NUMBER(10,2),
    UNIFORM(200, 1500, RANDOM())::NUMBER(10,2),
    CASE UNIFORM(1, 4, RANDOM()) WHEN 1 THEN 0.25 WHEN 2 THEN 0.22 WHEN 3 THEN 0.20 ELSE 0.18 END,
    ROUND(LEAST(5, GREATEST(1, NORMAL(4.0, 0.6, RANDOM()))), 1),
    UNIFORM(0, 50000, RANDOM()),
    DATEADD(SECOND, UNIFORM(0, 157680000, RANDOM()), '2015-01-01'::TIMESTAMP_NTZ),
    DATEADD(SECOND, UNIFORM(0, 126144000, RANDOM()), '2020-01-01'::TIMESTAMP_NTZ),
    CURRENT_TIMESTAMP()
FROM (SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 50000)));

-- MENU_ITEMS: menu_item number = (restaurant_num - 1) * 20 + k  (k = 1..20)
INSERT INTO RAW.ZOMATO_RESTAURANTS.MENU_ITEMS
SELECT
    'MI'  || LPAD(m::VARCHAR, 10, '0'),
    'RST' || LPAD((FLOOR((m - 1) / 20) + 1)::VARCHAR, 8, '0'),
    'Item_' || LPAD(m::VARCHAR, 10, '0'),
    CASE MOD(ABS(HASH(m)), 10)
        WHEN 0 THEN 'Starter' WHEN 1 THEN 'Main Course' WHEN 2 THEN 'Dessert' WHEN 3 THEN 'Beverage'
        WHEN 4 THEN 'Snack'   WHEN 5 THEN 'Bread'       WHEN 6 THEN 'Rice'    WHEN 7 THEN 'Combo'
        WHEN 8 THEN 'Salad'   ELSE 'Soup' END,
    (50 + MOD(ABS(HASH(m, 1)), 750))::NUMBER(10,2),
    MOD(ABS(HASH(m, 2)), 100) < 45,
    UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.95,
    CURRENT_TIMESTAMP()
FROM (SELECT SEQ4() + 1 AS m FROM TABLE(GENERATOR(ROWCOUNT => 1000000)));

-- ============================================================
-- STEP 4: CUSTOMERS (1,000,000) and ADDRESSES (2,000,000)
-- ============================================================

INSERT INTO RAW.ZOMATO_CUSTOMERS.CUSTOMERS
SELECT
    'C' || LPAD(n::VARCHAR, 10, '0'),
    'Customer_' || LPAD(n::VARCHAR, 10, '0'),
    'user' || n::VARCHAR || '@example.com',
    '+91' || LPAD(UNIFORM(7000000000, 9999999999, RANDOM())::VARCHAR, 10, '0'),
    UNIFORM(1, 20, RANDOM())::VARCHAR,
    CASE UNIFORM(1, 6, RANDOM()) WHEN 1 THEN 'organic' WHEN 2 THEN 'paid_social' WHEN 3 THEN 'referral'
         WHEN 4 THEN 'promo' WHEN 5 THEN 'app_store' ELSE 'unknown' END,
    CASE UNIFORM(1, 4, RANDOM()) WHEN 1 THEN 'premium' WHEN 2 THEN 'regular' WHEN 3 THEN 'occasional' ELSE 'new' END,
    UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.88,
    UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.25,
    DATEADD(SECOND, UNIFORM(0, 157680000, RANDOM()), '2015-01-01'::TIMESTAMP_NTZ),
    DATEADD(SECOND, UNIFORM(0, 31536000, RANDOM()), '2024-01-01'::TIMESTAMP_NTZ),
    DATEADD(SECOND, UNIFORM(0, 126144000, RANDOM()), '2020-01-01'::TIMESTAMP_NTZ),
    CURRENT_TIMESTAMP()
FROM (SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 1000000)));

-- First 1M rows = default address, next 1M rows = secondary address
INSERT INTO RAW.ZOMATO_CUSTOMERS.CUSTOMER_ADDRESSES
SELECT
    'ADDR' || LPAD(n::VARCHAR, 12, '0'),
    'C' || LPAD((MOD(n - 1, 1000000) + 1)::VARCHAR, 10, '0'),
    'House ' || UNIFORM(1, 999, RANDOM())::VARCHAR || ', Block ' || CHR(UNIFORM(65, 90, RANDOM()))
        || ', Locality ' || LPAD(UNIFORM(1, 1000, RANDOM())::VARCHAR, 4, '0'),
    'AREA' || LPAD(UNIFORM(1, 1000, RANDOM())::VARCHAR, 6, '0'),
    n <= 1000000,
    CURRENT_TIMESTAMP()
FROM (SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 2000000)));

-- ============================================================
-- STEP 5: DELIVERY PARTNERS (100,000)
-- ============================================================

INSERT INTO RAW.ZOMATO_DELIVERY.DELIVERY_PARTNERS
SELECT
    'DP' || LPAD(n::VARCHAR, 9, '0'),
    'Partner_' || LPAD(n::VARCHAR, 9, '0'),
    '+91' || LPAD(UNIFORM(7000000000, 9999999999, RANDOM())::VARCHAR, 10, '0'),
    CASE UNIFORM(1, 4, RANDOM()) WHEN 1 THEN 'bicycle' WHEN 2 THEN 'motorcycle' WHEN 3 THEN 'scooter' ELSE 'car' END,
    UNIFORM(1, 20, RANDOM())::VARCHAR,
    UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.90,
    UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.85,
    UNIFORM(0, 10000, RANDOM()),
    ROUND(LEAST(5, GREATEST(1, NORMAL(4.1, 0.5, RANDOM()))), 2),
    ROUND(UNIFORM(0.60::FLOAT, 0.98::FLOAT, RANDOM()), 3),
    DATEADD(SECOND, UNIFORM(0, 157680000, RANDOM()), '2015-01-01'::TIMESTAMP_NTZ),
    DATEADD(SECOND, UNIFORM(0, 126144000, RANDOM()), '2020-01-01'::TIMESTAMP_NTZ),
    CURRENT_TIMESTAMP()
FROM (SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 100000)));

-- ============================================================
-- STEP 6: ORDERS (5,000,000 = 5 batches x 1,000,000)
-- To make it bigger: raise total_batches (each batch = 1M orders).
-- ============================================================

EXECUTE IMMEDIATE $$
DECLARE
    batch_size    INTEGER DEFAULT 1000000;
    total_batches INTEGER DEFAULT 5;
    offset_val    INTEGER;
BEGIN
    FOR i IN 0 TO total_batches - 1 DO
        offset_val := i * batch_size;

        INSERT INTO RAW.ZOMATO_TRANSACTIONAL.ORDERS
        WITH g AS (
            SELECT
                :offset_val + SEQ4() + 1                      AS n,
                UNIFORM(0::FLOAT, 1::FLOAT, RANDOM())         AS r1,
                UNIFORM(1, 1000000, RANDOM())                 AS cust_num,
                UNIFORM(1, 50000, RANDOM())                   AS rest_num,
                UNIFORM(1, 100000, RANDOM())                  AS dp_num,
                UNIFORM(0, 126144000, RANDOM())               AS sec_offset,
                UNIFORM(50, 2000, RANDOM())                   AS subtotal,
                UNIFORM(0::FLOAT, 1::FLOAT, RANDOM())         AS promo_roll,
                UNIFORM(0.05::FLOAT, 0.30::FLOAT, RANDOM())   AS promo_pct,
                UNIFORM(1, 10000, RANDOM())                   AS promo_num,
                UNIFORM(1, 5, RANDOM())                       AS cancel_roll,
                UNIFORM(0::FLOAT, 1::FLOAT, RANDOM())         AS contactless_roll
            FROM TABLE(GENERATOR(ROWCOUNT => 1000000))
        ),
        s AS (
            SELECT
                n, cust_num, rest_num, dp_num, promo_num, sec_offset, subtotal,
                CASE WHEN r1 < 0.72 THEN 'delivered'
                     WHEN r1 < 0.82 THEN 'cancelled'
                     WHEN r1 < 0.87 THEN 'refunded'
                     WHEN r1 < 0.95 THEN 'out_for_delivery'
                     WHEN r1 < 0.98 THEN 'preparing'
                     ELSE 'accepted' END                                     AS status,
                (promo_roll < 0.20)                                          AS has_promo,
                CASE WHEN subtotal < 150 THEN 40 WHEN subtotal < 500 THEN 30 ELSE 0 END AS dfee,
                ROUND(subtotal * promo_pct, 2)                               AS disc_if_promo,
                ROUND(subtotal * 0.05, 2)                                    AS tax,
                CASE cancel_roll WHEN 1 THEN 'customer_cancelled' WHEN 2 THEN 'restaurant_rejected'
                     WHEN 3 THEN 'no_delivery_partner' WHEN 4 THEN 'payment_failed' ELSE 'other' END AS cancel_reason,
                (contactless_roll < 0.30)                                    AS contactless,
                DATEADD(SECOND, sec_offset, '2020-01-01'::TIMESTAMP_NTZ)     AS ts0
            FROM g
        )
        SELECT
            'ORD' || LPAD(n::VARCHAR, 13, '0'),
            'C'   || LPAD(cust_num::VARCHAR, 10, '0'),
            'RST' || LPAD(rest_num::VARCHAR, 8, '0'),
            CASE WHEN status IN ('cancelled', 'accepted') THEN NULL
                 ELSE 'DP' || LPAD(dp_num::VARCHAR, 9, '0') END,
            (MOD(rest_num - 1, 20) + 1)::VARCHAR,
            CASE WHEN has_promo THEN 'PRO' || LPAD(promo_num::VARCHAR, 8, '0') END,
            subtotal::NUMBER(12,2),
            dfee::NUMBER(8,2),
            5::NUMBER(8,2),
            IFF(has_promo, disc_if_promo, 0)::NUMBER(10,2),
            tax::NUMBER(10,2),
            (subtotal + dfee + 5 - IFF(has_promo, disc_if_promo, 0) + tax)::NUMBER(12,2),
            status,
            IFF(status = 'cancelled', cancel_reason, NULL),
            contactless,
            ts0,
            IFF(status <> 'cancelled', DATEADD(SECOND, UNIFORM(60, 300, RANDOM()), ts0), NULL),
            IFF(status IN ('delivered', 'refunded', 'out_for_delivery'),
                DATEADD(SECOND, UNIFORM(900, 2700, RANDOM()), ts0), NULL),
            IFF(status IN ('delivered', 'refunded', 'out_for_delivery'),
                DATEADD(SECOND, UNIFORM(2100, 3600, RANDOM()), ts0), NULL),
            IFF(status IN ('delivered', 'refunded'),
                DATEADD(SECOND, UNIFORM(3700, 5400, RANDOM()), ts0), NULL),
            IFF(status = 'cancelled', DATEADD(SECOND, UNIFORM(60, 1800, RANDOM()), ts0), NULL),
            DATEADD(SECOND, UNIFORM(5500, 86400, RANDOM()), ts0),
            CURRENT_TIMESTAMP()
        FROM s;
    END FOR;
END;
$$;

-- ============================================================
-- STEP 7: Tables derived from ORDERS (set-based, no loops, ids derived from order_id)
-- ============================================================

-- ORDER_ITEMS: 1-4 items per order, menu item always belongs to the order's restaurant
INSERT INTO RAW.ZOMATO_TRANSACTIONAL.ORDER_ITEMS
SELECT
    'OI' || SUBSTR(o.order_id, 4) || g.k::VARCHAR,
    o.order_id,
    'MI' || LPAD(m.menu_num::VARCHAR, 10, '0'),
    o.restaurant_id,
    'Item_' || LPAD(m.menu_num::VARCHAR, 10, '0'),
    CASE MOD(ABS(HASH(m.menu_num)), 10)
        WHEN 0 THEN 'Starter' WHEN 1 THEN 'Main Course' WHEN 2 THEN 'Dessert' WHEN 3 THEN 'Beverage'
        WHEN 4 THEN 'Snack'   WHEN 5 THEN 'Bread'       WHEN 6 THEN 'Rice'    WHEN 7 THEN 'Combo'
        WHEN 8 THEN 'Salad'   ELSE 'Soup' END,
    MOD(ABS(HASH(m.menu_num, 2)), 100) < 45,
    UNIFORM(1, 5, RANDOM()),
    (50 + MOD(ABS(HASH(m.menu_num, 1)), 750))::NUMBER(10,2),
    IFF(UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.20, UNIFORM(10, 100, RANDOM()), 0)::NUMBER(8,2),
    o.ordered_at,
    CURRENT_TIMESTAMP()
FROM RAW.ZOMATO_TRANSACTIONAL.ORDERS o
JOIN (SELECT SEQ4() + 1 AS k FROM TABLE(GENERATOR(ROWCOUNT => 4))) g
  ON g.k <= 1 + MOD(ABS(HASH(o.order_id)), 4)
CROSS JOIN LATERAL (
    SELECT ((SUBSTR(o.restaurant_id, 4)::INTEGER - 1) * 20 + UNIFORM(1, 20, RANDOM())) AS menu_num
) m;

-- DELIVERIES: for delivered / out_for_delivery / refunded orders
INSERT INTO RAW.ZOMATO_DELIVERY.DELIVERIES
WITH s AS (
    SELECT o.*, UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS fail_roll, UNIFORM(1, 3, RANDOM()) AS fail_pick
    FROM RAW.ZOMATO_TRANSACTIONAL.ORDERS o
    WHERE order_status IN ('delivered', 'out_for_delivery', 'refunded')
)
SELECT
    'DLV' || SUBSTR(order_id, 4),
    order_id,
    COALESCE(delivery_partner_id, 'DP' || LPAD(UNIFORM(1, 100000, RANDOM())::VARCHAR, 9, '0')),
    CASE WHEN order_status = 'out_for_delivery' THEN 'out_for_delivery'
         WHEN fail_roll < 0.03 THEN 'failed'
         ELSE 'delivered' END,
    IFF(order_status <> 'out_for_delivery' AND fail_roll < 0.03,
        CASE fail_pick WHEN 1 THEN 'partner_unavailable' WHEN 2 THEN 'address_not_found' ELSE 'customer_unavailable' END,
        NULL),
    DATEADD(SECOND, UNIFORM(30, 180, RANDOM()), ordered_at),
    DATEADD(SECOND, UNIFORM(181, 480, RANDOM()), ordered_at),
    DATEADD(SECOND, UNIFORM(600, 1800, RANDOM()), ordered_at),
    COALESCE(picked_up_at, DATEADD(SECOND, UNIFORM(1900, 2400, RANDOM()), ordered_at)),
    IFF(order_status = 'out_for_delivery' OR fail_roll < 0.03, NULL,
        COALESCE(delivered_at, DATEADD(SECOND, UNIFORM(2500, 4800, RANDOM()), ordered_at))),
    ROUND(UNIFORM(1.0::FLOAT, 25.0::FLOAT, RANDOM()), 2),
    ROUND(UNIFORM(1.5::FLOAT, 35.0::FLOAT, RANDOM()), 2),
    DATEADD(SECOND, UNIFORM(5000, 90000, RANDOM()), ordered_at),
    CURRENT_TIMESTAMP()
FROM s;

-- PAYMENTS: one payment per order
INSERT INTO RAW.ZOMATO_PAYMENTS.PAYMENTS
WITH s AS (
    SELECT order_id, total_amount, ordered_at, order_status,
           UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS r,
           UNIFORM(1, 10, RANDOM())              AS m,
           UNIFORM(0.005::FLOAT, 0.025::FLOAT, RANDOM()) AS fee_rate,
           UNIFORM(1, 3, RANDOM())               AS settle_days
    FROM RAW.ZOMATO_TRANSACTIONAL.ORDERS
)
SELECT
    'PAY' || SUBSTR(order_id, 4),
    order_id,
    CASE WHEN order_status = 'cancelled' AND r < 0.30 THEN 'failed'
         WHEN order_status IN ('delivered', 'refunded') AND r < 0.02 THEN 'refunded'
         ELSE 'success' END,
    CASE m WHEN 1 THEN 'upi' WHEN 2 THEN 'upi' WHEN 3 THEN 'credit_card' WHEN 4 THEN 'debit_card'
           WHEN 5 THEN 'net_banking' WHEN 6 THEN 'wallet' WHEN 7 THEN 'cash_on_delivery'
           WHEN 8 THEN 'phonepe' WHEN 9 THEN 'amazon_pay' ELSE 'pay_later' END,
    total_amount,
    ROUND(total_amount * fee_rate, 2)::NUMBER(8,2),
    DATEADD(SECOND, UNIFORM(0, 300, RANDOM()), ordered_at),
    DATEADD(DAY, settle_days, ordered_at::DATE),
    CURRENT_TIMESTAMP()
FROM s;

-- RATINGS: ~60% of delivered orders
INSERT INTO RAW.ZOMATO_ENGAGEMENT.RATINGS
WITH s AS (
    SELECT order_id, customer_id, restaurant_id, delivery_partner_id, delivered_at,
           UNIFORM(1, 5, RANDOM()) AS food, UNIFORM(1, 5, RANDOM()) AS deliv
    FROM RAW.ZOMATO_TRANSACTIONAL.ORDERS
    WHERE order_status = 'delivered'
      AND UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.60
)
SELECT
    'RTG' || SUBSTR(order_id, 4), order_id, customer_id, restaurant_id, delivery_partner_id,
    food, deliv, (food + deliv) / 2.0,
    DATEADD(SECOND, UNIFORM(1800, 172800, RANDOM()), delivered_at),
    CURRENT_TIMESTAMP()
FROM s;

-- REVIEWS: ~30% of ratings carry a text review
INSERT INTO RAW.ZOMATO_ENGAGEMENT.REVIEWS
SELECT
    'RVW' || SUBSTR(rating_id, 4),
    rating_id,
    CASE WHEN overall_rating >= 4 THEN 'Great food and quick delivery.'
         WHEN overall_rating >= 3 THEN 'Average experience, okay value.'
         ELSE 'Food was cold and delivery was late.' END,
    CASE WHEN overall_rating >= 4 THEN 'positive' WHEN overall_rating >= 3 THEN 'neutral' ELSE 'negative' END,
    DATEADD(MINUTE, UNIFORM(1, 600, RANDOM()), rated_at),
    CURRENT_TIMESTAMP()
FROM RAW.ZOMATO_ENGAGEMENT.RATINGS
WHERE UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.30;

-- PROMO_REDEMPTIONS: every order that used a promo
INSERT INTO RAW.ZOMATO_PROMOTIONS.PROMO_REDEMPTIONS
WITH s AS (
    SELECT order_id, customer_id, promo_id, promo_discount_amount, ordered_at, order_status,
           (order_status = 'cancelled' AND UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.15) AS failed
    FROM RAW.ZOMATO_TRANSACTIONAL.ORDERS
    WHERE promo_id IS NOT NULL
)
SELECT
    'RDM' || SUBSTR(order_id, 4), order_id, promo_id, customer_id, promo_discount_amount,
    IFF(failed, 'failed', 'success'),
    IFF(failed, 'promo_expired', NULL),
    ordered_at,
    CURRENT_TIMESTAMP()
FROM s;

-- SUPPORT_TICKETS: ~2% of orders
INSERT INTO RAW.ZOMATO_SUPPORT.SUPPORT_TICKETS
SELECT
    'TKT' || SUBSTR(order_id, 4),
    customer_id,
    order_id,
    'AGT' || LPAD(UNIFORM(1, 5000, RANDOM())::VARCHAR, 6, '0'),
    CASE UNIFORM(1, 9, RANDOM())
        WHEN 1 THEN 'missing_item' WHEN 2 THEN 'wrong_item' WHEN 3 THEN 'late_delivery'
        WHEN 4 THEN 'damaged_food' WHEN 5 THEN 'payment_issue' WHEN 6 THEN 'refund_request'
        WHEN 7 THEN 'account_issue' WHEN 8 THEN 'restaurant_complaint' ELSE 'other' END,
    CASE UNIFORM(1, 4, RANDOM()) WHEN 1 THEN 'open' WHEN 2 THEN 'in_progress' WHEN 3 THEN 'resolved' ELSE 'closed' END,
    CASE UNIFORM(1, 3, RANDOM()) WHEN 1 THEN 'high' WHEN 2 THEN 'medium' ELSE 'low' END,
    IFF(UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.80,
        CASE UNIFORM(1, 4, RANDOM()) WHEN 1 THEN 'full_refund' WHEN 2 THEN 'partial_refund'
             WHEN 3 THEN 'replacement_sent' ELSE 'no_action' END, NULL),
    IFF(UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.75, UNIFORM(1, 5, RANDOM()), NULL),
    DATEADD(SECOND, 3600, ordered_at),
    DATEADD(SECOND, UNIFORM(3900, 10800, RANDOM()), ordered_at),
    IFF(UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.80,
        DATEADD(SECOND, UNIFORM(11000, 172800, RANDOM()), ordered_at), NULL),
    DATEADD(SECOND, UNIFORM(11000, 259200, RANDOM()), ordered_at),
    CURRENT_TIMESTAMP()
FROM RAW.ZOMATO_TRANSACTIONAL.ORDERS
WHERE UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.02;

-- TICKET_COMMENTS: one customer comment + one agent reply per ticket
INSERT INTO RAW.ZOMATO_SUPPORT.TICKET_COMMENTS
SELECT
    'CMT' || SUBSTR(t.ticket_id, 4) || g.k::VARCHAR,
    t.ticket_id,
    IFF(g.k = 1, 'customer', 'agent'),
    IFF(g.k = 1, 'I have an issue with my order. Please help.', 'Sorry for the trouble, we are looking into it.'),
    DATEADD(MINUTE, g.k * 15, t.created_at),
    CURRENT_TIMESTAMP()
FROM RAW.ZOMATO_SUPPORT.SUPPORT_TICKETS t
CROSS JOIN (SELECT SEQ4() + 1 AS k FROM TABLE(GENERATOR(ROWCOUNT => 2))) g;

-- ============================================================
-- STEP 8: VERIFICATION
-- ============================================================

SELECT 'CITIES' AS table_name, COUNT(*) AS row_count FROM RAW.ZOMATO_GEOGRAPHY.CITIES
UNION ALL SELECT 'AREAS',              COUNT(*) FROM RAW.ZOMATO_GEOGRAPHY.AREAS
UNION ALL SELECT 'RESTAURANTS',        COUNT(*) FROM RAW.ZOMATO_RESTAURANTS.RESTAURANTS
UNION ALL SELECT 'MENU_ITEMS',         COUNT(*) FROM RAW.ZOMATO_RESTAURANTS.MENU_ITEMS
UNION ALL SELECT 'CUSTOMERS',          COUNT(*) FROM RAW.ZOMATO_CUSTOMERS.CUSTOMERS
UNION ALL SELECT 'CUSTOMER_ADDRESSES', COUNT(*) FROM RAW.ZOMATO_CUSTOMERS.CUSTOMER_ADDRESSES
UNION ALL SELECT 'DELIVERY_PARTNERS',  COUNT(*) FROM RAW.ZOMATO_DELIVERY.DELIVERY_PARTNERS
UNION ALL SELECT 'ORDERS',             COUNT(*) FROM RAW.ZOMATO_TRANSACTIONAL.ORDERS
UNION ALL SELECT 'ORDER_ITEMS',        COUNT(*) FROM RAW.ZOMATO_TRANSACTIONAL.ORDER_ITEMS
UNION ALL SELECT 'DELIVERIES',         COUNT(*) FROM RAW.ZOMATO_DELIVERY.DELIVERIES
UNION ALL SELECT 'PAYMENTS',           COUNT(*) FROM RAW.ZOMATO_PAYMENTS.PAYMENTS
UNION ALL SELECT 'RATINGS',            COUNT(*) FROM RAW.ZOMATO_ENGAGEMENT.RATINGS
UNION ALL SELECT 'REVIEWS',            COUNT(*) FROM RAW.ZOMATO_ENGAGEMENT.REVIEWS
UNION ALL SELECT 'PROMOTIONS',         COUNT(*) FROM RAW.ZOMATO_PROMOTIONS.PROMOTIONS
UNION ALL SELECT 'PROMO_REDEMPTIONS',  COUNT(*) FROM RAW.ZOMATO_PROMOTIONS.PROMO_REDEMPTIONS
UNION ALL SELECT 'SUPPORT_TICKETS',    COUNT(*) FROM RAW.ZOMATO_SUPPORT.SUPPORT_TICKETS
UNION ALL SELECT 'TICKET_COMMENTS',    COUNT(*) FROM RAW.ZOMATO_SUPPORT.TICKET_COMMENTS
ORDER BY 1;

-- Order status mix and GMV
SELECT order_status,
       COUNT(*)                     AS orders,
       ROUND(AVG(total_amount), 2)  AS avg_order_value,
       ROUND(SUM(total_amount) / 1e6, 2) AS gmv_millions_inr
FROM RAW.ZOMATO_TRANSACTIONAL.ORDERS
GROUP BY 1
ORDER BY 2 DESC;

-- FK sanity checks (all should be 0)
SELECT COUNT(*) AS orphan_orders_customer
FROM RAW.ZOMATO_TRANSACTIONAL.ORDERS o
LEFT JOIN RAW.ZOMATO_CUSTOMERS.CUSTOMERS c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT COUNT(*) AS orphan_order_items_menu
FROM RAW.ZOMATO_TRANSACTIONAL.ORDER_ITEMS oi
LEFT JOIN RAW.ZOMATO_RESTAURANTS.MENU_ITEMS m ON oi.menu_item_id = m.menu_item_id
WHERE m.menu_item_id IS NULL;

SELECT COUNT(*) AS orphan_orders_city
FROM RAW.ZOMATO_TRANSACTIONAL.ORDERS o
LEFT JOIN RAW.ZOMATO_GEOGRAPHY.CITIES c ON o.city_id = c.city_id
WHERE c.city_id IS NULL;
