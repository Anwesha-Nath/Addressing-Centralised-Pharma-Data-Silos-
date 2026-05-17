-- ====================================================================
-- Centralized Clinical Trial & ADR Data Management
-- Purpose: Eliminate data silos by centralizing various data tables related to pharma 
-- ====================================================================

-- 0. Safety drop (for re-run)
DROP VIEW IF EXISTS vw_trial_safety_summary CASCADE;
DROP VIEW IF EXISTS vw_enrollment_progress CASCADE;
DROP TABLE IF EXISTS report_drug_link CASCADE;
DROP TABLE IF EXISTS adr_drug_link CASCADE;
DROP TABLE IF EXISTS concomitant_medications CASCADE;
DROP TABLE IF EXISTS laboratory_results CASCADE;
DROP TABLE IF EXISTS monitoring_visits CASCADE;
drop TABLE IF EXISTS ethics_approval CASCADE;
DROP TABLE IF EXISTS protocol_amendments CASCADE;
DROP TABLE IF EXISTS regulatory_report CASCADE;
DROP TABLE IF EXISTS executive_kpi CASCADE;
DROP TABLE IF EXISTS feature_metadata CASCADE;
DROP TABLE IF EXISTS trial_drug CASCADE;
DROP TABLE IF EXISTS adr CASCADE;
DROP TABLE IF EXISTS meddra CASCADE;
DROP TABLE IF EXISTS Subjects CASCADE;
DROP TABLE IF EXISTS treatment_arm CASCADE;
DROP TABLE IF EXISTS drugs CASCADE;
DROP TABLE IF EXISTS site CASCADE;
DROP TABLE IF EXISTS investigator CASCADE;
DROP TABLE IF EXISTS trials CASCADE;
DROP TABLE IF EXISTS audit_log CASCADE;

-- =========================
-- 1. DDL: Create schema
-- Creating all the data tables 
-- =========================

-- 1.1 Central hub: Trials
CREATE TABLE trials (
  trial_id             INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  trial_code           VARCHAR(50) NOT NULL UNIQUE,
  trial_name           VARCHAR(250) NOT NULL,
  phase                VARCHAR(10) NOT NULL CHECK (phase IN ('I','II','III','IV')),
  therapeutic_area     VARCHAR(120),
  sponsor_company      VARCHAR(150),
  start_date           DATE NOT NULL,
  end_date             DATE,
  status               VARCHAR(30) NOT NULL CHECK (status IN ('planned','recruiting','ongoing','completed','suspended')),
  created_by           VARCHAR(100),
  created_at           TIMESTAMP DEFAULT now()
);
-- trail_ID - PK 
-- trail_code - UNIQUE, 'phase' & 'status' - CHECK constraints  

-- 1.2 Investigator (PI)
CREATE TABLE investigator (
  investigator_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name                 VARCHAR(150) NOT NULL,
  specialization       VARCHAR(100),
  email                VARCHAR(150),
  phone                VARCHAR(50),
  created_at           TIMESTAMP DEFAULT now()
);
-- -- investigator_ID - PK 

-- 1.3 Drugs (canonical)
CREATE TABLE drugs (
  drug_id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  drug_code            VARCHAR(50) NOT NULL UNIQUE,
  drug_name            VARCHAR(150) NOT NULL,
  dosage_strength      VARCHAR(80),
  formulation          VARCHAR(80),
  route_of_admin       VARCHAR(80),
  sponsor_company      VARCHAR(150),
  created_at           TIMESTAMP DEFAULT now()
);
-- drugs_ID - PK 
-- drug_code - UNIQUE 

-- 1.4 Treatment arms (trial-scoped)
CREATE TABLE treatment_arm (
  arm_id               INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  trial_id             INT NOT NULL,
  arm_name             VARCHAR(120) NOT NULL,
  drug_id              INT,
  dosage_strength      VARCHAR(80),
  route_of_admin       VARCHAR(80),
  CONSTRAINT fk_ta_trial FOREIGN KEY (trial_id) REFERENCES trials(trial_id) ON DELETE CASCADE,
  CONSTRAINT fk_ta_drug  FOREIGN KEY (drug_id) REFERENCES drugs(drug_id) ON DELETE SET NULL,
  CONSTRAINT uq_trial_arm UNIQUE (trial_id, arm_name)
);
-- 'arm_id' - PK
-- 'trails' & 'drugs' - FK
-- 'trail_id' & 'arm_name' - UNIQUE

-- 1.5 Site
CREATE TABLE site (
  site_id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  trial_id             INT NOT NULL,
  site_name            VARCHAR(180) NOT NULL,
  institution_name     VARCHAR(180),
  country              VARCHAR(80),
  target_enrollment    INT CHECK (target_enrollment >= 0),
  lead_investigator_id INT,
  created_at           TIMESTAMP DEFAULT now(),
  CONSTRAINT fk_site_trial FOREIGN KEY (trial_id) REFERENCES trials(trial_id) ON DELETE CASCADE,
  CONSTRAINT fk_site_inv   FOREIGN KEY (lead_investigator_id) REFERENCES investigator(investigator_id) ON DELETE SET NULL
);
-- 'site_id' - PK
-- 'trails' & 'investigator' - FK

-- 1.6 Subjects (participants) - pseudonymized
CREATE TABLE subjects (
  subject_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  external_ref         VARCHAR(120),
  trial_id             INT NOT NULL,
  site_id              INT NOT NULL,
  date_of_birth        DATE,
  age_at_enrollment    INT CHECK (age_at_enrollment >= 0),
  sex                  VARCHAR(10) CHECK (sex IN ('M','F','Other','Unknown')),
  ethnicity            VARCHAR(80),
  inclusion_date       DATE NOT NULL,
  treatment_arm_id     INT,
  completion_status    VARCHAR(30) CHECK (completion_status IN ('active','withdrawn','completed','lost_to_followup')),
  created_at           TIMESTAMP DEFAULT now(),
  CONSTRAINT fk_sub_trial FOREIGN KEY (trial_id) REFERENCES trials(trial_id) ON DELETE CASCADE,
  CONSTRAINT fk_sub_site  FOREIGN KEY (site_id) REFERENCES site(site_id) ON DELETE CASCADE,
  CONSTRAINT fk_sub_arm   FOREIGN KEY (treatment_arm_id) REFERENCES treatment_arm(arm_id) ON DELETE SET NULL
);
-- 'subject_id' - PK 
-- 'trail' , 'site' & 'treatment_arm' - FK

