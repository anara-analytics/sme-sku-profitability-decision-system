-- =============================================================
-- 03_cost_model.sql
-- Cost integration logic (per-category and per-SKU cost views).
-- =============================================================

-- Depends on: 02_tables.sql (+ 02b_data.sql for results)
-- dim_category joins the 5 cost/lookup tables; vw_sku_costs derives
-- COGS, storage, fulfillment, return and freight cost per SKU.

--
-- Name: dim_category; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.dim_category AS
 SELECT ct.product_category_name_english AS category,
    sc.cogs_rate,
    st.storage_cost_per_unit,
    fc.fulfillment_cost_per_order,
    rc.return_rate,
    rc.return_cost_per_unit
   FROM ((((public.category_translation ct
     JOIN public.supplier_costs sc ON ((sc.category = ct.product_category_name_english)))
     JOIN public.storage_costs st ON ((st.category = ct.product_category_name_english)))
     JOIN public.fulfillment_costs fc ON ((fc.category = ct.product_category_name_english)))
     JOIN public.return_costs rc ON ((rc.category = ct.product_category_name_english)));


--
-- Name: vw_sku_costs; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_sku_costs AS
 WITH sku_base AS (
         SELECT oi.product_id,
            ct.product_category_name_english AS category,
            count(oi.order_item_id) AS units_sold,
            count(DISTINCT oi.order_id) AS order_count,
            sum(oi.price) AS gross_revenue,
            sum(oi.freight_value) AS freight_cost_total
           FROM (((public.order_items oi
             JOIN public.orders o ON ((oi.order_id = o.order_id)))
             JOIN public.products p ON ((oi.product_id = p.product_id)))
             JOIN public.category_translation ct ON ((p.product_category_name = ct.product_category_name)))
          WHERE (NOT (o.order_status = ANY (ARRAY['canceled'::text, 'unavailable'::text])))
          GROUP BY oi.product_id, ct.product_category_name_english
        )
 SELECT b.product_id,
    b.category,
    round(((b.gross_revenue * sc.cogs_rate))::numeric, 2) AS cogs_total,
    round((((b.units_sold)::double precision * st.storage_cost_per_unit))::numeric, 2) AS storage_cost_total,
    round((((b.order_count)::double precision * fc.fulfillment_cost_per_order))::numeric, 2) AS fulfillment_cost_total,
    round(((((b.units_sold)::double precision * rc.return_rate) * rc.return_cost_per_unit))::numeric, 2) AS return_cost_total,
    round((b.freight_cost_total)::numeric, 2) AS freight_cost_total
   FROM ((((sku_base b
     JOIN public.supplier_costs sc ON ((sc.category = b.category)))
     JOIN public.storage_costs st ON ((st.category = b.category)))
     JOIN public.fulfillment_costs fc ON ((fc.category = b.category)))
     JOIN public.return_costs rc ON ((rc.category = b.category)));
