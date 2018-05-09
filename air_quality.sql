--
-- PostgreSQL database dump
--

-- Dumped from database version 10.3
-- Dumped by pg_dump version 10.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: tablefunc; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA public;


--
-- Name: EXTENSION tablefunc; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION tablefunc IS 'functions that manipulate whole tables, including crosstab';


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: air_complete; Type: TABLE; Schema: public; Owner: rossi
--

CREATE TABLE public.air_complete (
    id bigint NOT NULL,
    sensor_id integer,
    _date timestamp without time zone,
    val double precision,
    station_name text,
    latitude double precision,
    longitude double precision,
    particle text,
    unit text,
    date_format text
);


ALTER TABLE public.air_complete OWNER TO rossi;

--
-- Name: air_complete_id_seq; Type: SEQUENCE; Schema: public; Owner: rossi
--

CREATE SEQUENCE public.air_complete_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.air_complete_id_seq OWNER TO rossi;

--
-- Name: air_complete_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rossi
--

ALTER SEQUENCE public.air_complete_id_seq OWNED BY public.air_complete.id;


--
-- Name: expected_air_lectures; Type: MATERIALIZED VIEW; Schema: public; Owner: rossi
--

CREATE MATERIALIZED VIEW public.expected_air_lectures AS
 SELECT i.i AS day_hour,
    w.sensor_id,
    w.particle
   FROM generate_series(( SELECT '2013-11-01 00:00:00'::timestamp without time zone AS "timestamp"), ( SELECT '2013-12-31 23:00:00'::timestamp without time zone AS "timestamp"), '01:00:00'::interval) i(i),
    ( SELECT DISTINCT air_complete.sensor_id,
            air_complete.particle
           FROM public.air_complete) w
  ORDER BY i.i, w.sensor_id
  WITH NO DATA;


ALTER TABLE public.expected_air_lectures OWNER TO rossi;

--
-- Name: weather_complete; Type: TABLE; Schema: public; Owner: rossi
--

CREATE TABLE public.weather_complete (
    id bigint NOT NULL,
    sensor_id integer,
    _date timestamp without time zone,
    val double precision,
    station_name text,
    latitude double precision,
    longitude double precision,
    type text,
    unit text
);


ALTER TABLE public.weather_complete OWNER TO rossi;

--
-- Name: expected_weather_lectures; Type: MATERIALIZED VIEW; Schema: public; Owner: rossi
--

CREATE MATERIALIZED VIEW public.expected_weather_lectures AS
 SELECT i.i AS day_hour,
    w.sensor_id,
    w.measure
   FROM generate_series(( SELECT '2013-11-01 00:00:00'::timestamp without time zone AS "timestamp"), ( SELECT '2013-12-31 23:00:00'::timestamp without time zone AS "timestamp"), '01:00:00'::interval) i(i),
    ( SELECT DISTINCT weather_complete.sensor_id,
            weather_complete.type AS measure
           FROM public.weather_complete) w
  ORDER BY i.i, w.sensor_id
  WITH NO DATA;


ALTER TABLE public.expected_weather_lectures OWNER TO rossi;

--
-- Name: gates; Type: TABLE; Schema: public; Owner: rossi
--

CREATE TABLE public.gates (
    gate_id integer NOT NULL,
    street_name text,
    type text,
    latitude double precision,
    longitude double precision
);


ALTER TABLE public.gates OWNER TO rossi;

--
-- Name: transit; Type: TABLE; Schema: public; Owner: rossi
--

CREATE TABLE public.transit (
    _timestamp timestamp without time zone NOT NULL,
    plate text NOT NULL,
    gate_id integer NOT NULL
);


ALTER TABLE public.transit OWNER TO rossi;

--
-- Name: transit_per_gate; Type: MATERIALIZED VIEW; Schema: public; Owner: rossi
--

CREATE MATERIALIZED VIEW public.transit_per_gate AS
 SELECT g.i AS date_time,
    ('gate_'::text || g.gate_id) AS gate_id,
    count(t.plate) AS count
   FROM (( SELECT i.i,
            b.gate_id
           FROM generate_series(( SELECT '2013-11-01 00:00:00'::timestamp without time zone AS "timestamp"), ( SELECT '2013-12-31 23:00:00'::timestamp without time zone AS "timestamp"), '01:00:00'::interval) i(i),
            ( SELECT gates.gate_id
                   FROM public.gates) b
          ORDER BY i.i, b.gate_id) g
     LEFT JOIN public.transit t ON (((g.gate_id = t.gate_id) AND (date_trunc('hour'::text, t._timestamp) = g.i))))
  GROUP BY g.i, g.gate_id
  ORDER BY g.i, g.gate_id
  WITH NO DATA;