-- 1.7 MedDRA dictionary (reference)
CREATE TABLE meddra (
  meddra_code          VARCHAR(20) PRIMARY KEY,
  preferred_term       VARCHAR(200) NOT NULL,
  soc                  VARCHAR(150), -- System Organ Class
  level                VARCHAR(10) CHECK (level IN ('LLT','PT','HLT','HLGT','SOC')),
  created_at           TIMESTAMP DEFAULT now()
);
-- meddra_code - PK 

-- 1.8 ADR (adverse event)
CREATE TABLE adr (
  adr_id               INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  subject_id           INT NOT NULL,
  trial_id             INT NOT NULL,
  event_date           DATE NOT NULL,
  event_description    TEXT,
  meddra_code          VARCHAR(20),
  severity             VARCHAR(30) CHECK (severity IN ('mild','moderate','severe','life-threatening','fatal')),
  seriousness          BOOLEAN DEFAULT FALSE,
  outcome              VARCHAR(80),
  causality            VARCHAR(50) CHECK (causality IN ('related','possibly_related','not_related','unknown')),
  reported_by          VARCHAR(120),
  created_at           TIMESTAMP DEFAULT now(),
  CONSTRAINT fk_adr_subject FOREIGN KEY (subject_id) REFERENCES subjects(subject_id) ON DELETE CASCADE,
  CONSTRAINT fk_adr_trial   FOREIGN KEY (trial_id) REFERENCES trials(trial_id) ON DELETE CASCADE,
  CONSTRAINT fk_adr_meddra  FOREIGN KEY (meddra_code) REFERENCES meddra(meddra_code) ON DELETE SET NULL
);
-- 'adr_id' - PK
-- 'subject_id', 'trail_id', 'meddra_code' - FK 

-- 1.9 ADR ↔ Drug link (many-to-many)
CREATE TABLE adr_drug_link (
  adr_id               INT NOT NULL,
  drug_id              INT NOT NULL,
  relationship_type    VARCHAR(50) CHECK (relationship_type IN ('suspected','concomitant','interacting','unknown')),
  created_at           TIMESTAMP DEFAULT now(),
  PRIMARY KEY (adr_id, drug_id),
  CONSTRAINT fk_adl_adr FOREIGN KEY (adr_id) REFERENCES adr(adr_id) ON DELETE CASCADE,
  CONSTRAINT fk_adl_drug FOREIGN KEY (drug_id) REFERENCES drugs(drug_id) ON DELETE CASCADE
);
-- 'adr_id' & 'drug_id' - FK

-- 1.10 Regulatory_Report
CREATE TABLE regulatory_report (
  report_id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  trial_id             INT NOT NULL,
  ethics_id            INT,
  protocol_id          INT,
  report_code          VARCHAR(80) NOT NULL UNIQUE,
  agency               VARCHAR(50) NOT NULL CHECK (agency IN ('FDA','EMA','CDSCO','PMDA','Other')),
  submission_date      DATE NOT NULL,
  report_type          VARCHAR(80),
  approval_status      VARCHAR(30) CHECK (approval_status IN ('pending','approved','rejected','conditional')),
  document_uri         VARCHAR(500),
  created_at           TIMESTAMP DEFAULT now(),
  CONSTRAINT fk_report_trial FOREIGN KEY (trial_id) REFERENCES trials(trial_id) ON DELETE CASCADE
  -- FKs to ethics_id and protocol_id added later via ALTER (after those tables exist).
);
-- 'report_id' - PK
-- 'trail_id' - FK

-- 1.11 Trial_Drug (trial ↔ drug with role)
CREATE TABLE trial_drug (
  trial_id             INT NOT NULL,
  drug_id              INT NOT NULL,
  role                 VARCHAR(50) CHECK (role IN ('investigational','comparator','placebo','concomitant')),
  PRIMARY KEY (trial_id, drug_id),
  CONSTRAINT fk_td_trial FOREIGN KEY (trial_id) REFERENCES trials(trial_id) ON DELETE CASCADE,
  CONSTRAINT fk_td_drug  FOREIGN KEY (drug_id) REFERENCES drugs(drug_id) ON DELETE CASCADE
);

-- 1.12 Feature metadata (AI readiness)
CREATE TABLE feature_metadata (
  feature_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  feature_name         VARCHAR(200) NOT NULL UNIQUE,
  source_table         VARCHAR(100) NOT NULL,
  column_name          VARCHAR(100) NOT NULL,
  data_type            VARCHAR(50),
  is_model_ready       BOOLEAN DEFAULT FALSE,
  notes                TEXT,
  created_at           TIMESTAMP DEFAULT now()
);
-- 'feature_id' - PK
-- 'feature_name' - UNIQUE

-- 1.13 Executive KPIs (aggregated for dashboard)
CREATE TABLE executive_kpi (
  kpi_id               INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  trial_id             INT NOT NULL,
  metric_name          VARCHAR(150) NOT NULL,
  metric_value         NUMERIC,
  metric_date          DATE DEFAULT CURRENT_DATE,
  created_at           TIMESTAMP DEFAULT now(),
  CONSTRAINT fk_kpi_trial FOREIGN KEY (trial_id) REFERENCES trials(trial_id) ON DELETE CASCADE
);
-- 'kpi_id' - PK
-- 'trail_id' - FK

-- 1.14 Audit log (for trigger)
CREATE TABLE audit_log (
  audit_id             INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_time           TIMESTAMP DEFAULT now(),
  table_name           VARCHAR(100),
  action               VARCHAR(10),
  record_id            VARCHAR(100),
  detail               TEXT
);
-- 'audit_id' - PK 

