-- File: 02b_src_lab_messages.sql
-- Package/owner: B - Zhihao Zhang
-- Purpose: Load Appendix B.4: 36 FHIR messages and 34 result deliveries.
-- Reads: C source reference rows, encounter/dispense and audit.identity_truth.
-- Writes: src_lab.observation_message and src_lab.result_delivery only.
-- Design link: laboratory source; Observation and Result delivery entities.
-- Run after: 00 -> 01_src_tables -> C final 02_src_data handoff; before 03.
-- Re-runnable: yes; replace both target datasets in one transaction, no CASCADE.
-- Deployment: C confirms final 02 is complete; pause affected writers and back up.
-- Time assumption: received/delivered noon with the specified fixed +10:00 offset.
-- Ordinary arrivals are day +1, MSG-0032 day +4; deliveries are day +2.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $load$
DECLARE fixture jsonb; messages jsonb; deliveries jsonb;
BEGIN
 -- Keep the complete Appendix B.4 fixture in memory; create no tables.
 SELECT jsonb_agg(to_jsonb(f)) INTO fixture FROM (VALUES
('MSG-0001', 1, 'PATH0001', 'OBS-0001', DATE '2025-10-10', 50.0, 'mmol/mol', 1),
 ('MSG-0002', 1, 'PATH0001', 'OBS-0002', DATE '2026-02-12', 56.0, 'mmol/mol', 1),
 ('MSG-0003', 1, 'PATH0001', 'OBS-0003', DATE '2026-05-20', 62.0, 'mmol/mol', 1),
 ('MSG-0004', 1, 'PATH0002', 'OBS-0004', DATE '2025-11-20', 58.0, 'mmol/mol', 1),
 ('MSG-0005', 1, 'PATH0002', 'OBS-0005', DATE '2026-03-01', 57.0, 'mmol/mol', 1),
 ('MSG-0006', 1, 'PATH0002', 'OBS-0006', DATE '2026-07-01', 58.0, 'mmol/mol', 1),
 ('MSG-0007', 1, 'PATH0003', 'OBS-0007', DATE '2025-06-10', 49.0, 'mmol/mol', 2),
 ('MSG-0008', 1, 'PATH0003', 'OBS-0008', DATE '2025-12-01', 51.0, 'mmol/mol', 2),
 ('MSG-0009', 1, 'PATH0004', 'OBS-0009', DATE '2025-12-02', 47.0, 'mmol/mol', 2),
 ('MSG-0010', 1, 'PATH0004', 'OBS-0010', DATE '2026-06-02', 48.0, 'mmol/mol', NULL),
 ('MSG-0011', 2, 'PATH0005', 'OBS-0011', DATE '2026-01-05', 6.8, '%', 3),
 ('MSG-0012', 2, 'PATH0005', 'OBS-0012', DATE '2026-05-05', 6.9, '%', 3),
 ('MSG-0013', 1, 'PATH0006', 'OBS-0013', DATE '2026-02-10', 52.0, 'mmol/mol', 1),
 ('MSG-0014', 2, 'PATH0007', 'OBS-0014', DATE '2026-05-15', 6.5, '%', 3),
 ('MSG-0015', 1, 'PATH0008', 'OBS-0015', DATE '2026-01-20', 51.0, 'mmol/mol', 1),
 ('MSG-0016', 1, 'PATH0008', 'OBS-0016', DATE '2026-06-25', 50.0, 'mmol/mol', 2),
 ('MSG-0017', 1, 'PATH0009', 'OBS-0017', DATE '2025-09-28', 49.0, 'mmol/mol', 1),
 ('MSG-0018', 1, 'PATH0009', 'OBS-0018', DATE '2025-12-28', 48.0, 'mmol/mol', 1),
 ('MSG-0019', 1, 'PATH0009', 'OBS-0019', DATE '2026-03-28', 50.0, 'mmol/mol', 1),
 ('MSG-0020', 1, 'PATH0009', 'OBS-0020', DATE '2026-06-28', 48.0, 'mmol/mol', 1),
 ('MSG-0021', 1, 'PATH0010', 'OBS-0021', DATE '2026-02-01', 52.0, 'mmol/mol', 2),
 ('MSG-0022', 1, 'PATH0010', 'OBS-0022', DATE '2026-06-01', 55.0, '', 2),
 ('MSG-0023', 1, 'PATH0011', 'OBS-0023', DATE '2026-03-15', 54.0, 'mmol/mol', 3),
 ('MSG-0024', 1, 'PATH0011', 'OBS-0024', DATE '2026-06-20', 50.0, 'mmol/mol', 3),
 ('MSG-0025', 1, 'PATH0011', 'OBS-0025', DATE '2026-10-01', 49.0, 'mmol/mol', 3),
 ('MSG-0026', 1, 'PATH0012', 'OBS-0026', DATE '2026-05-10', 57.0, 'mmol/mol', 1),
 ('MSG-0027', 1, 'PATH0013', 'OBS-0027', DATE '2025-11-10', 55.0, 'mmol/mol', 2),
 ('MSG-0028', 1, 'PATH0013', 'OBS-0028', DATE '2026-04-10', 60.0, 'mmol/mol', 2),
 ('MSG-0029', 1, 'PATH0014', 'OBS-0029', DATE '2026-02-10', 52.0, 'mmol/mol', 3),
 ('MSG-0030', 1, 'PATH0014', 'OBS-0030', DATE '2026-08-10', 58.0, 'mmol/mol', 3),
 ('MSG-0031', 1, 'PATH0015', 'OBS-0031', DATE '2026-04-01', 51.0, 'mmol/mol', 1),
 ('MSG-0032', 1, 'PATH0015', 'OBS-0031', DATE '2026-04-01', 51.0, 'mmol/mol', NULL),
 ('MSG-0033', 1, 'PATH0015', 'OBS-0032', DATE '2026-07-01', 50.0, 'mmol/mol', 1),
 ('MSG-0034', 2, 'PATH0016', 'OBS-0033', DATE '2025-11-05', 7.0, '%', 2),
 ('MSG-0035', 2, 'PATH0016', 'OBS-0034', DATE '2026-06-05', 8.1, '%', 2),
 ('MSG-0036', 1, 'PATH0017', 'OBS-0035', DATE '2026-04-25', 49.0, 'mmol/mol', 3)
 ) AS f(message_id,lab_id,lab_patient_id,observation_id,collected_date,result_value,result_unit,clinic_id);
 -- Validate target columns before obtaining any destructive lock.
 IF (SELECT string_agg(attname||':'||format_type(atttypid,atttypmod),',' ORDER BY attnum)
     FROM pg_attribute WHERE attrelid='src_lab.observation_message'::regclass AND attnum>0 AND NOT attisdropped)
    IS DISTINCT FROM 'message_id:text,lab_id:integer,lab_patient_id:text,received_at:timestamp with time zone,fhir_json:jsonb'
 OR (SELECT string_agg(attname||':'||format_type(atttypid,atttypmod),',' ORDER BY attnum)
     FROM pg_attribute WHERE attrelid='src_lab.result_delivery'::regclass AND attnum>0 AND NOT attisdropped)
    IS DISTINCT FROM 'delivery_id:text,message_id:text,clinic_id:integer,delivered_at:timestamp with time zone' THEN
  RAISE EXCEPTION 'Target structure differs; coordinate with C before loading';
 END IF;
 -- Freeze prerequisite rows during validation and loading; timeout rather than interrupt a teammate.
 LOCK TABLE src_lab.laboratory,src_lab.lab_patient,src_gp.clinic,
            src_gp.encounter,src_pharm.dispense,audit.identity_truth IN SHARE MODE;
 IF (SELECT count(*) FROM src_gp.encounter)<>28
 OR (SELECT count(*) FROM src_pharm.dispense)<>68
 OR (SELECT count(*) FROM audit.identity_truth)<>48 THEN
  RAISE EXCEPTION 'C final 02 prerequisites missing: require 28 encounters, 68 dispenses, 48 identity truth rows';
 END IF;
 -- Check every patient and institution before clearing either target.
 IF EXISTS (SELECT 1 FROM jsonb_to_recordset(fixture) AS f(message_id text,lab_id integer,lab_patient_id text,observation_id text,collected_date date,result_value numeric,result_unit text,clinic_id integer) LEFT JOIN src_lab.laboratory l USING(lab_id) WHERE l.lab_id IS NULL)
 OR EXISTS (SELECT 1 FROM jsonb_to_recordset(fixture) AS f(message_id text,lab_id integer,lab_patient_id text,observation_id text,collected_date date,result_value numeric,result_unit text,clinic_id integer) LEFT JOIN src_lab.lab_patient p USING(lab_patient_id) WHERE p.lab_patient_id IS NULL)
 OR EXISTS (SELECT 1 FROM jsonb_to_recordset(fixture) AS f(message_id text,lab_id integer,lab_patient_id text,observation_id text,collected_date date,result_value numeric,result_unit text,clinic_id integer) LEFT JOIN src_gp.clinic c USING(clinic_id) WHERE f.clinic_id IS NOT NULL AND c.clinic_id IS NULL) THEN
  RAISE EXCEPTION 'Missing C reference/patient data; finish 02 and obtain handoff before 02b';
 END IF;
 -- Build fixed-offset FHIR strings without session-timezone conversions.
 SELECT jsonb_agg(to_jsonb(m) ORDER BY message_id) INTO messages FROM (
SELECT message_id,lab_id,lab_patient_id,
 ((collected_date + CASE WHEN message_id='MSG-0032' THEN 4 ELSE 1 END)::text || 'T12:00:00+10:00')::timestamptz AS received_at,
 jsonb_build_object(
  'resourceType','Observation','id',observation_id,'status','final',
  'code',jsonb_build_object('coding',jsonb_build_array(jsonb_build_object(
    'system','http://loinc.org','code',CASE WHEN lab_id=1 THEN '59261-8' ELSE '4548-4' END,
    'display','Hemoglobin A1c'))),
  'subject',jsonb_build_object('reference','Patient/'||lab_patient_id),
  'effectiveDateTime',collected_date::text||'T09:00:00+10:00',
  'issued',(collected_date+1)::text||'T12:00:00+10:00',
  'valueQuantity',jsonb_build_object('value',result_value,'unit',result_unit)
 ) AS fhir_json FROM jsonb_to_recordset(fixture) AS f(message_id text,lab_id integer,lab_patient_id text,observation_id text,collected_date date,result_value numeric,result_unit text,clinic_id integer)
 ) m;
 SELECT jsonb_agg(to_jsonb(d) ORDER BY delivery_id) INTO deliveries FROM (
SELECT replace(message_id,'MSG-','DLV-') AS delivery_id,message_id,clinic_id,
 ((collected_date+2)::text||'T12:00:00+10:00')::timestamptz AS delivered_at
FROM jsonb_to_recordset(fixture) AS f(message_id text,lab_id integer,lab_patient_id text,observation_id text,collected_date date,result_value numeric,result_unit text,clinic_id integer) WHERE clinic_id IS NOT NULL
 ) d;
 -- Replace exactly these two tables; any outside foreign key makes this fail safely.
 TRUNCATE TABLE src_lab.result_delivery,src_lab.observation_message;
 -- Insert parent messages, then child delivery records.
 INSERT INTO src_lab.observation_message(message_id,lab_id,lab_patient_id,received_at,fhir_json)
 SELECT message_id,lab_id,lab_patient_id,received_at,fhir_json FROM jsonb_to_recordset(messages)
 AS m(message_id text,lab_id integer,lab_patient_id text,received_at timestamptz,fhir_json jsonb);
 INSERT INTO src_lab.result_delivery(delivery_id,message_id,clinic_id,delivered_at)
 SELECT delivery_id,message_id,clinic_id,delivered_at FROM jsonb_to_recordset(deliveries)
 AS d(delivery_id text,message_id text,clinic_id integer,delivered_at timestamptz);
 -- Check all values, not just row counts, before the transaction may commit.
 IF (SELECT jsonb_agg(to_jsonb(m) ORDER BY message_id) FROM src_lab.observation_message m) IS DISTINCT FROM messages
 OR (SELECT jsonb_agg(to_jsonb(d) ORDER BY delivery_id) FROM src_lab.result_delivery d) IS DISTINCT FROM deliveries
 OR (SELECT count(*) FROM src_lab.observation_message)<>36
 OR (SELECT count(*) FROM src_lab.result_delivery)<>34 THEN
  RAISE EXCEPTION 'Loaded content differs from the complete expected fixture';
 END IF;
 -- Retain the two intentional undelivered observations for UC4 testing.
 IF (SELECT array_agg(m.message_id ORDER BY m.message_id) FROM src_lab.observation_message m
     LEFT JOIN src_lab.result_delivery d USING(message_id) WHERE d.message_id IS NULL)
    IS DISTINCT FROM ARRAY['MSG-0010','MSG-0032'] THEN
  RAISE EXCEPTION 'Unexpected undelivered message set';
 END IF;
END $load$;
COMMIT;
