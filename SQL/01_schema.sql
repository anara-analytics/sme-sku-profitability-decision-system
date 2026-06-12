-- =============================================================
-- 01_schema.sql
-- Database / session structure and environment setup.
-- =============================================================

-- Run this first. Establishes session settings used by the load.
-- Objects are schema-qualified to public; schema assumed to exist.

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;
SET default_tablespace = '';
SET default_table_access_method = heap;

SELECT pg_catalog.set_config('search_path', 'public', false);