-- 1.15 Protocol amendments (new)
CREATE TABLE protocol_amendments (
  protocol_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  trial_id             INT NOT NULL,
  amendment_date       DATE NOT NULL,
  description          TEXT,
  reason               TEXT,
  created_at           TIMESTAMP DEFAULT now(),
  CONSTRAINT fk_pa_trial FOREIGN KEY (trial_id) REFERENCES trials(trial_id) ON DELETE CASCADE
);
-- 'protocol_id' - PK
-- 'trail_id' - FK 

-- 1.16 Ethics approval (new)
CREATE TABLE ethics_approval (
  ethics_id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  trial_id             INT NOT NULL,
  committee_name       VARCHAR(200) NOT NULL,
  approval_date        DATE,
  approval_status      VARCHAR(30) CHECK (approval_status IN ('approved','pending','rejected')),
  document_uri         VARCHAR(500),
  created_at           TIMESTAMP DEFAULT now(),
  CONSTRAINT fk_eth_trial FOREIGN KEY (trial_id) REFERENCES trials(trial_id) ON DELETE CASCADE
);
-- 'ethics_id' - PK
-- 'trail_id' - FK

-- 1.17 Monitoring visits (new)
CREATE TABLE monitoring_visits (
  visit_id             INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  trial_id             INT NOT NULL,
  site_id              INT NOT NULL,
  monitor_name         VARCHAR(150),
  visit_date           DATE,
  findings             TEXT,
  created_at           TIMESTAMP DEFAULT now(),
  CONSTRAINT fk_mv_trial FOREIGN KEY (trial_id) REFERENCES trials(trial_id) ON DELETE CASCADE,
  CONSTRAINT fk_mv_site  FOREIGN KEY (site_id) REFERENCES site(site_id) ON DELETE CASCADE
);
-- 'visit_id' - PK
-- 'trail_id' & 'site_id' - FK 

-- 1.18 Laboratory results (new)
CREATE TABLE laboratory_results (
  lab_result_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  subject_id           INT NOT NULL,
  trial_id             INT NOT NULL,
  test_name            VARCHAR(150) NOT NULL,
  test_value_numeric   NUMERIC,          -- numeric for analysis
  unit                 VARCHAR(30),
  test_date            DATE NOT NULL,
  created_at           TIMESTAMP DEFAULT now(),
  CONSTRAINT fk_lr_subject FOREIGN KEY (subject_id) REFERENCES subjects(subject_id) ON DELETE CASCADE,
  CONSTRAINT fk_lr_trial   FOREIGN KEY (trial_id) REFERENCES trials(trial_id) ON DELETE CASCADE
);
-- 'lab_result_id' - PK
-- 'subject_id' & 'trail_id' - FK 

-- 1.19 Concomitant medications (new)
CREATE TABLE concomitant_medications (
  conmed_id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  subject_id           INT NOT NULL,
  drug_name            VARCHAR(200) NOT NULL,
  start_date           DATE,
  end_date             DATE,
  dose                 VARCHAR(80),
  route_of_admin       VARCHAR(80),
  created_at           TIMESTAMP DEFAULT now(),
  CONSTRAINT fk_con_subj FOREIGN KEY (subject_id) REFERENCES subjects(subject_id) ON DELETE CASCADE
);
-- 'conmed_id' - PK
-- 'subject_id' - FK 

-- 1.20 Report ↔ Drug link: many-to-many (reports may cover multiple drugs)
CREATE TABLE report_drug_link (
  report_id            INT NOT NULL,
  drug_id              INT NOT NULL,
  notes                TEXT,
  PRIMARY KEY (report_id, drug_id),
  CONSTRAINT fk_rdl_report FOREIGN KEY (report_id) REFERENCES regulatory_report(report_id) ON DELETE CASCADE,
  CONSTRAINT fk_rdl_drug   FOREIGN KEY (drug_id) REFERENCES drugs(drug_id) ON DELETE CASCADE
);

-- Now add FK columns in regulatory_report linking to ethics & protocol (we created those tables)
ALTER TABLE regulatory_report
  ADD CONSTRAINT fk_report_ethics FOREIGN KEY (ethics_id) REFERENCES ethics_approval(ethics_id) ON DELETE SET NULL,
  ADD CONSTRAINT fk_report_protocol FOREIGN KEY (protocol_id) REFERENCES protocol_amendments(protocol_id) ON DELETE SET NULL;

-- =========================
-- 2. Views 
-- =========================

-- View: trial safety summary — aggregated counts and severity breakdown
CREATE VIEW vw_trial_safety_summary AS
SELECT
  t.trial_id,
  t.trial_code,
  t.trial_name,
  COUNT(a.adr_id) FILTER (WHERE a.adr_id IS NOT NULL) AS total_adrs,
  COUNT(a.adr_id) FILTER (WHERE a.severity = 'severe') AS severe_adrs,
  COUNT(a.adr_id) FILTER (WHERE a.severity = 'fatal') AS fatal_adrs,
  SUM(CASE WHEN a.seriousness THEN 1 ELSE 0 END) AS sae_count
FROM trials t
LEFT JOIN adr a ON a.trial_id = t.trial_id
GROUP BY t.trial_id, t.trial_code, t.trial_name;

-- View: enrollment progress per trial & site
CREATE VIEW vw_enrollment_progress AS
SELECT
  t.trial_id,
  t.trial_code,
  s.site_id,
  s.site_name,
  s.country,
  s.target_enrollment,
  COUNT(sub.subject_id) AS enrolled
FROM trials t
JOIN site s ON s.trial_id = t.trial_id
LEFT JOIN subjects sub ON sub.site_id = s.site_id
GROUP BY t.trial_id, t.trial_code, s.site_id, s.site_name, s.country, s.target_enrollment;

-- =========================
-- 3. Trigger: audit ADR changes 
-- =========================

