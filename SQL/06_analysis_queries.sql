-- =============================================================
-- 05_analysis_queries.sql
-- Final KPI, reporting and sensitivity views.
-- =============================================================

-- Depends on: 04_profitability_views.sql
-- Sensitivity scenario views precede vw_sensitivity_summary.

--
-- Name: vw_business_impact; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_business_impact AS
 SELECT 'EXIT SKUs — eliminating losses'::text AS opportunity,
    count(*) AS sku_count,
    round(sum(
        CASE
            WHEN (vw_sku_classification.net_profit < (0)::numeric) THEN abs(vw_sku_classification.net_profit)
            ELSE (0)::numeric
        END), 2) AS potential_value_brl,
    round(sum(vw_sku_classification.gross_revenue), 2) AS revenue_in_scope
   FROM public.vw_sku_classification
  WHERE (vw_sku_classification.decision = 'EXIT'::text)
UNION ALL
 SELECT 'SCALE SKUs — 20% revenue uplift opportunity'::text AS opportunity,
    count(*) AS sku_count,
    round((((sum(vw_sku_classification.gross_revenue) * 0.20) * avg(vw_sku_classification.profit_margin_pct)) / NULLIF(100.0, (0)::numeric)), 2) AS potential_value_brl,
    round(sum(vw_sku_classification.gross_revenue), 2) AS revenue_in_scope
   FROM public.vw_sku_classification
  WHERE (vw_sku_classification.decision = 'SCALE'::text)
UNION ALL
 SELECT 'OPTIMIZE SKUs — 5pp margin improvement opportunity'::text AS opportunity,
    count(*) AS sku_count,
    round((sum(vw_sku_classification.gross_revenue) * 0.05), 2) AS potential_value_brl,
    round(sum(vw_sku_classification.gross_revenue), 2) AS revenue_in_scope
   FROM public.vw_sku_classification
  WHERE (vw_sku_classification.decision = 'OPTIMIZE'::text);


