-- =============================================================
-- 02_tables.sql
-- Base table creation + keys/constraints (structure only).
-- =============================================================

-- Depends on: 01_schema.sql
-- Creates the 9 raw tables, then primary keys, unique and FK constraints.

-- ---- CREATE TABLE ----------------------------------------------

--
-- Name: category_translation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_translation (
    product_category_name text NOT NULL,
    product_category_name_english text
);


--
-- Name: fulfillment_costs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fulfillment_costs (
    category text NOT NULL,
    fulfillment_cost_per_order real NOT NULL
);


--
-- Name: return_costs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.return_costs (
    category text NOT NULL,
    return_rate real NOT NULL,
    return_cost_per_unit real NOT NULL
);


--
-- Name: storage_costs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.storage_costs (
    category text NOT NULL,
    storage_cost_per_unit real NOT NULL
);


--
-- Name: supplier_costs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_costs (
    category text NOT NULL,
    cogs_rate real NOT NULL
);


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    order_id text NOT NULL,
    customer_id text,
    order_status text,
    order_purchase_timestamp text,
    order_approved_at text,
    order_delivered_carrier_date text,
    order_delivered_customer_date text,
    order_estimated_delivery_date text
);


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    product_id text NOT NULL,
    product_category_name text,
    product_name_lenght real,
    product_description_lenght real,
    product_photos_qty real,
    product_weight_g real,
    product_length_cm real,
    product_height_cm real,
    product_width_cm real
);


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_items (
    order_id text NOT NULL,
    order_item_id integer NOT NULL,
    product_id text,
    seller_id text,
    shipping_limit_date text,
    price real,
    freight_value real
);


--
-- Name: order_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_reviews (
    review_id text NOT NULL,
    order_id text,
    review_score integer,
    review_comment_title text,
    review_comment_message text,
    review_creation_date text,
    review_answer_timestamp text
);


-- ---- CONSTRAINTS (PK / UNIQUE / FK) ----------------------------

--
-- Name: category_translation pk_category_translation; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_translation
    ADD CONSTRAINT pk_category_translation PRIMARY KEY (product_category_name);


--
-- Name: fulfillment_costs pk_fulfillment_costs; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fulfillment_costs
    ADD CONSTRAINT pk_fulfillment_costs PRIMARY KEY (category);


--
-- Name: order_items pk_order_items; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT pk_order_items PRIMARY KEY (order_id, order_item_id);


--
-- Name: order_reviews pk_order_reviews; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_reviews
    ADD CONSTRAINT pk_order_reviews PRIMARY KEY (review_id);


--
-- Name: orders pk_orders; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT pk_orders PRIMARY KEY (order_id);


--
-- Name: products pk_products; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT pk_products PRIMARY KEY (product_id);


--
-- Name: return_costs pk_return_costs; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.return_costs
    ADD CONSTRAINT pk_return_costs PRIMARY KEY (category);


--
-- Name: storage_costs pk_storage_costs; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_costs
    ADD CONSTRAINT pk_storage_costs PRIMARY KEY (category);


--
-- Name: supplier_costs pk_supplier_costs; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_costs
    ADD CONSTRAINT pk_supplier_costs PRIMARY KEY (category);


--
-- Name: category_translation uq_category_en; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_translation
    ADD CONSTRAINT uq_category_en UNIQUE (product_category_name_english);


--
-- Name: fulfillment_costs fk_fc_category; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fulfillment_costs
    ADD CONSTRAINT fk_fc_category FOREIGN KEY (category) REFERENCES public.category_translation(product_category_name_english);


--
-- Name: products fk_p_category; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT fk_p_category FOREIGN KEY (product_category_name) REFERENCES public.category_translation(product_category_name);


--
-- Name: return_costs fk_rc_category; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.return_costs
    ADD CONSTRAINT fk_rc_category FOREIGN KEY (category) REFERENCES public.category_translation(product_category_name_english);


--
-- Name: supplier_costs fk_sc_category; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_costs
    ADD CONSTRAINT fk_sc_category FOREIGN KEY (category) REFERENCES public.category_translation(product_category_name_english);


--
-- Name: storage_costs fk_st_category; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_costs
    ADD CONSTRAINT fk_st_category FOREIGN KEY (category) REFERENCES public.category_translation(product_category_name_english);