-- Trigger function writes to audit_log when ADR rows change
CREATE OR REPLACE FUNCTION fn_audit_adr_changes() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO audit_log(table_name, action, record_id, detail)
    VALUES ('adr','INSERT', NEW.adr_id::text, 'Inserted ADR for subject ' || NEW.subject_id::text || ' trial ' || NEW.trial_id::text);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_log(table_name, action, record_id, detail)
    VALUES ('adr','UPDATE', NEW.adr_id::text, 'Updated ADR ' || NEW.adr_id::text);
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO audit_log(table_name, action, record_id, detail)
    VALUES ('adr','DELETE', OLD.adr_id::text, 'Deleted ADR ' || OLD.adr_id::text);
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_adr
AFTER INSERT OR UPDATE OR DELETE ON adr
FOR EACH ROW EXECUTE FUNCTION fn_audit_adr_changes();

-- =========================
-- 4. DML: Populate tables with sample data (realistic)
-- =========================
BEGIN;

-- Trials
INSERT INTO trials (trial_code, trial_name, phase, therapeutic_area, sponsor_company, start_date, status, created_by)
VALUES
('TR-ONC-001','Kinasol Phase II Oncology','II','Oncology','Merck MSD','2024-01-15','ongoing','data_team'),
('TR-CVD-002','Cardiol Phase III Cardiovascular','III','Cardiology','Novartis','2023-09-01','recruiting','data_team'),
('TR-RESP-003','Asthabiol Phase II Asthma','II','Pulmonology','Pfizer','2024-03-01','planned','data_team'),
('TR-DIAB-004','Metafin Phase III Diabetes','III','Endocrinology','Sanofi','2023-06-15','completed','data_team'),
('TR-NEUR-005','Neurozil Phase I Alzheimer’s','I','Neurology','Eli Lilly','2024-05-20','recruiting','data_team'),
('TR-VACC-006','Immunex Phase II COVID Vaccine','II','Immunology','AstraZeneca','2023-10-01','ongoing','data_team');

-- Investigators
INSERT INTO investigator (name, specialization, email, phone)
VALUES
('Dr. Asha Sharma','Oncology','asha.sharma@bci.example','+91-80-1234567'),
('Dr. John Miller','Cardiology','john.miller@nyheart.example','+1-212-555-1000'),
('Dr. Mei Li','Pulmonology','mei.li@resp.example','+86-10-66554433'),
('Dr. Elena Rossi','Endocrinology','elena.rossi@milanohealth.example','+39-02-88997766'),
('Dr. Omar Al-Farooq','Immunology','omar.alfarooq@riyadhmed.example','+966-11-4422331'),
('Dr. Carlos Mendoza','Gastroenterology','carlos.mendoza@buenosresearch.example','+54-11-33445566');


-- Drugs
INSERT INTO drugs (drug_code, drug_name, dosage_strength, formulation, route_of_admin, sponsor_company)
VALUES
('DRG-001','Kinasol','50 mg','tablet','oral','Merck MSD'),
('DRG-002','Cardiol','100 mg','tablet','oral','Novartis'),
('DRG-003','Asthabiol','200 mg','injection','IV','Pfizer'),
('DRG-004','ComparatorX','100 mg','tablet','oral','GenericPharma'),
('DRG-005','Neurolex','10 mg','capsule','oral','Roche'),
('DRG-006','Immunavax','250 mg','injection','subcutaneous','AstraZeneca'),
('DRG-007','Hepacure','500 mg','tablet','oral','Gilead Sciences');

-- Treatment arms
INSERT INTO treatment_arm (trial_id, arm_name, drug_id, dosage_strength, route_of_admin)
VALUES
(1,'Placebo', NULL, NULL, NULL),
(1,'Low-dose', 1, '25 mg', 'oral'),
(1,'High-dose', 1, '50 mg', 'oral'),
(2,'Active', 2, '100 mg', 'oral'),
(2,'Placebo', NULL, NULL, NULL),
(3,'Active', 3, '200 mg', 'IV'),
(2, 'Low-dose', 2, '50 mg', 'oral'),
(3, 'Placebo', NULL, NULL, NULL),
(1, 'Combination Therapy', 1, '50 mg + ComparatorX 100 mg', 'oral');

-- Sites
INSERT INTO site (trial_id, site_name, institution_name, country, target_enrollment, lead_investigator_id)
VALUES
(1,'Onco Unit - Bangalore','Bangalore Cancer Institute','India',120,1),
(1,'Onco Center - London','St Marys Research','UK',80,1),
(2,'Cardio Center - NYC','NY Heart Institute','USA',200,2),
(3,'Respiratory Center - Shanghai','Shanghai Respiratory Institute','China',150,3),
(1, 'Onco Center - Milan', 'Milan Oncology Research Hospital', 'Italy', 100, 4),
(2, 'Cardio Unit - Riyadh', 'King Fahd Cardiac Center', 'Saudi Arabia', 150, 5),
(3, 'Respiratory Clinic - Buenos Aires', 'Buenos Aires Pulmonary Institute', 'Argentina', 120, 6);


-- Subjects
INSERT INTO subjects (external_ref, trial_id, site_id, date_of_birth, age_at_enrollment, sex, ethnicity, inclusion_date, treatment_arm_id, completion_status)
VALUES
('SUB-IN-0001',1,1,'1970-05-12',53,'F','Asian','2024-02-10',2,'active'),
('SUB-UK-0002',1,2,'1982-11-03',41,'M','Caucasian','2024-02-15',3,'active'),
('SUB-US-0101',2,3,'1958-07-20',66,'M','Hispanic','2023-10-02',4,'active'),
('SUB-CN-0201',3,4,'1990-04-12',34,'F','Asian','2024-04-01',6,'active'),
('SUB-IT-0301', 1, 5, '1965-09-18', 58, 'F', 'Caucasian', '2024-03-01', 7, 'active'),
('SUB-SA-0402', 2, 6, '1978-02-22', 46, 'M', 'Middle Eastern', '2023-11-20', 8, 'active'),
('SUB-AR-0503', 3, 7, '1985-07-05', 39, 'F', 'Latino', '2024-04-10', 9, 'active');

