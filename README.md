# Centralized Clinical Trial & ADR Data Management System

## Overview

This project provides a comprehensive SQL-based solution for eliminating data silos in pharmaceutical organizations by centralizing clinical trial data, adverse drug reaction (ADR) data, and related regulatory information into a unified database schema.

## Key Features

- **Centralized Data Hub**: Consolidates trial management, subject enrollment, adverse events, and regulatory data into one unified system
- **Trial Management**: Complete tracking of clinical trials across multiple phases (I, II, III, IV) with status monitoring
- **ADR Monitoring**: Systematic collection and tracking of adverse drug reactions using MedDRA coding standards
- **Subject Management**: Comprehensive patient/subject data including demographics, enrollment status, and treatment assignments
- **Regulatory Compliance**: Built-in audit trails, ethics approvals, and regulatory reporting capabilities
- **Data Integrity**: Foreign key constraints, unique constraints, and check constraints ensure data quality
- **Audit Logging**: Complete audit trail for all data modifications
- **Reporting Views**: Pre-built views for safety summaries and enrollment progress tracking

## Database Schema Components

### Core Tables

1. **trials** - Central hub for all clinical trial information
2. **investigator** - Principal Investigators and study personnel
3. **drugs** - Canonical drug master data
4. **treatment_arm** - Trial-specific treatment arms and dosing regimens
5. **site** - Clinical trial sites and institutions
6. **subjects** - Patient/subject enrollment and demographics
7. **adr** - Adverse Drug Reaction records
8. **meddra** - MedDRA medical terminology standards
9. **trial_drug** - Drug-trial associations

### Supporting Tables

- **monitoring_visits** - Subject visit tracking and assessments
- **laboratory_results** - Lab test results and outcomes
- **concomitant_medications** - Concurrent medications during trials
- **protocol_amendments** - Protocol change tracking
- **ethics_approval** - Ethics committee approvals and dates
- **regulatory_report** - Regulatory submissions and communications
- **adr_drug_link** - Many-to-many relationship between ADRs and drugs
- **report_drug_link** - Drug linkages for regulatory reports
- **audit_log** - Complete audit trail of data modifications
- **feature_metadata** - Metadata for system configuration

## Getting Started

### Prerequisites

- PostgreSQL 12 or higher
- SQL client (psql, pgAdmin, or similar)

### Installation

1. Connect to your PostgreSQL database
2. Execute the SQL script to create all tables, views, and constraints
3. The script includes DROP statements for re-runs - comment out if data retention is needed

```sql
psql -U postgres -d your_database -f Centralized_Pharma_Data_SQL_code.sql
```

## Key Constraints & Features

- **Primary Keys**: All tables use GENERATED ALWAYS AS IDENTITY for auto-increment IDs
- **Foreign Keys**: CASCADE DELETE for logical data relationships
- **Check Constraints**: Status and phase validations to ensure data consistency
- **Unique Constraints**: Prevents duplicate codes and trial-specific entries
- **Timestamps**: Automatic created_at timestamps for audit purposes

## Usage Examples

### Creating a New Trial

```sql
INSERT INTO trials (trial_code, trial_name, phase, therapeutic_area, sponsor_company, start_date, status, created_by)
VALUES ('TRIAL-001', 'Phase III Cardiovascular Study', 'III', 'Cardiology', 'Pharma Corp', '2024-01-15', 'recruiting', 'admin@pharma.com');
```

### Recording an Adverse Event

```sql
INSERT INTO adr (trial_id, subject_id, event_date, description, severity, outcome, reported_by)
VALUES (1, 1, '2024-06-01', 'Headache', 'Mild', 'Resolved', 'Nurse_123');
```

### Viewing Trial Safety Summary

```sql
SELECT * FROM vw_trial_safety_summary;
```

## Data Relationships

```
trials (central hub)
  ├── treatment_arm → drugs
  ├── site
  ├── subjects → treatment_arm
  ├── monitoring_visits
  ├── laboratory_results
  ├── adr → subjects
  ├── ethics_approval
  └── regulatory_report
```

## Compliance & Audit

- All data modifications are logged in the `audit_log` table
- Ethics approval tracking ensures regulatory compliance
- Support for multiple regulatory report types
- ADR tracking aligned with pharmaceutical safety standards

## Best Practices

1. **Data Entry**: Always validate phase, status, and severity values against CHECK constraints
2. **Foreign Keys**: Maintain referential integrity when inserting related records
3. **Audit Trail**: Review audit_log regularly for compliance and data quality checks
4. **Backup**: Regular backups recommended before bulk operations
5. **Version Control**: Track schema changes and migrations

## Views

- **vw_trial_safety_summary** - Safety event summary by trial
- **vw_enrollment_progress** - Real-time enrollment tracking by site and arm

---

**Last Updated**: May 2026

**Version**: 1.0
