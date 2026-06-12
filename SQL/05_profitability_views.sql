-- =============================================================
-- 04_profitability_views.sql
-- Analytical views: dimensions, facts, revenue, profitability, classification.
-- =============================================================

-- Depends on: 03_cost_model.sql (vw_sku_profitability uses vw_sku_costs)
-- Order matters: revenue + review views precede vw_sku_profitability,
-- which precedes vw_sku_classification.

--
-- Name: dim_date; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.dim_date AS
 SELECT DISTINCT (order_purchase_timestamp)::date AS order_date,
    substr(order_purchase_timestamp, 1, 4) AS year,
    substr(order_purchase_timestamp, 1, 7) AS year_month,
    substr(order_purchase_timestamp, 6, 2) AS month,
    (EXTRACT(dow FROM (order_purchase_timestamp)::timestamp without time zone))::integer AS day_of_week
   FROM public.orders
  WHERE (NOT (order_purchase_timestamp IS NULL));


--
-- Name: dim_product; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.dim_product AS
 SELECT p.product_id,
    p.product_category_name AS category_pt,
    ct.product_category_name_english AS category_en,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
   FROM (public.products p
     LEFT JOIN public.category_translation ct ON ((p.product_category_name = ct.product_category_name)));


--
-- Name: fact_order_items; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.fact_order_items AS
 SELECT oi.order_id,
    oi.order_item_id,
    oi.product_id,
    (o.order_purchase_timestamp)::date AS order_date,
    o.order_status,
    oi.price,
    oi.freight_value,
    r.review_score
   FROM ((public.order_items oi
     JOIN public.orders o ON ((oi.order_id = o.order_id)))
     LEFT JOIN public.order_reviews r ON ((oi.order_id = r.order_id)))
  WHERE (NOT (o.order_status = ANY (ARRAY['canceled'::text, 'unavailable'::text])));


--
-- Name: vw_sku_revenue; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_sku_revenue AS
 SELECT oi.product_id,
    count(oi.order_item_id) AS units_sold,
    sum(oi.price) AS gross_revenue,
    sum(oi.freight_value) AS freight_collected,
    count(DISTINCT oi.order_id) AS order_count
   FROM (public.order_items oi
     JOIN public.orders o ON ((oi.order_id = o.order_id)))
  WHERE (NOT (o.order_status = ANY (ARRAY['canceled'::text, 'unavailable'::text])))
  GROUP BY oi.product_id;


--
-- Name: vw_sku_review_scores; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_sku_review_scores AS
 SELECT oi.product_id,
    round(avg(r.review_score), 2) AS avg_review_score,
    sum(
        CASE
            WHEN (r.review_score <= 2) THEN 1
            ELSE 0
        END) AS negative_review_count
   FROM ((public.order_items oi
     JOIN public.orders o ON ((oi.order_id = o.order_id)))
     JOIN public.order_reviews r ON ((oi.order_id = r.order_id)))
  WHERE (NOT (o.order_status = ANY (ARRAY['canceled'::text, 'unavailable'::text])))
  GROUP BY oi.product_id;


--
-- Name: vw_sku_profitability; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_sku_profitability AS
 SELECT r.product_id,
    c.category,
    round((r.gross_revenue)::numeric, 2) AS gross_revenue,
    round(((((c.cogs_total + c.storage_cost_total) + c.fulfillment_cost_total) + c.return_cost_total) + c.freight_cost_total), 2) AS total_cost,
    round(((r.gross_revenue - (((((c.cogs_total + c.storage_cost_total) + c.fulfillment_cost_total) + c.return_cost_total) + c.freight_cost_total))::double precision))::numeric, 2) AS net_profit,
    round(((((r.gross_revenue - (((((c.cogs_total + c.storage_cost_total) + c.fulfillment_cost_total) + c.return_cost_total) + c.freight_cost_total))::double precision) * (100.0)::double precision) / NULLIF(r.gross_revenue, (0)::double precision)))::numeric, 2) AS profit_margin_pct,
    rs.avg_review_score,
    row_number() OVER (ORDER BY r.gross_revenue DESC NULLS LAST) AS sku_rank
   FROM ((public.vw_sku_revenue r
     JOIN public.vw_sku_costs c ON ((r.product_id = c.product_id)))
     LEFT JOIN public.vw_sku_review_scores rs ON ((r.product_id = rs.product_id)));


--
-- Name: vw_sku_classification; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_sku_classification AS
 SELECT product_id,
    category,
    gross_revenue,
    total_cost,
    net_profit,
    profit_margin_pct,
    avg_review_score,
    sku_rank,
        CASE
            WHEN ((profit_margin_pct < (10)::numeric) OR (avg_review_score < 3.0)) THEN 'EXIT'::text
            WHEN ((profit_margin_pct >= (25)::numeric) AND (avg_review_score >= 4.0)) THEN 'SCALE'::text
            ELSE 'OPTIMIZE'::text
        END AS decision
   FROM public.vw_sku_profitability;