-- MedDRA entries
INSERT INTO meddra (meddra_code, preferred_term, soc, level)
VALUES
('10016256','Nausea','Gastrointestinal disorders','PT'),
('10012345','Headache','Nervous system disorders','PT'),
('10098765','Liver function test increased','Hepatobiliary disorders','PT'),
('10011222','ALT increased','Hepatobiliary disorders','PT'),
('10034567','Fatigue','General disorders and administration site conditions','PT'),
('10045678','Rash erythematous','Skin and subcutaneous tissue disorders','PT'),
('10056789','Dizziness','Nervous system disorders','PT');

-- ADRs
INSERT INTO adr (subject_id, trial_id, event_date, event_description, meddra_code, severity, seriousness, outcome, causality, reported_by)
VALUES
(1,1,'2024-02-16','Mild nausea after first dose','10016256','mild',FALSE,'resolved','possibly_related','site_nurse'),
(2,1,'2024-02-20','Elevated LFTs detected','10098765','severe',TRUE,'ongoing','related','lab_technician'),
(3,2,'2023-10-10','Headache post-dosing','10012345','moderate',FALSE,'resolved','not_related','subject'),
(4,3,'2024-04-05','ALT increased after infusion','10011222','moderate',TRUE,'ongoing','possibly_related','site_nurse'),
(5,2,'2024-03-12','Dizziness and fatigue','10012345','mild',FALSE,'resolved','possibly_related','subject'),
(6,3,'2024-05-01','Rash observed on arm','10016256','moderate',TRUE,'ongoing','related','site_nurse'),
(7,1,'2024-02-25','Increased bilirubin levels','10098765','severe',TRUE,'ongoing','related','lab_technician');

-- ADR ↔ Drug links
INSERT INTO adr_drug_link (adr_id, drug_id, relationship_type)
VALUES
(1,1,'suspected'),
(2,1,'suspected'),
(3,2,'concomitant'),
(4,3,'suspected'),
(5,2,'concomitant'),
(6,3,'suspected'),
(7,1,'concomitant');

-- Trial ↔ Drug (trial_drug)
INSERT INTO trial_drug (trial_id, drug_id, role)
VALUES
(1,1,'investigational'),
(1,4,'comparator'),
(2,2,'investigational'),
(3,3,'investigational'),
(2,5,'comparator'),
(3,1,'investigational'),
(4,2,'comparator');

-- Protocol Amendments
INSERT INTO protocol_amendments (trial_id, amendment_date, description, reason)
VALUES
(1,'2024-03-01','Extended inclusion age to 75','improve recruitment'),
(2,'2023-11-15','Adjusted primary endpoint analysis','statistical reasons'),
(3,'2024-01-20','Added new secondary endpoint','enhance data collection'),
(4,'2024-02-10','Modified visit schedule','logistical reasons'),
(5,'2023-12-05','Updated exclusion criteria','safety concerns');

-- Ethics approvals
INSERT INTO ethics_approval (trial_id, committee_name, approval_date, approval_status, document_uri)
VALUES
(1,'Bangalore Institutional Ethics Committee','2023-12-20','approved','/docs/ethics/TR-ONC-001/approval.pdf'),
(2,'NY Heart IRB','2023-08-01','approved','/docs/ethics/TR-CVD-002/approval.pdf'),
(3,'London Medical Ethics Board','2024-01-15','approved','/docs/ethics/TR-ONC-003/approval.pdf'),
(4,'Tokyo Clinical IRB','2023-11-10','approved','/docs/ethics/TR-CVD-004/approval.pdf'),
(5,'Sydney Health Research Ethics Committee','2024-02-05','approved','/docs/ethics/TR-ONC-005/approval.pdf');

-- Monitoring visits
INSERT INTO monitoring_visits (trial_id, site_id, monitor_name, visit_date, findings)
VALUES
(1,1,'Mr. Ajay Kumar','2024-02-25','No critical findings'),
(1,2,'Ms. Sarah Green','2024-03-05','Minor data entry delays'),
(2,3,'Mr. Tom Willis','2023-10-15','Consent form issues');

-- Laboratory results (numeric values)
INSERT INTO laboratory_results (subject_id, trial_id, test_name, test_value_numeric, unit, test_date)
VALUES
(1,1,'Hemoglobin',13.2,'g/dL','2024-02-12'),
(2,1,'ALT',78,'U/L','2024-02-19'),
(3,2,'Platelets',190,'10^9/L','2023-10-09'),
(4,3,'ALT',120,'U/L','2024-04-04');

-- Concomitant medications
INSERT INTO concomitant_medications (subject_id, drug_name, start_date, end_date, dose, route_of_admin)
VALUES
(1,'Paracetamol','2024-02-10','2024-02-12','500 mg','oral'),
(3,'Aspirin','2023-09-01',NULL,'75 mg','oral'),
(2,'Omeprazole','2023-12-01','2024-03-01','20 mg','oral');

-- Regulatory reports (link to ethics and protocol assumed via FK later)
INSERT INTO regulatory_report (trial_id, ethics_id, protocol_id, report_code, agency, submission_date, report_type, approval_status, document_uri)
VALUES
(1,1,1,'RR-ONC-001-FDA','FDA','2024-03-01','Initial Safety Update','pending','/docs/TR-ONC-001/initial_safety.pdf'),
(2,2,2,'RR-CVD-002-EMA','EMA','2023-12-01','Interim Efficacy','pending','/docs/TR-CVD-002/interim_efficacy.pdf');

-- Report ↔ Drug links (which drugs are covered by a report)
INSERT INTO report_drug_link (report_id, drug_id, notes)
VALUES
(1,1,'Covers Kinasol safety signals'),
(1,4,'Comparator data included'),
(2,2,'Cardiol efficacy interim data');

-- Feature metadata (for AI)
INSERT INTO feature_metadata (feature_name, source_table, column_name, data_type, is_model_ready, notes)
VALUES
('age_at_enrollment','subjects','age_at_enrollment','integer',TRUE,'Ready'),
('sex','subjects','sex','categorical',TRUE,'Encode'),
('alt_value','laboratory_results','test_value_numeric','numeric',FALSE,'Needs normalization');

-- Executive KPIs
INSERT INTO executive_kpi (trial_id, metric_name, metric_value, metric_date)
VALUES
(1,'Enrollment Rate',37,'2024-03-01'),
(1,'Severe ADR Rate (%)',1.7,'2024-03-01'),
(2,'Enrollment Rate',120,'2024-03-01');