--
-- Name: vw_category_margin_changes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_category_margin_changes AS
 WITH period_bounds AS (
         SELECT min(substr(orders.order_purchase_timestamp, 1, 7)) AS min_month,
            max(substr(orders.order_purchase_timestamp, 1, 7)) AS max_month
           FROM public.orders
          WHERE ((NOT (orders.order_status = ANY (ARRAY['canceled'::text, 'unavailable'::text]))) AND (NOT (orders.order_purchase_timestamp IS NULL)))
        ), category_monthly AS (
         SELECT ct.product_category_name_english AS category,
            substr(o.order_purchase_timestamp, 1, 7) AS order_month,
            sum(oi.price) AS month_revenue,
            ((sum(oi.price) * ((1)::double precision - sc.cogs_rate)) - sum(oi.freight_value)) AS month_margin
           FROM ((((public.order_items oi
             JOIN public.orders o ON ((oi.order_id = o.order_id)))
             JOIN public.products p ON ((oi.product_id = p.product_id)))
             JOIN public.category_translation ct ON ((p.product_category_name = ct.product_category_name)))
             JOIN public.supplier_costs sc ON ((sc.category = ct.product_category_name_english)))
          WHERE ((NOT (o.order_status = ANY (ARRAY['canceled'::text, 'unavailable'::text]))) AND (NOT (o.order_purchase_timestamp IS NULL)))
          GROUP BY ct.product_category_name_english, (substr(o.order_purchase_timestamp, 1, 7)), sc.cogs_rate
        ), category_split AS (
         SELECT cm.category,
                CASE
                    WHEN (cm.order_month <= '2018-02'::text) THEN 'first_half'::text
                    ELSE 'second_half'::text
                END AS period,
            sum(cm.month_revenue) AS period_revenue,
            sum(cm.month_margin) AS period_margin
           FROM category_monthly cm
          GROUP BY cm.category,
                CASE
                    WHEN (cm.order_month <= '2018-02'::text) THEN 'first_half'::text
                    ELSE 'second_half'::text
                END
        )
 SELECT first.category,
    round((((first.period_margin * (100.0)::double precision) / NULLIF(NULLIF(first.period_revenue, (0)::double precision), (0)::double precision)))::numeric, 2) AS margin_pct_first_half,
    round((((second.period_margin * (100.0)::double precision) / NULLIF(NULLIF(second.period_revenue, (0)::double precision), (0)::double precision)))::numeric, 2) AS margin_pct_second_half,
    round(((((second.period_margin * (100.0)::double precision) / NULLIF(NULLIF(second.period_revenue, (0)::double precision), (0)::double precision)) - ((first.period_margin * (100.0)::double precision) / NULLIF(NULLIF(first.period_revenue, (0)::double precision), (0)::double precision))))::numeric, 2) AS margin_change_pp,
        CASE
            WHEN ((((second.period_margin * (100.0)::double precision) / NULLIF(NULLIF(second.period_revenue, (0)::double precision), (0)::double precision)) - ((first.period_margin * (100.0)::double precision) / NULLIF(NULLIF(first.period_revenue, (0)::double precision), (0)::double precision))) > (2)::double precision) THEN 'IMPROVING'::text
            WHEN ((((second.period_margin * (100.0)::double precision) / NULLIF(NULLIF(second.period_revenue, (0)::double precision), (0)::double precision)) - ((first.period_margin * (100.0)::double precision) / NULLIF(NULLIF(first.period_revenue, (0)::double precision), (0)::double precision))) < ('-2'::integer)::double precision) THEN 'DETERIORATING'::text
            ELSE 'STABLE'::text
        END AS trend_flag,
    round(((first.period_revenue + second.period_revenue))::numeric, 2) AS total_revenue
   FROM (category_split first
     JOIN category_split second ON ((first.category = second.category)))
  WHERE ((first.period = 'first_half'::text) AND (second.period = 'second_half'::text))
  ORDER BY (round(((((second.period_margin * (100.0)::double precision) / NULLIF(NULLIF(second.period_revenue, (0)::double precision), (0)::double precision)) - ((first.period_margin * (100.0)::double precision) / NULLIF(NULLIF(first.period_revenue, (0)::double precision), (0)::double precision))))::numeric, 2)) NULLS FIRST;


--
-- Name: vw_executive_kpis; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_executive_kpis AS
 SELECT ( SELECT count(DISTINCT vw_sku_profitability.product_id) AS count
           FROM public.vw_sku_profitability) AS total_skus_analyzed,
    ( SELECT round(sum(vw_sku_profitability.gross_revenue), 2) AS round
           FROM public.vw_sku_profitability) AS total_gross_revenue,
    ( SELECT round(sum(vw_sku_profitability.net_profit), 2) AS round
           FROM public.vw_sku_profitability) AS total_net_profit,
    ( SELECT round(avg(vw_sku_profitability.profit_margin_pct), 2) AS round
           FROM public.vw_sku_profitability) AS avg_profit_margin_pct,
    ( SELECT round(avg(vw_sku_profitability.avg_review_score), 2) AS round
           FROM public.vw_sku_profitability) AS avg_customer_review,
    ( SELECT count(*) AS count
           FROM public.vw_sku_classification
          WHERE (vw_sku_classification.decision = 'SCALE'::text)) AS scale_skus,
    ( SELECT count(*) AS count
           FROM public.vw_sku_classification
          WHERE (vw_sku_classification.decision = 'OPTIMIZE'::text)) AS optimize_skus,
    ( SELECT count(*) AS count
           FROM public.vw_sku_classification
          WHERE (vw_sku_classification.decision = 'EXIT'::text)) AS exit_skus;


