-- =============================================================================
-- northwind_registry_setup.sql
-- Creates the flyway_registry database with the jdbc_table_store table,
-- the usp_GetFlywayTargets stored procedure, and populates two rows
-- for Northwind (dev) and northwind_prod (prod).
--
-- Run this once in SSMS against your local SQL Server.
-- =============================================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'flyway_registry')
BEGIN
    CREATE DATABASE flyway_registry;
    PRINT 'Created database: flyway_registry';
END
GO

USE flyway_registry;
GO

-- =============================================================================
-- TABLE: jdbc_table_store
-- =============================================================================

IF OBJECT_ID(N'dbo.jdbc_table_store', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.jdbc_table_store
    (
        [entry_id]      INT             NOT NULL IDENTITY(1,1)
                                        CONSTRAINT PK_jdbc_table_store PRIMARY KEY CLUSTERED,
        [type]          NVARCHAR(10)    NOT NULL,
        [id]            NVARCHAR(50)    NOT NULL,
        [replicated]    BIT             NOT NULL DEFAULT (0),
        [name]          NVARCHAR(255)   NOT NULL,
        [dbserver]      NVARCHAR(255)   NOT NULL,
        [db]            NVARCHAR(255)   NOT NULL,
        [dbaccess]      NVARCHAR(255)   NULL,
        [odbc_driver]   NVARCHAR(255)   NULL,
        [is_dbmaster]   BIT             NOT NULL DEFAULT (0),
        [machine]       NVARCHAR(255)   NULL,
        [available]     BIT             NOT NULL DEFAULT (1),
        [location]      NVARCHAR(50)    NOT NULL,
        [is_cloud]      BIT             NOT NULL DEFAULT (0)
    );

    CREATE INDEX IX_jts_location  ON dbo.jdbc_table_store ([location]);
    CREATE INDEX IX_jts_available ON dbo.jdbc_table_store ([available]);
    CREATE INDEX IX_jts_type_id   ON dbo.jdbc_table_store ([type], [id]);
    CREATE INDEX IX_jts_server_db ON dbo.jdbc_table_store ([dbserver], [db]);

    PRINT 'Created table: dbo.jdbc_table_store';
END
GO

-- =============================================================================
-- DATA: Two Northwind targets
-- =============================================================================

-- Clear existing data (safe for fresh setup)
DELETE FROM dbo.jdbc_table_store;
GO

INSERT INTO dbo.jdbc_table_store
    ([type], [id], [replicated], [name], [dbserver], [db],
     [dbaccess], [odbc_driver], [is_dbmaster], [machine],
     [available], [location], [is_cloud])
VALUES
    ('NW', 'Northwind', 0, 'Northwind Dev',
     'localhost', 'Northwind',
     NULL, NULL, 1, 'localhost',
     1, 'Development', 0),

    ('NW', 'Northwind', 0, 'Northwind Prod',
     'localhost', 'northwind_prod',
     NULL, NULL, 0, 'localhost',
     1, 'Production', 0);
GO

PRINT 'Inserted 2 rows into jdbc_table_store';
GO

-- Verify
SELECT * FROM dbo.jdbc_table_store;
GO

-- =============================================================================
-- STORED PROCEDURE: usp_GetFlywayTargets
-- =============================================================================
-- Returns deployment targets with constructed JDBC URLs.
--
-- This replaces what the Perl script's sp_tw_db_load_all did:
--   1. Returns all target databases from the registry
--   2. Filters by location, availability, replication
--   3. Filters by database type (maps to Perl's %cvsdirtodbtype)
--   4. Constructs ready-to-use JDBC connection strings
--
-- The Python script calls this with no parameters to get ALL rows,
-- then filters further in the pipeline. Or you can filter at the DB level
-- by passing parameters.
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_GetFlywayTargets
    @location       NVARCHAR(50)  = NULL,       -- NULL = all locations
    @type           NVARCHAR(10)  = NULL,       -- NULL = all types (matches Perl's installdb=ALL)
    @available_only BIT           = 1,          -- 1 = only available DBs
    @include_replicas BIT         = 0,          -- 0 = exclude replicas (matches Perl default)
    @jdbc_port      INT           = 1433        -- port for JDBC URL construction
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        jts.[type],
        jts.[id],
        jts.[replicated],
        jts.[name],
        jts.[dbserver],
        jts.[db],
        jts.[location],
        jts.[available],
        jts.[is_dbmaster],
        jts.[machine],
        jts.[is_cloud],
        -- Constructed JDBC URL (what the Perl script built via sqlcmd connection strings)
        'jdbc:sqlserver://' + jts.[dbserver] + ':' + CAST(@jdbc_port AS VARCHAR(5))
            + ';databaseName=' + jts.[db]
            + ';encrypt=false;trustServerCertificate=true'
        AS [jdbc_url]
    FROM
        dbo.jdbc_table_store jts
    WHERE
        (@available_only = 0 OR jts.[available] = 1)
        AND (@include_replicas = 1 OR jts.[replicated] = 0)
        AND (@location IS NULL OR jts.[location] = @location)
        AND (@type IS NULL OR jts.[type] = @type)
    ORDER BY
        jts.[location],
        jts.[type],
        jts.[dbserver],
        jts.[db];
END
GO

PRINT 'Created stored procedure: dbo.usp_GetFlywayTargets';
GO

-- =============================================================================
-- Verify: run the sproc
-- =============================================================================

-- All targets
EXEC dbo.usp_GetFlywayTargets;
GO

-- Development only
EXEC dbo.usp_GetFlywayTargets @location = 'Development';
GO

-- Production only
EXEC dbo.usp_GetFlywayTargets @location = 'Production';
GO