COMMIT;
-- End sample data insertion

-- =========================
-- 5. DML: UPDATE statements (>=3)
-- =========================

-- Update 1: Mark participant as completed (business workflow)
UPDATE subjects
SET completion_status = 'completed'
WHERE external_ref = 'SUB-IN-0001';

-- Update 2: ADR was resolved; update outcome and seriousness
UPDATE adr
SET outcome = 'resolved', seriousness = FALSE
WHERE adr_id = 2;

-- Update 3: Change trial status from planned to ongoing after start
UPDATE trials
SET status = 'ongoing'
WHERE trial_code = 'TR-RESP-003' AND status = 'planned';

-- Update 4: Mark a lab value as corrected (example)
UPDATE laboratory_results
SET test_value_numeric = 82
WHERE lab_result_id = 2 AND test_name = 'ALT';

-- =========================
-- 6. DML: DELETE statements (>=3)
-- =========================

-- Delete 1: Remove a mistaken concomitant medication entry
DELETE FROM concomitant_medications
WHERE conmed_id = (SELECT conmed_id FROM concomitant_medications WHERE drug_name='TestDrug' LIMIT 1);

-- Delete 2: Remove an old KPI (cleanup)
DELETE FROM executive_kpi WHERE metric_date < '2022-01-01';

-- Delete 3: Remove a monitoring visit that was a test record (if exists)
DELETE FROM monitoring_visits WHERE monitor_name = 'Test Monitor' AND visit_date < '2020-01-01';

-- =========================
-- 7. DQL: SELECT queries (>=15 queries; joins, aggregates, GROUP BY, ORDER BY)
-- These queries demonstrate the value of a centralized DB for R&D, AI, regulators
-- =========================

-- Q1: Trial safety summary (view)
SELECT * FROM vw_trial_safety_summary ORDER BY trial_id;
-- Purpose: Aggregates all ADRs (adverse events) by trial — total, severe, and fatal counts.
-- Why It Matters: Safety teams can instantly view trial-level safety profiles, rather than pulling from multiple disconnected ADR systems.
-- Silos Solved: Combines safety + trial data automatically.

-- Q2: Enrollment progress for all trials & sites (view)
SELECT * FROM vw_enrollment_progress ORDER BY trial_id, enrolled DESC;
-- Purpose: Compares how many subjects are enrolled vs. target per site.
-- Why It Matters: R&D and project managers can track recruitment progress per site, helping allocate resources faster.
-- Silos Solved: Combines clinical operations (sites) and subject data in one query.


-- Q3: Complete ADR detail joined with subject, trial and suspected drugs (multi-join + aggregation)
SELECT
  a.adr_id,
  a.event_date,
  s.external_ref,
  t.trial_code,
  t.trial_name,
  a.severity,
  a.seriousness,
  a.outcome,
  STRING_AGG(DISTINCT d.drug_name || ' (' || adl.relationship_type || ')', ', ') AS drugs_related
FROM adr a
JOIN subjects s ON s.subject_id = a.subject_id
JOIN trials t ON t.trial_id = a.trial_id
LEFT JOIN adr_drug_link adl ON adl.adr_id = a.adr_id
LEFT JOIN drugs d ON d.drug_id = adl.drug_id
GROUP BY a.adr_id, a.event_date, s.external_ref, t.trial_code, t.trial_name, a.severity, a.seriousness, a.outcome
ORDER BY a.event_date DESC;
-- Purpose: Gives a 360° view of each ADR, which subject and trial it came from, and which drugs are implicated.
-- Why It Matters: Combines patient safety and drug exposure data — essential for pharmacovigilance.
-- Silos Solved: Merges safety, subject, and drug systems.


-- Q4: ADR counts by MedDRA SOC (aggregation)
SELECT m.soc AS system_organ_class, COUNT(a.adr_id) AS adr_count
FROM adr a
LEFT JOIN meddra m ON m.meddra_code = a.meddra_code
GROUP BY m.soc
ORDER BY adr_count DESC;
-- Purpose: Groups all adverse events by MedDRA category (e.g., gastrointestinal, nervous system).
-- Why It Matters: Allows standardized reporting to regulators like FDA/EMA using MedDRA coding.
-- Silos Solved: Integrates coded terminology data with ADR events.


-- Q5: Site performance: enrolled vs target, percent achievement
SELECT
  s.site_id,
  s.site_name,
  s.country,
  s.target_enrollment,
  COUNT(sub.subject_id) AS enrolled,
  ROUND(COALESCE((COUNT(sub.subject_id)::NUMERIC / NULLIF(s.target_enrollment,0)) * 100,0),2) AS pct_of_target
FROM site s
LEFT JOIN subjects sub ON sub.site_id = s.site_id
GROUP BY s.site_id, s.site_name, s.country, s.target_enrollment
ORDER BY pct_of_target DESC NULLS LAST;
-- Purpose: Shows site-level performance by comparing enrolled vs. target subjects
-- Why It Matters: Helps clinical operations optimize recruitment and site monitoring.
-- Silos Solved: Unifies site and participant data


-- Q6: Subjects with severe ADRs and abnormal ALT lab values (join ADR + lab)
SELECT DISTINCT s.subject_id, s.external_ref, t.trial_code, a.adr_id, a.event_date, lr.test_name, lr.test_value_numeric
FROM adr a
JOIN subjects s ON s.subject_id = a.subject_id
JOIN trials t ON t.trial_id = a.trial_id
LEFT JOIN laboratory_results lr ON lr.subject_id = s.subject_id AND lr.test_name ILIKE '%ALT%'
WHERE a.severity = 'severe'
ORDER BY a.event_date DESC;
-- Purpose: Identifies subjects who had severe ADRs and abnormal ALT lab results.
-- Why It Matters: Enables correlation between lab biomarkers and adverse reactions.
-- Silos Solved: Integrates lab data with safety monitoring.