ALTER TABLE public.transit_per_gate OWNER TO rossi;

--
-- Name: vehicles; Type: TABLE; Schema: public; Owner: rossi
--

CREATE TABLE public.vehicles (
    plate text NOT NULL,
    "EURO" integer,
    "VType" integer,
    "FType" integer,
    "DPF" integer,
    "Length" integer
);


ALTER TABLE public.vehicles OWNER TO rossi;

--
-- Name: vw_air; Type: VIEW; Schema: public; Owner: rossi
--

CREATE VIEW public.vw_air AS
 SELECT DISTINCT e.day_hour AS date_time,
    e.sensor_id,
    e.particle,
    a.val
   FROM (public.expected_air_lectures e
     LEFT JOIN public.air_complete a ON (((e.sensor_id = a.sensor_id) AND (e.day_hour = a._date))));


ALTER TABLE public.vw_air OWNER TO rossi;

--
-- Name: vw_count_dist_vehicles; Type: MATERIALIZED VIEW; Schema: public; Owner: rossi
--

CREATE MATERIALIZED VIEW public.vw_count_dist_vehicles AS
 SELECT date_trunc('hour'::text, t._timestamp) AS date_time,
    v."EURO" AS euro,
    v."VType" AS vtype,
    v."FType" AS ftype,
    count(v.plate) AS c,
        CASE
            WHEN (v."Length" < 2000) THEN '0-2'::text
            WHEN ((v."Length" >= 2000) AND (v."Length" <= 4000)) THEN '2-4'::text
            WHEN ((v."Length" >= 4000) AND (v."Length" <= 6000)) THEN '4-6'::text
            ELSE '6-n'::text
        END AS ltype
   FROM (public.vehicles v
     JOIN public.transit t ON ((t.plate = v.plate)))
  GROUP BY (date_trunc('hour'::text, t._timestamp)), v."EURO", v."VType", v."FType",
        CASE
            WHEN (v."Length" < 2000) THEN '0-2'::text
            WHEN ((v."Length" >= 2000) AND (v."Length" <= 4000)) THEN '2-4'::text
            WHEN ((v."Length" >= 4000) AND (v."Length" <= 6000)) THEN '4-6'::text
            ELSE '6-n'::text
        END
  WITH NO DATA;


ALTER TABLE public.vw_count_dist_vehicles OWNER TO rossi;

--
-- Name: vw_cross_air; Type: VIEW; Schema: public; Owner: rossi
--