--
-- Name: vw_monthly_revenue_trend; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_monthly_revenue_trend AS
 SELECT substr(o.order_purchase_timestamp, 1, 7) AS order_month,
    count(DISTINCT oi.order_id) AS order_count,
    count(oi.order_item_id) AS units_sold,
    round((sum(oi.price))::numeric, 2) AS gross_revenue,
    round((sum(oi.freight_value))::numeric, 2) AS freight_collected,
    round((avg(oi.price))::numeric, 2) AS avg_order_value
   FROM (public.order_items oi
     JOIN public.orders o ON ((oi.order_id = o.order_id)))
  WHERE ((NOT (o.order_status = ANY (ARRAY['canceled'::text, 'unavailable'::text]))) AND (NOT (o.order_purchase_timestamp IS NULL)))
  GROUP BY (substr(o.order_purchase_timestamp, 1, 7))
  ORDER BY (substr(o.order_purchase_timestamp, 1, 7)) NULLS FIRST;


--
-- Name: vw_monthly_sku_performance; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_monthly_sku_performance AS
 SELECT oi.product_id,
    ct.product_category_name_english AS category,
    substr(o.order_purchase_timestamp, 1, 7) AS order_month,
    count(oi.order_item_id) AS units_sold,
    round((sum(oi.price))::numeric, 2) AS revenue,
    round(avg(r.review_score), 2) AS avg_review_score
   FROM ((((public.order_items oi
     JOIN public.orders o ON ((oi.order_id = o.order_id)))
     JOIN public.products p ON ((oi.product_id = p.product_id)))
     JOIN public.category_translation ct ON ((p.product_category_name = ct.product_category_name)))
     LEFT JOIN public.order_reviews r ON ((oi.order_id = r.order_id)))
  WHERE ((NOT (o.order_status = ANY (ARRAY['canceled'::text, 'unavailable'::text]))) AND (NOT (o.order_purchase_timestamp IS NULL)))
  GROUP BY oi.product_id, ct.product_category_name_english, (substr(o.order_purchase_timestamp, 1, 7))
  ORDER BY (substr(o.order_purchase_timestamp, 1, 7)) NULLS FIRST;


--
-- Name: vw_sensitivity_freight_up_20pct; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_sensitivity_freight_up_20pct AS
 SELECT r.product_id,
    c.category,
    round((r.gross_revenue)::numeric, 2) AS gross_revenue,
    round(((((c.cogs_total + c.storage_cost_total) + c.fulfillment_cost_total) + c.return_cost_total) + (c.freight_cost_total * 1.20)), 2) AS stressed_total_cost,
    round(((r.gross_revenue - (((((c.cogs_total + c.storage_cost_total) + c.fulfillment_cost_total) + c.return_cost_total) + (c.freight_cost_total * 1.20)))::double precision))::numeric, 2) AS stressed_net_profit,
    round(((((r.gross_revenue - (((((c.cogs_total + c.storage_cost_total) + c.fulfillment_cost_total) + c.return_cost_total) + (c.freight_cost_total * 1.20)))::double precision) * (100.0)::double precision) / NULLIF(NULLIF(r.gross_revenue, (0)::double precision), (0)::double precision)))::numeric, 2) AS stressed_margin_pct
   FROM (public.vw_sku_revenue r
     JOIN public.vw_sku_costs c ON ((r.product_id = c.product_id)));


--
-- Name: vw_sensitivity_returns_up_50pct; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_sensitivity_returns_up_50pct AS
 SELECT r.product_id,
    c.category,
    round((r.gross_revenue)::numeric, 2) AS gross_revenue,
    round(((r.gross_revenue - (((((c.cogs_total + c.storage_cost_total) + c.fulfillment_cost_total) + (c.return_cost_total * 1.50)) + c.freight_cost_total))::double precision))::numeric, 2) AS stressed_net_profit,
    round(((((r.gross_revenue - (((((c.cogs_total + c.storage_cost_total) + c.fulfillment_cost_total) + (c.return_cost_total * 1.50)) + c.freight_cost_total))::double precision) * (100.0)::double precision) / NULLIF(NULLIF(r.gross_revenue, (0)::double precision), (0)::double precision)))::numeric, 2) AS stressed_margin_pct
   FROM (public.vw_sku_revenue r
     JOIN public.vw_sku_costs c ON ((r.product_id = c.product_id)));