-- Q7: Average ADRs per subject per trial (aggregate)
SELECT t.trial_id, t.trial_code, ROUND(AVG(sc.cnt)::NUMERIC,2) AS avg_adrs_per_subject
FROM trials t
LEFT JOIN (
  SELECT subject_id, trial_id, COUNT(adr_id) AS cnt
  FROM adr
  GROUP BY subject_id, trial_id
) sc ON sc.trial_id = t.trial_id
GROUP BY t.trial_id, t.trial_code
ORDER BY avg_adrs_per_subject DESC NULLS LAST;
-- Purpose: Computes the average number of ADRs per subject.
-- Why It Matters: Detects which trials have more frequent safety signals.
-- Silos Solved: Summarizes safety and participant data for management dashboards.


-- Q8: Drugs most commonly associated with ADRs
SELECT d.drug_id, d.drug_name, COUNT(adl.adr_id) AS times_linked
FROM adr_drug_link adl
JOIN drugs d ON d.drug_id = adl.drug_id
GROUP BY d.drug_id, d.drug_name
ORDER BY times_linked DESC;
-- Purpose: Ranks drugs by how many ADRs they’re linked with.
-- Why It Matters: Helps safety scientists identify high-risk compounds early.
-- Silos Solved: Integrates drug metadata with pharmacovigilance outcomes.


-- Q9: Pending regulatory reports with count of severe ADRs for the trial
SELECT rr.report_id, rr.report_code, rr.agency, rr.submission_date, rr.approval_status,
       COUNT(a.adr_id) FILTER (WHERE a.severity = 'severe') AS severe_adr_count
FROM regulatory_report rr
LEFT JOIN adr a ON a.trial_id = rr.trial_id
WHERE rr.approval_status = 'pending'
GROUP BY rr.report_id, rr.report_code, rr.agency, rr.submission_date, rr.approval_status
ORDER BY rr.submission_date ASC;
-- Purpose: Helps regulatory affairs monitor pending submissions and linked safety risks.
-- Why It Matters: Prevents delays in approvals due to missing safety updates.
-- Silos Solved: Combines regulatory and clinical safety data.

-- Q10: AI team: model-ready features
SELECT feature_id, feature_name, source_table, column_name, data_type, is_model_ready
FROM feature_metadata
WHERE is_model_ready = TRUE
ORDER BY feature_name;
-- Purpose: Lists all columns that are cleaned and approved for machine learning.
-- Why It Matters: Accelerates AI model development for patient risk prediction.
-- Silos Solved: Documents features across systems for data science reuse.

-- Q11: Monitoring visits and findings per site/trial
SELECT t.trial_code, s.site_name, mv.monitor_name, mv.visit_date, mv.findings
FROM monitoring_visits mv
JOIN site s ON s.site_id = mv.site_id
JOIN trials t ON t.trial_id = mv.trial_id
ORDER BY mv.visit_date DESC;
-- Purpose: Displays when and where monitoring visits occurred and findings noted.
-- Why It Matters: Ensures regulatory compliance for Good Clinical Practice (GCP).
-- Silos Solved: Brings together operational and compliance tracking.

-- Q12: Subjects with no ADRs (useful for safety denominators)
SELECT s.subject_id, s.external_ref, t.trial_code
FROM subjects s
JOIN trials t ON t.trial_id = s.trial_id
LEFT JOIN adr a ON a.subject_id = s.subject_id
WHERE a.adr_id IS NULL
ORDER BY s.inclusion_date DESC;
-- Purpose: Identifies all participants who have not experienced any adverse event.
-- Why It Matters: Helps establish safety denominators for risk calculations.
-- Silos Solved: Combines safety and subject data for balanced analysis.

-- Q13: Lab signal detection example: ALT > 50 U/L across trials (safety signal)
SELECT lr.lab_result_id, lr.test_date, lr.test_name, lr.test_value_numeric, lr.unit, s.external_ref, t.trial_code
FROM laboratory_results lr
JOIN subjects s ON s.subject_id = lr.subject_id
JOIN trials t ON t.trial_id = lr.trial_id
WHERE lr.test_name ILIKE '%ALT%' AND lr.test_value_numeric > 50
ORDER BY lr.test_date DESC;
-- Purpose: Detects possible liver-related toxicity signals.
-- Why It Matters: Enables proactive signal detection before safety escalations.
-- Silos Solved: Connects clinical labs and safety data seamlessly.


-- Q14: Concomitant medications among subjects with ADRs (helpful for causality)
SELECT DISTINCT s.external_ref, c.drug_name, c.start_date, c.end_date, a.adr_id, a.event_date
FROM concomitant_medications c
JOIN subjects s ON s.subject_id = c.subject_id
JOIN adr a ON a.subject_id = s.subject_id
ORDER BY a.event_date DESC;
-- Purpose: Correlates ADRs with other medications subjects were taking.
-- Why It Matters: Supports causality assessments (e.g., was ADR caused by main or side drug?).
-- Silos Solved: Bridges medication and ADR databases.

-- Q15: Regulatory report composition: which drugs and how many ADRs are summarized per report
SELECT rr.report_id, rr.report_code, rr.agency,
       STRING_AGG(DISTINCT d.drug_name, ', ') AS drugs_in_report,
       COUNT(a.adr_id) AS total_adrs_in_trial
FROM regulatory_report rr
LEFT JOIN report_drug_link rdl ON rdl.report_id = rr.report_id
LEFT JOIN drugs d ON d.drug_id = rdl.drug_id
LEFT JOIN adr a ON a.trial_id = rr.trial_id
GROUP BY rr.report_id, rr.report_code, rr.agency
ORDER BY rr.submission_date DESC;
-- Purpose: Displays each regulatory report’s covered drugs and related ADR count.
-- Why It Matters: Gives regulators and pharmacovigilance teams consolidated insight.
-- Silos Solved: Joins safety, drug, and regulatory systems automatically.


-- Q16: Executive KPI trend for a trial (example)
SELECT k.metric_name, k.metric_value, k.metric_date
FROM executive_kpi k
JOIN trials t ON t.trial_id = k.trial_id
WHERE t.trial_code = 'TR-ONC-001'
ORDER BY k.metric_date DESC;
-- Purpose: Shows how trial KPIs (like enrollment rate, ADR rate) evolve over time.
-- Why It Matters: Enables management dashboards and performance tracking.
-- Silos Solved: Centralizes KPIs from multiple workflows.