CREATE VIEW public.vw_cross_air AS
 SELECT pivot_air.date_time,
    pivot_air."5504",
    pivot_air."5506",
    pivot_air."5531",
    pivot_air."5542",
    pivot_air."5550",
    pivot_air."5551",
    pivot_air."5552",
    pivot_air."5722",
    pivot_air."5725",
    pivot_air."5823",
    pivot_air."5827",
    pivot_air."5834",
    pivot_air."5841",
    pivot_air."6057",
    pivot_air."6062",
    pivot_air."6320",
    pivot_air."6328",
    pivot_air."6340",
    pivot_air."6344",
    pivot_air."6354",
    pivot_air."6366",
    pivot_air."6372",
    pivot_air."6956",
    pivot_air."10273",
    pivot_air."10278",
    pivot_air."10279",
    pivot_air."10280",
    pivot_air."10282",
    pivot_air."10283",
    pivot_air."10320",
    pivot_air."17122",
    pivot_air."17126",
    pivot_air."17127",
    pivot_air."20004",
    pivot_air."20005",
    pivot_air."20020"
   FROM public.crosstab('select date_time, sensor_id, val 
from vw_air
order by date_time, sensor_id'::text, 'select distinct sensor_id from vw_air order by sensor_id'::text) pivot_air(date_time timestamp without time zone, "5504" double precision, "5506" double precision, "5531" double precision, "5542" double precision, "5550" double precision, "5551" double precision, "5552" double precision, "5722" double precision, "5725" double precision, "5823" double precision, "5827" double precision, "5834" double precision, "5841" double precision, "6057" double precision, "6062" double precision, "6320" double precision, "6328" double precision, "6340" double precision, "6344" double precision, "6354" double precision, "6366" double precision, "6372" double precision, "6956" double precision, "10273" double precision, "10278" double precision, "10279" double precision, "10280" double precision, "10282" double precision, "10283" double precision, "10320" double precision, "17122" double precision, "17126" double precision, "17127" double precision, "20004" double precision, "20005" double precision, "20020" double precision);


ALTER TABLE public.vw_cross_air OWNER TO rossi;

--
-- Name: vw_cross_traffic; Type: VIEW; Schema: public; Owner: rossi
--

CREATE VIEW public.vw_cross_traffic AS
 SELECT final_result.date_time,
    final_result.gate_57,
    final_result.gate_58,
    final_result.gate_59,
    final_result.gate_60,
    final_result.gate_61,
    final_result.gate_62,
    final_result.gate_63,
    final_result.gate_64,
    final_result.gate_65,
    final_result.gate_66,
    final_result.gate_67,
    final_result.gate_68,
    final_result.gate_69,
    final_result.gate_70,
    final_result.gate_71,
    final_result.gate_72,
    final_result.gate_73,
    final_result.gate_74,
    final_result.gate_75,
    final_result.gate_76,
    final_result.gate_77,
    final_result.gate_78,
    final_result.gate_79,
    final_result.gate_80,
    final_result.gate_81,
    final_result.gate_82,
    final_result.gate_83,
    final_result.gate_84,
    final_result.gate_85,
    final_result.gate_86,
    final_result.gate_87,
    final_result.gate_88,
    final_result.gate_89,
    final_result.gate_90,
    final_result.gate_91,
    final_result.gate_92,
    final_result.gate_93,
    final_result.gate_94,
    final_result.gate_95,
    final_result.gate_96,
    final_result.gate_97,
    final_result.gate_98
   FROM public.crosstab('select date_time, gate_id, "count" c
from transit_per_gate order by 1,2'::text, 'select distinct ''gate_''||gate_id gate_id from gates order by gate_id'::text) final_result(date_time timestamp without time zone, gate_57 integer, gate_58 integer, gate_59 integer, gate_60 integer, gate_61 integer, gate_62 integer, gate_63 integer, gate_64 integer, gate_65 integer, gate_66 integer, gate_67 integer, gate_68 integer, gate_69 integer, gate_70 integer, gate_71 integer, gate_72 integer, gate_73 integer, gate_74 integer, gate_75 integer, gate_76 integer, gate_77 integer, gate_78 integer, gate_79 integer, gate_80 integer, gate_81 integer, gate_82 integer, gate_83 integer, gate_84 integer, gate_85 integer, gate_86 integer, gate_87 integer, gate_88 integer, gate_89 integer, gate_90 integer, gate_91 integer, gate_92 integer, gate_93 integer, gate_94 integer, gate_95 integer, gate_96 integer, gate_97 integer, gate_98 integer);


ALTER TABLE public.vw_cross_traffic OWNER TO rossi;

--
-- Name: vw_cross_vehicles_dpf; Type: MATERIALIZED VIEW; Schema: public; Owner: rossi
--

CREATE MATERIALIZED VIEW public.vw_cross_vehicles_dpf AS
 SELECT final_result.date_time,
    final_result.dpf_0,
    final_result.dpf_1,
    final_result.dpf_2
   FROM public.crosstab('
select date_trunc(''hour'', t."_timestamp") date_time, ''DPF_''||v."DPF" euro, count(v.plate)
from vehicles v join transit t on t.plate = v.plate
group by 1, 2;'::text, 'select distinct ''DPF_''||v."DPF" from vehicles v order by 1'::text) final_result(date_time timestamp without time zone, dpf_0 integer, dpf_1 integer, dpf_2 integer)
  WITH NO DATA;


ALTER TABLE public.vw_cross_vehicles_dpf OWNER TO rossi;

--
-- Name: vw_cross_vehicles_euro; Type: MATERIALIZED VIEW; Schema: public; Owner: rossi
--

CREATE MATERIALIZED VIEW public.vw_cross_vehicles_euro AS
 SELECT final_result.date_time,
    final_result.euro_0,
    final_result.euro_1,
    final_result.euro_2,
    final_result.euro_3,
    final_result.euro_4,
    final_result.euro_5,
    final_result.euro_6,
    final_result.euro_7
   FROM public.crosstab('
select date_trunc(''hour'', t."_timestamp") date_time, ''euro_''||v."EURO" euro, count(v.plate)
from vehicles v join transit t on t.plate = v.plate
group by 1, 2;'::text, 'select distinct ''euro_''||v."EURO" from vehicles v order by 1'::text) final_result(date_time timestamp without time zone, euro_0 integer, euro_1 integer, euro_2 integer, euro_3 integer, euro_4 integer, euro_5 integer, euro_6 integer, euro_7 integer)
  WITH NO DATA;


ALTER TABLE public.vw_cross_vehicles_euro OWNER TO rossi;

--
-- Name: vw_cross_vehicles_ftype; Type: MATERIALIZED VIEW; Schema: public; Owner: rossi
--

CREATE MATERIALIZED VIEW public.vw_cross_vehicles_ftype AS
 SELECT final_result.date_time,
    final_result.ftype_0,
    final_result.ftype_1,
    final_result.ftype_2,
    final_result.ftype_3,
    final_result.ftype_4,
    final_result.ftype_5
   FROM public.crosstab('
select date_trunc(''hour'', t."_timestamp") date_time, ''ftype_''||v."FType" ftype, count(v.plate)
from vehicles v join transit t on t.plate = v.plate
group by 1,2;'::text, 'select distinct ''ftype_''||v."FType" from vehicles v order by 1'::text) final_result(date_time timestamp without time zone, ftype_0 integer, ftype_1 integer, ftype_2 integer, ftype_3 integer, ftype_4 integer, ftype_5 integer)
  WITH NO DATA;


ALTER TABLE public.vw_cross_vehicles_ftype OWNER TO rossi;

--
-- Name: vw_cross_vehicles_ltype; Type: MATERIALIZED VIEW; Schema: public; Owner: rossi
--

CREATE MATERIALIZED VIEW public.vw_cross_vehicles_ltype AS
 SELECT final_result.date_time,
    final_result.ltype_0,
    final_result.ltype_0_2,
    final_result.ltype_2_4,
    final_result.ltype_4_6,
    final_result.ltype_6_n
   FROM public.crosstab('
select date_trunc(''hour'', t."_timestamp") date_time
, case when v."Length" = 0 then ''ltype_0''
      when v."Length" > 0  and v."Length" < 2000 then ''ltype_0_2''
      when v."Length" between 2000 and 4000 then ''ltype_2_4''
       when v."Length" between 4000 and 6000 then ''ltype_4_6''
       else ''ltype_6_n'' end ltype
, count(v.plate)
from vehicles v join transit t on t.plate = v.plate
group by date_time, ltype;'::text, 'select a from ( values (''ltype_0''), (''ltype_0_2''), (''ltype_2_4''), (''ltype_4_6''), (''ltype_6_n'')) s(a);'::text) final_result(date_time timestamp without time zone, ltype_0 integer, ltype_0_2 integer, ltype_2_4 integer, ltype_4_6 integer, ltype_6_n integer)
  WITH NO DATA;


ALTER TABLE public.vw_cross_vehicles_ltype OWNER TO rossi;

--
-- Name: vw_cross_vehicles_vtype; Type: MATERIALIZED VIEW; Schema: public; Owner: rossi
--

CREATE MATERIALIZED VIEW public.vw_cross_vehicles_vtype AS
 SELECT final_result.date_time,
    final_result.vtype_0,
    final_result.vtype_1,
    final_result.vtype_2,
    final_result.vtype_3,
    final_result.vtype_4
   FROM public.crosstab('
select date_trunc(''hour'', t."_timestamp") date_time, ''vtype_''||v."VType" vtype, count(v.plate)
from vehicles v join transit t on t.plate = v.plate
group by 1, 2;'::text, 'select distinct ''vtype_''||v."VType" from vehicles v order by 1'::text) final_result(date_time timestamp without time zone, vtype_0 integer, vtype_1 integer, vtype_2 integer, vtype_3 integer, vtype_4 integer)
  WITH NO DATA;


ALTER TABLE public.vw_cross_vehicles_vtype OWNER TO rossi;

--
-- Name: vw_cross_weather; Type: VIEW; Schema: public; Owner: rossi
--

CREATE VIEW public.vw_cross_weather AS
 SELECT pivot_air.date_time,
    pivot_air."2001",
    pivot_air."2002",
    pivot_air."2006",
    pivot_air."2008",
    pivot_air."5897",
    pivot_air."5908",
    pivot_air."5909",
    pivot_air."5911",
    pivot_air."5920",
    pivot_air."6030",
    pivot_air."6045",
    pivot_air."6049",
    pivot_air."6064",
    pivot_air."6120",
    pivot_air."6129",
    pivot_air."6131",
    pivot_air."6138",
    pivot_air."6174",
    pivot_air."6179",
    pivot_air."6185",
    pivot_air."6457",
    pivot_air."6502",
    pivot_air."6597",
    pivot_air."8162",
    pivot_air."9341",
    pivot_air."14121",
    pivot_air."14391",
    pivot_air."19004",
    pivot_air."19005",
    pivot_air."19006",
    pivot_air."19019",
    pivot_air."19020",
    pivot_air."19021"
   FROM public.crosstab('select date_time, sensor_id, val 
from vw_weather
order by date_time, sensor_id'::text, 'select distinct sensor_id from vw_weather order by sensor_id'::text) pivot_air(date_time timestamp without time zone, "2001" double precision, "2002" double precision, "2006" double precision, "2008" double precision, "5897" double precision, "5908" double precision, "5909" double precision, "5911" double precision, "5920" double precision, "6030" double precision, "6045" double precision, "6049" double precision, "6064" double precision, "6120" double precision, "6129" double precision, "6131" double precision, "6138" double precision, "6174" double precision, "6179" double precision, "6185" double precision, "6457" double precision, "6502" double precision, "6597" double precision, "8162" double precision, "9341" double precision, "14121" double precision, "14391" double precision, "19004" double precision, "19005" double precision, "19006" double precision, "19019" double precision, "19020" double precision, "19021" double precision);


ALTER TABLE public.vw_cross_weather OWNER TO rossi;

--
-- Name: vw_weather; Type: VIEW; Schema: public; Owner: rossi
--

CREATE VIEW public.vw_weather AS
 SELECT DISTINCT e.day_hour AS date_time,
    e.sensor_id,
    e.measure,
    a.val
   FROM (public.expected_weather_lectures e
     LEFT JOIN public.weather_complete a ON (((e.sensor_id = a.sensor_id) AND (e.day_hour = a._date))));


ALTER TABLE public.vw_weather OWNER TO rossi;

--
-- Name: weather_complete_id_seq; Type: SEQUENCE; Schema: public; Owner: rossi
--

CREATE SEQUENCE public.weather_complete_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.weather_complete_id_seq OWNER TO rossi;

--
-- Name: weather_complete_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rossi
--

ALTER SEQUENCE public.weather_complete_id_seq OWNED BY public.weather_complete.id;


--
-- Name: air_complete id; Type: DEFAULT; Schema: public; Owner: rossi
--

ALTER TABLE ONLY public.air_complete ALTER COLUMN id SET DEFAULT nextval('public.air_complete_id_seq'::regclass);


--
-- Name: weather_complete id; Type: DEFAULT; Schema: public; Owner: rossi
--

ALTER TABLE ONLY public.weather_complete ALTER COLUMN id SET DEFAULT nextval('public.weather_complete_id_seq'::regclass);


--
-- Name: air_complete air_complete_pkey; Type: CONSTRAINT; Schema: public; Owner: rossi
--

ALTER TABLE ONLY public.air_complete
    ADD CONSTRAINT air_complete_pkey PRIMARY KEY (id);


--
-- Name: gates gates_pk; Type: CONSTRAINT; Schema: public; Owner: rossi
--

ALTER TABLE ONLY public.gates
    ADD CONSTRAINT gates_pk PRIMARY KEY (gate_id);


--
-- Name: transit transit_pk; Type: CONSTRAINT; Schema: public; Owner: rossi
--

ALTER TABLE ONLY public.transit
    ADD CONSTRAINT transit_pk PRIMARY KEY (_timestamp, plate);


--
-- Name: vehicles vehicles_pkey; Type: CONSTRAINT; Schema: public; Owner: rossi
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT vehicles_pkey PRIMARY KEY (plate);


--
-- Name: weather_complete weather_complete_pkey; Type: CONSTRAINT; Schema: public; Owner: rossi
--

ALTER TABLE ONLY public.weather_complete
    ADD CONSTRAINT weather_complete_pkey PRIMARY KEY (id);


--
-- Name: transit__timestamp_idx; Type: INDEX; Schema: public; Owner: rossi
--

CREATE INDEX transit__timestamp_idx ON public.transit USING btree (_timestamp);


--
-- Name: transit_gate_id_idx; Type: INDEX; Schema: public; Owner: rossi
--

CREATE INDEX transit_gate_id_idx ON public.transit USING btree (gate_id);


--
-- Name: transit transit_gates_fk; Type: FK CONSTRAINT; Schema: public; Owner: rossi
--

ALTER TABLE ONLY public.transit
    ADD CONSTRAINT transit_gates_fk FOREIGN KEY (gate_id) REFERENCES public.gates(gate_id);


--
-- Name: transit transit_vehicles_fk; Type: FK CONSTRAINT; Schema: public; Owner: rossi
--

ALTER TABLE ONLY public.transit
    ADD CONSTRAINT transit_vehicles_fk FOREIGN KEY (plate) REFERENCES public.vehicles(plate);


--
-- PostgreSQL database dump complete
--

