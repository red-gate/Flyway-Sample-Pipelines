-- =============================================================================
-- client_registry_setup.sql
-- Creates and populates the flyway_registry database with the
-- jdbc_table_store table, and creates the stored procedure
-- used by the GitLab pipeline generator to build JDBC deployment targets.
--
-- Run this once on your registry SQL Server instance.
-- =============================================================================

USE master;
GO

-- Create registry database if it does not already exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'flyway_registry')
BEGIN
    CREATE DATABASE flyway_registry;
    PRINT 'Created database: flyway_registry';
END
ELSE
BEGIN
    PRINT 'Database flyway_registry already exists.';
END
GO

USE flyway_registry;
GO

-- =============================================================================
-- TABLE: jdbc_table_store
-- Mirrors the source table visible in jdbc-table-store.
-- Each row represents one database instance across a geographic location.
-- =============================================================================

IF OBJECT_ID(N'dbo.jdbc_table_store', N'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.jdbc_table_store;
    PRINT 'Dropped existing table: dbo.jdbc_table_store';
END
GO

CREATE TABLE dbo.jdbc_table_store
(
    -- Surrogate primary key – avoids the 900-byte clustered index limit that
    -- would result from using (dbserver, db) directly, and allows two logical
    -- entries to share the same physical server/database (e.g. different schemas
    -- or logical aliases pointing at the same instance).
    [entry_id]      INT             NOT NULL IDENTITY(1,1)
                                    CONSTRAINT PK_jdbc_table_store PRIMARY KEY CLUSTERED,

    -- Logical database type/category (e.g. AW, CB, CH, CO, CU, D, DLR)
    [type]          NVARCHAR(10)    NOT NULL,

    -- Short logical identifier for the database group
    [id]            NVARCHAR(50)    NOT NULL,

    -- 1 = this entry is a replica; 0 = primary
    [replicated]    BIT             NOT NULL CONSTRAINT DF_jts_replicated DEFAULT (0),

    -- Human-readable name of the database
    [name]          NVARCHAR(255)   NOT NULL,

    -- SQL Server instance / hostname used in the JDBC connection URL
    [dbserver]      NVARCHAR(255)   NOT NULL,

    -- Database name on the target server
    [db]            NVARCHAR(255)   NOT NULL,

    -- Optional access qualifier (e.g. read-only alias)
    [dbaccess]      NVARCHAR(255)   NULL,

    -- ODBC driver override (NULL = use default)
    [odbc_driver]   NVARCHAR(255)   NULL,

    -- 1 = this entry is the authoritative DB master for DTC/replication
    [is_dbmaster]   BIT             NOT NULL CONSTRAINT DF_jts_is_dbmaster DEFAULT (0),

    -- Physical machine name hosting the instance
    [machine]       NVARCHAR(255)   NULL,

    -- 1 = database is available for deployments
    [available]     BIT             NOT NULL CONSTRAINT DF_jts_available DEFAULT (1),

    -- Geographic deployment region: 'London', 'New York', or 'Tokyo'
    [location]      NVARCHAR(50)    NOT NULL,

    -- 1 = cloud-hosted; 0 = on-premises
    [is_cloud]      BIT             NOT NULL CONSTRAINT DF_jts_is_cloud DEFAULT (0)
);
GO

CREATE INDEX IX_jts_location  ON dbo.jdbc_table_store ([location]);
CREATE INDEX IX_jts_available ON dbo.jdbc_table_store ([available]);
CREATE INDEX IX_jts_type_id   ON dbo.jdbc_table_store ([type], [id]);
CREATE INDEX IX_jts_server_db ON dbo.jdbc_table_store ([dbserver], [db]);
GO

PRINT 'Created table: dbo.jdbc_table_store';
GO

-- =============================================================================
-- DATA: populate from jdbc-table-store source
-- Servers follow the regional naming convention:
--   EU* / eu* prefix => London
--   US* / us* prefix => New York
--   AS* / as* prefix => Tokyo
-- =============================================================================

INSERT INTO dbo.jdbc_table_store
    ([type], [id], [replicated], [name],
     [dbserver], [db], [dbaccess], [odbc_driver],
     [is_dbmaster], [machine], [available], [location], [is_cloud])
VALUES

-- ---------------------------------------------------------------------------
-- AW: Awesome
-- ---------------------------------------------------------------------------
('AW', 'Awesome', 0, 'Awesome',
 'EUIFISTGAGL01W', 'awesome',  NULL, NULL, 1, 'euifistgagl01w', 1, 'London',   0),
('AW', 'Awesome', 1, 'Awesome',
 'USIFISTGAGL01W', 'awesome',  NULL, NULL, 0, 'usifistgagl01w', 1, 'New York', 0),
('AW', 'Awesome', 0, 'Awesome',
 'ASIFISTGAGL01W', 'AWESOME',  NULL, NULL, 0, 'asifistgagl01w', 1, 'Tokyo',    0),

-- ---------------------------------------------------------------------------
-- AW: AwesomeM (Awesome Mobile / Mirror)
-- ---------------------------------------------------------------------------
('AW', 'AwesomeM', 0, 'Awesome Mobile',
 'EUIFISTGAGL01W', 'AWESOME',  NULL, NULL, 0, 'euifistgagl01w', 1, 'London',   0),
('AW', 'AwesomeM', 0, 'Awesome Mobile',
 'USIFISTGAGL01W', 'AWESOME',  NULL, NULL, 0, 'usifistgagl01w', 1, 'New York', 0),
('AW', 'AwesomeM', 0, 'Awesome Mobile',
 'ASIFISTGAGL01W', 'AWESOME',  NULL, NULL, 0, 'asifistgagl01w', 1, 'Tokyo',    0),

-- ---------------------------------------------------------------------------
-- CB: CodeBase
-- ---------------------------------------------------------------------------
('CB', 'CodeBase', 0, 'CodeBase',
 'EUIFISTGSQL03W', 'CODEBASE', NULL, NULL, 1, 'eufistgsql03w', 1, 'London',   0),
('CB', 'CodeBase', 0, 'CodeBase',
 'USIFISTGSQL03W', 'CODEBASE', NULL, NULL, 0, 'usfistgsql03w', 1, 'New York', 0),
('CB', 'CodeBase', 0, 'CodeBase',
 'ASIFISTGSQL03W', 'CODEBASE', NULL, NULL, 0, 'asifistgsql03w',1, 'Tokyo',    0),

-- ---------------------------------------------------------------------------
-- CH: CustHist1 - Client customer history database (batch 1)
-- ---------------------------------------------------------------------------
('CH', 'CustHist1', 0, 'Client customer history database',
 'EUIFISTGSQL03W', 'HISTCUSTOMERTRADE_DB_01', NULL, NULL, 1, 'eufistgsql03w',  1, 'London',   0),
('CH', 'CustHist1', 0, 'Client customer history database',
 'USIFISTGSQL03W', 'HISTCUSTOMERTRADE_DB_01', NULL, NULL, 0, 'usfistgsql03w',  1, 'New York', 0),
('CH', 'CustHist1', 1, 'Client customer history database',
 'ASIFISTGSQL03W', 'HISTCUSTOMERTRADE_DB_01', NULL, NULL, 0, 'asifistgsql03w', 1, 'Tokyo',    0),

-- ---------------------------------------------------------------------------
-- CH: CustHist2 - Client customer history database (batch 2)
-- ---------------------------------------------------------------------------
('CH', 'CustHist2', 0, 'Client customer history database 2',
 'EUIFISTGSQL03W', 'HISTCUSTOMERTRADE_DB_02', NULL, NULL, 1, 'eufistgsql03w',  1, 'London',   0),
('CH', 'CustHist2', 0, 'Client customer history database 2',
 'USIFISTGSQL03W', 'HISTCUSTOMERTRADE_DB_02', NULL, NULL, 0, 'usfistgsql03w',  1, 'New York', 0),
('CH', 'CustHist2', 1, 'Client customer history database 2',
 'ASIFISTGSQL03W', 'HISTCUSTOMERTRADE_DB_02', NULL, NULL, 0, 'asifistgsql03w', 1, 'Tokyo',    0),

-- ---------------------------------------------------------------------------
-- CO: Cont01 - Content Database
-- ---------------------------------------------------------------------------
('CO', 'Cont01', 0, 'Content Database',
 'EUIFISTGAGL01W', 'CONTENT_DB_01', NULL, NULL, 1, 'euifistgagl01w', 1, 'London',   1),
('CO', 'Cont01', 0, 'Content Database',
 'USIFISTGAGL01W', 'CONTENT_DB_01', NULL, NULL, 0, 'usifistgagl01w', 1, 'New York', 1),
('CO', 'Cont01', 0, 'Content Database',
 'ASIFISTGAGL01W', 'CONTENT_DB_01', NULL, NULL, 0, 'asifistgagl01w', 1, 'Tokyo',    1),

-- ---------------------------------------------------------------------------
-- CU: CustomTrade01 - Client customer trading database (primary)
-- ---------------------------------------------------------------------------
('CU', 'Custom01', 1, 'Client customer trading database',
 'EUIFISTGAGL01W',  'CUSTOMERTRADE_DB_01',    NULL, NULL, 1, 'euifistgagl01w',  1, 'London',   0),
('CU', 'Custom01', 1, 'Client customer trading database',
 'eufistgsql03w',   'histcustomertrade_db_01',NULL, NULL, 0, 'eufistgsql03w',   1, 'London',   0),
('CU', 'Custom01', 0, 'Client customer trading database',
 'USIFISTGAGL01W',  'CUSTOMERTRADE_DB_01',    NULL, NULL, 0, 'usifistgagl01w',  1, 'New York', 0),
('CU', 'Custom01', 1, 'Client customer trading database',
 'asifistgsql03w',  'histcustomertrade_db_01',NULL, NULL, 0, 'asifistgsql03w',  1, 'New York', 0),
('CU', 'Custom01', 1, 'Client customer trading database',
 'ASIFISTGAGL01W',  'CUSTOMERTRADE_DB_01',    NULL, NULL, 0, 'asifistgagl01w',  1, 'Tokyo',    0),
('CU', 'Custom01', 1, 'Client customer trading database',
 'asifistgagl03w',  'histcustomertrade_db_01',NULL, NULL, 0, 'asifistgagl03w',  1, 'Tokyo',    0),

-- ---------------------------------------------------------------------------
-- CU: CustomTrade02 - Client customer trading database (batch 2)
-- ---------------------------------------------------------------------------
('CU', 'Custom02', 1, 'Client customer trading database 2',
 'EUIFISTGAGL01W',  'CUSTOMERTRADE_DB_02',    NULL, NULL, 1, 'euifistgagl01w',  1, 'London',   0),
('CU', 'Custom02', 1, 'Client customer trading database 2',
 'eufistgsql03w',   'histcustomertrade_db_02',NULL, NULL, 0, 'eufistgsql03w',   1, 'London',   0),
('CU', 'Custom02', 0, 'Client customer trading database 2',
 'USIFISTGAGL01W',  'CUSTOMERTRADE_DB_02',    NULL, NULL, 0, 'usifistgagl01w',  1, 'New York', 0),
('CU', 'Custom02', 1, 'Client customer trading database 2',
 'ASIFISTGAGL01W',  'CUSTOMERTRADE_DB_02',    NULL, NULL, 0, 'asifistgagl01w',  1, 'Tokyo',    0),

-- ---------------------------------------------------------------------------
-- D: DlrHist1 - Client dealer history database (batch 1)
-- ---------------------------------------------------------------------------
('D',  'DlrHist1', 0, 'Client dealer history database 1',
 'EUIFISTGSQL03W', 'HISTDEALERTRADE_DB_01', NULL, NULL, 1, 'eufistgsql03w',  1, 'London',   0),
('D',  'DlrHist1', 0, 'Client dealer history database 1',
 'USIFISTGSQL03W', 'HISTDEALERTRADE_DB_01', NULL, NULL, 0, 'usfistgsql03w',  1, 'New York', 0),
('D',  'DlrHist1', 1, 'Client dealer history database 1',
 'ASIFISTGSQL03W', 'HISTDEALERTRADE_DB_01', NULL, NULL, 0, 'asifistgsql03w', 1, 'Tokyo',    0),

-- ---------------------------------------------------------------------------
-- D: DlrHist2 - Client dealer history database (batch 2)
-- ---------------------------------------------------------------------------
('D',  'DlrHist2', 0, 'Client dealer history database 2',
 'EUIFISTGSQL03W', 'HISTDEALERTRADE_DB_02', NULL, NULL, 1, 'eufistgsql03w',  1, 'London',   0),
('D',  'DlrHist2', 0, 'Client dealer history database 2',
 'USIFISTGSQL03W', 'HISTDEALERTRADE_DB_02', NULL, NULL, 0, 'usfistgsql03w',  1, 'New York', 0),
('D',  'DlrHist2', 1, 'Client dealer history database 2',
 'ASIFISTGSQL03W', 'HISTDEALERTRADE_DB_02', NULL, NULL, 0, 'asifistgsql03w', 1, 'Tokyo',    0),

-- ---------------------------------------------------------------------------
-- DLR: Dealer1 - Client dealer trading database 1
-- ---------------------------------------------------------------------------
('DLR','Dealer1', 0, 'Client dealer trading database 1',
 'EUIFISTGAGL01W',  'DEALERTRADE_DB_01',       NULL, NULL, 1, 'euifistgagl01w', 1, 'London',   0),
('DLR','Dealer1', 1, 'Client dealer trading database 1',
 'eufistgsql03w',   'histdealertrade_db_01',   NULL, NULL, 0, 'eufistgsql03w',  1, 'London',   0),
('DLR','Dealer1', 0, 'Client dealer trading database 1',
 'USIFISTGAGL01W',  'DEALERTRADE_DB_01',       NULL, NULL, 0, 'usifistgagl01w', 1, 'New York', 0),
('DLR','Dealer1', 0, 'Client dealer trading database 1',
 'ASIFISTGAGL01W',  'DEALERTRADE_DB_01',       NULL, NULL, 0, 'asifistgagl01w', 1, 'Tokyo',    0);
GO

PRINT 'Inserted all rows into dbo.jdbc_table_store';
GO

-- =============================================================================
-- STORED PROCEDURE: usp_GetFlywayTargets
-- Returns deployment targets for the pipeline generator.
-- Constructs the JDBC URL directly so callers do not need to build strings.
--
-- Parameters:
--   @location      Filter by location ('London','New York','Tokyo'). NULL = all.
--   @available_only  1 = only available databases (default). 0 = all.
--   @jdbc_port       SQL Server port for JDBC URL construction (default 1433).
--   @include_replicas  1 = include replicated entries. 0 = primaries only.
-- =============================================================================

IF OBJECT_ID(N'dbo.usp_GetFlywayTargets', N'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.usp_GetFlywayTargets;
    PRINT 'Dropped existing procedure: dbo.usp_GetFlywayTargets';
END
GO

CREATE PROCEDURE dbo.usp_GetFlywayTargets
    @location         NVARCHAR(50)  = NULL,   -- NULL returns all locations
    @available_only   BIT           = 1,       -- 1 = skip unavailable DBs
    @jdbc_port        INT           = 1433,    -- SQL Server port for JDBC string
    @include_replicas BIT           = 1        -- 1 = include replicated entries
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        [type],
        [id],
        [replicated],
        [name],
        [dbserver],
        [db],
        [location],
        [is_dbmaster],
        [machine],
        [available],
        [is_cloud],

        -- Fully constructed JDBC connection string ready for Flyway
        N'jdbc:sqlserver://' + [dbserver]
            + N':' + CAST(@jdbc_port AS NVARCHAR(10))
            + N';databaseName=' + [db]
            + N';encrypt=false;trustServerCertificate=true'
            AS [jdbc_url]

    FROM
        dbo.jdbc_table_store

    WHERE
        -- Optional availability filter
        (@available_only = 0   OR [available] = 1)

        -- Optional location filter
        AND (@location IS NULL OR [location]  = @location)

        -- Optional replica filter
        AND (@include_replicas = 1 OR [replicated] = 0)

    ORDER BY
        [location],
        [type],
        [id],
        [dbserver];
END
GO

PRINT 'Created procedure: dbo.usp_GetFlywayTargets';
GO

-- =============================================================================
-- VERIFICATION
-- Run these to validate the setup.
-- =============================================================================

-- Show all targets
EXEC dbo.usp_GetFlywayTargets;
GO

-- Show London targets only
EXEC dbo.usp_GetFlywayTargets @location = N'London';
GO

-- Show New York primaries only
EXEC dbo.usp_GetFlywayTargets @location = N'New York', @include_replicas = 0;
GO

-- Count by location
SELECT [location], COUNT(*) AS db_count
FROM dbo.jdbc_table_store
WHERE [available] = 1
GROUP BY [location]
ORDER BY [location];
GO

PRINT '=== Setup complete ===';
GO