-- Q17: Cross-check: Sites with missing ethics approval (potential compliance hole)
SELECT DISTINCT s.site_id, s.site_name, t.trial_code, ea.ethics_id
FROM site s
JOIN trials t ON t.trial_id = s.trial_id
LEFT JOIN ethics_approval ea ON ea.trial_id = t.trial_id
WHERE ea.ethics_id IS NULL
ORDER BY s.site_id;
-- Purpose: Flags any site operating without an ethics approval record.
-- Why It Matters: Ensures compliance and audit readiness.
-- Silos Solved: Cross-verifies operational and regulatory data sources.

--Q18: Listing all ongoing trials with the number of enrolled subjects
SELECT t.trial_id,
       t.trial_name,
       t.status,
       COUNT(s.subject_id) AS enrolled_subjects
FROM trials t
LEFT JOIN subjects s ON t.trial_id = s.trial_id
WHERE t.status = 'ongoing'
GROUP BY t.trial_id, t.trial_name, t.status
ORDER BY enrolled_subjects DESC;
-- Purpose: Get ongoing trials and track subject enrollment
-- Why It Matters: Helps trial managers monitor progress and plan resource allocation
-- Silos Solved: Combines trial metadata with subject enrollment info

--Q19: Identify adverse events for a specific drug
SELECT d.drug_name,
       s.subject_id,
       s.external_ref,
       a.event_date,
       a.event_description,
       a.severity
FROM adr a
JOIN adr_drug_link adl ON a.adr_id = adl.adr_id
JOIN drugs d ON adl.drug_id = d.drug_id
JOIN subjects s ON a.subject_id = s.subject_id
WHERE d.drug_name = 'Paracetamol'
ORDER BY a.event_date;
-- Purpose: Identify which subjects experienced adverse events linked to a particular drug
-- Why It Matters: Critical for safety monitoring and pharmacovigilance
-- Silos Solved: Connects ADR records with drug administration data

--Q20:Average lab test values per trial
SELECT t.trial_name,
       lr.test_name,
       AVG(lr.test_value_numeric) AS avg_test_value,
       lr.unit
FROM laboratory_results lr
JOIN trials t ON lr.trial_id = t.trial_id
GROUP BY t.trial_name, lr.test_name, lr.unit
ORDER BY t.trial_name, lr.test_name;
-- Purpose: Compute average lab test results for each trial
-- Why It Matters: Useful for detecting trends, anomalies, or safety signals
-- Silos Solved: Combines lab results with trial data for holistic monitoring

-- Q21: Investigators and their active trials 
SELECT i.name AS investigator_name,
       t.trial_name,
       t.status,
       s.site_name
FROM investigator i
JOIN site s ON i.investigator_id = s.lead_investigator_id
JOIN trials t ON s.trial_id = t.trial_id
WHERE t.status IN ('ongoing','recruiting')
ORDER BY i.name, t.trial_name;
-- Purpose: List investigators with the trials they lead
-- Why It Matters: Supports workload management and trial oversight
-- Silos Solved: Connects investigator and trial information across sites

-- Q22: Query: Regulatory reports submitted per agency
SELECT rr.agency,
       COUNT(rr.report_id) AS total_reports,
       SUM(CASE WHEN rr.approval_status='approved' THEN 1 ELSE 0 END) AS approved_reports
FROM regulatory_report rr
GROUP BY rr.agency
ORDER BY total_reports DESC;
-- Purpose: Track regulatory submissions by agency
-- Why It Matters: Ensures compliance and avoids regulatory delays
-- Silos Solved: Links trial data with regulatory documentation

-- Q23: Subjects by treatment arm and completion status 
SELECT t.trial_name,
       ta.arm_name,
       s.completion_status,
       COUNT(s.subject_id) AS subject_count
FROM subjects s
JOIN treatment_arm ta ON s.treatment_arm_id = ta.arm_id
JOIN trials t ON s.trial_id = t.trial_id
GROUP BY t.trial_name, ta.arm_name, s.completion_status
ORDER BY t.trial_name, ta.arm_name;
-- Purpose: Analyze subject distribution across treatment arms
-- Why It Matters: Helps identify dropout trends and completion rates
-- Silos Solved: Combines trial, subject, and treatment arm information

-- Q24: Concomitant medications per subject
SELECT s.subject_id,
       s.external_ref,
       cm.drug_name,
       cm.start_date,
       cm.end_date,
       cm.dose
FROM concomitant_medications cm
JOIN subjects s ON cm.subject_id = s.subject_id
ORDER BY s.subject_id, cm.start_date;
-- Purpose: Identify all other drugs subjects are taking during a trial
-- Why It Matters: Detect potential drug interactions and confounding factors
-- Silos Solved: Connects subject treatment records with concomitant medication data

-- Q25: Count of serious adverse events per trial
SELECT t.trial_name,
       COUNT(a.adr_id) AS serious_events
FROM adr a
JOIN trials t ON a.trial_id = t.trial_id
WHERE a.seriousness = TRUE
GROUP BY t.trial_name
ORDER BY serious_events DESC;
-- Purpose: Identify trials with the highest number of serious events
-- Why It Matters: Prioritizes safety monitoring and mitigation actions
-- Silos Solved: Connects ADRs with trial metadata and MedDRA classification

-- =========================
-- 8. Helpful Index recommendations
-- (Create indexes to speed queries in production)
-- =========================
CREATE INDEX IF NOT EXISTS idx_adr_trial ON adr(trial_id);
CREATE INDEX IF NOT EXISTS idx_adr_subject ON adr(subject_id);
CREATE INDEX IF NOT EXISTS idx_lr_subject_test ON laboratory_results(subject_id, test_name);
CREATE INDEX IF NOT EXISTS idx_sub_trial ON subjects(trial_id);
CREATE INDEX IF NOT EXISTS idx_report_trial ON regulatory_report(trial_id);