--
-- Name: vw_sensitivity_storage_up_30pct; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_sensitivity_storage_up_30pct AS
 SELECT r.product_id,
    c.category,
    round((r.gross_revenue)::numeric, 2) AS gross_revenue,
    round(((r.gross_revenue - (((((c.cogs_total + (c.storage_cost_total * 1.30)) + c.fulfillment_cost_total) + c.return_cost_total) + c.freight_cost_total))::double precision))::numeric, 2) AS stressed_net_profit,
    round(((((r.gross_revenue - (((((c.cogs_total + (c.storage_cost_total * 1.30)) + c.fulfillment_cost_total) + c.return_cost_total) + c.freight_cost_total))::double precision) * (100.0)::double precision) / NULLIF(NULLIF(r.gross_revenue, (0)::double precision), (0)::double precision)))::numeric, 2) AS stressed_margin_pct
   FROM (public.vw_sku_revenue r
     JOIN public.vw_sku_costs c ON ((r.product_id = c.product_id)));


--
-- Name: vw_sensitivity_summary; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_sensitivity_summary AS
 SELECT 'Baseline'::text AS scenario,
    round(avg(vw_sku_profitability.profit_margin_pct), 2) AS avg_margin_pct,
    round(sum(vw_sku_profitability.net_profit), 2) AS total_net_profit
   FROM public.vw_sku_profitability
UNION ALL
 SELECT 'Freight +20%'::text AS scenario,
    round(avg(vw_sensitivity_freight_up_20pct.stressed_margin_pct), 2) AS avg_margin_pct,
    round(sum(vw_sensitivity_freight_up_20pct.stressed_net_profit), 2) AS total_net_profit
   FROM public.vw_sensitivity_freight_up_20pct
UNION ALL
 SELECT 'Returns +50%'::text AS scenario,
    round(avg(vw_sensitivity_returns_up_50pct.stressed_margin_pct), 2) AS avg_margin_pct,
    round(sum(vw_sensitivity_returns_up_50pct.stressed_net_profit), 2) AS total_net_profit
   FROM public.vw_sensitivity_returns_up_50pct
UNION ALL
 SELECT 'Storage +30%'::text AS scenario,
    round(avg(vw_sensitivity_storage_up_30pct.stressed_margin_pct), 2) AS avg_margin_pct,
    round(sum(vw_sensitivity_storage_up_30pct.stressed_net_profit), 2) AS total_net_profit
   FROM public.vw_sensitivity_storage_up_30pct;


--
-- Name: vw_top_400_skus; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_top_400_skus AS
 SELECT product_id,
    category,
    gross_revenue,
    total_cost,
    net_profit,
    profit_margin_pct,
    avg_review_score,
    sku_rank,
    decision
   FROM public.vw_sku_classification
  WHERE (sku_rank <= 400);


--
-- Name: vw_top_products; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_top_products AS
 SELECT p.product_id,
    p.product_category_name,
    count(*) AS total_items_sold,
    round((sum(oi.price))::numeric, 2) AS revenue
   FROM (public.order_items oi
     JOIN public.products p ON ((oi.product_id = p.product_id)))
  GROUP BY p.product_id, p.product_category_name
  ORDER BY (round((sum(oi.price))::numeric, 2)) DESC;


--
-- Name: vw_worst_rated_products; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_worst_rated_products AS
 SELECT p.product_category_name,
    round(avg(r.review_score), 2) AS avg_rating,
    count(r.review_id) AS total_reviews
   FROM (((public.products p
     JOIN public.order_items oi ON ((p.product_id = oi.product_id)))
     JOIN public.orders o ON ((oi.order_id = o.order_id)))
     JOIN public.order_reviews r ON ((o.order_id = r.order_id)))
  GROUP BY p.product_category_name
  ORDER BY (round(avg(r.review_score), 2))
 LIMIT 5;
