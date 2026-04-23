-- =============================================================================
-- northwind_registry_setup.sql
-- Sets up flyway_registry on TWO servers:
--   1. QA registry  (sqlserver-dev  172.30.0.4 / localhost,1434)
--      → northwind_qa1 .. northwind_qa4
--   2. Prod registry (sqlserver-prod 172.30.0.5 / localhost,1435)
--      → northwind_prod1 .. northwind_prod4
--
-- Run each section against the appropriate server, or execute the whole
-- script twice — once per server — and the IF blocks will skip the
-- irrelevant inserts.
-- =============================================================================

-- ╔═══════════════════════════════════════════════════════════════════════════╗
-- ║  PART 1 — Common: create database, table, indexes, stored procedure     ║
-- ║  Run this on BOTH sqlserver-dev (1434) and sqlserver-prod (1435)         ║
-- ╚═══════════════════════════════════════════════════════════════════════════╝

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
-- STORED PROCEDURE: usp_GetFlywayTargets
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_GetFlywayTargets
    @location       NVARCHAR(50)  = NULL,       -- NULL = all locations
    @type           NVARCHAR(10)  = NULL,       -- NULL = all types
    @available_only BIT           = 1,          -- 1 = only available DBs
    @include_replicas BIT         = 0,          -- 0 = exclude replicas
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


-- ╔═══════════════════════════════════════════════════════════════════════════╗
-- ║  PART 2A — QA registry data                                             ║
-- ║  Run on sqlserver-dev  (172.30.0.4 / localhost,1434)                    ║
-- ╚═══════════════════════════════════════════════════════════════════════════╝

-- Clear existing data (safe for fresh setup)
DELETE FROM dbo.jdbc_table_store;
GO

INSERT INTO dbo.jdbc_table_store
    ([type], [id], [replicated], [name], [dbserver], [db],
     [dbaccess], [odbc_driver], [is_dbmaster], [machine],
     [available], [location], [is_cloud])
VALUES
    ('NW', 'Northwind', 0, 'Northwind QA 1',
     '172.30.0.4', 'northwind_qa1',
     NULL, NULL, 1, 'sqlserver-dev',
     1, 'London', 0),

    ('NW', 'Northwind', 0, 'Northwind QA 2',
     '172.30.0.4', 'northwind_qa2',
     NULL, NULL, 0, 'sqlserver-dev',
     1, 'New York', 0),

    ('NW', 'Northwind', 0, 'Northwind QA 3',
     '172.30.0.4', 'northwind_qa3',
     NULL, NULL, 0, 'sqlserver-dev',
     1, 'Tokyo', 0),

    ('NW', 'Northwind', 0, 'Northwind QA 4',
     '172.30.0.4', 'northwind_qa4',
     NULL, NULL, 0, 'sqlserver-dev',
     1, 'London', 0);
GO

PRINT 'Inserted QA rows into jdbc_table_store';
GO


-- ╔═══════════════════════════════════════════════════════════════════════════╗
-- ║  PART 2B — Prod registry data                                           ║
-- ║  Run on sqlserver-prod (172.30.0.5 / localhost,1435)                    ║
-- ╚═══════════════════════════════════════════════════════════════════════════╝

-- To set up the PROD registry instead, comment out Part 2A above and
-- uncomment this block (or run it separately against sqlserver-prod).

-- DELETE FROM dbo.jdbc_table_store;
-- GO

-- INSERT INTO dbo.jdbc_table_store
--     ([type], [id], [replicated], [name], [dbserver], [db],
--      [dbaccess], [odbc_driver], [is_dbmaster], [machine],
--      [available], [location], [is_cloud])
-- VALUES
--     ('NW', 'Northwind', 0, 'Northwind Prod 1',
--      '172.30.0.5', 'northwind_prod1',
--      NULL, NULL, 1, 'sqlserver-prod',
--      1, 'London', 0),
--
--     ('NW', 'Northwind', 0, 'Northwind Prod 2',
--      '172.30.0.5', 'northwind_prod2',
--      NULL, NULL, 0, 'sqlserver-prod',
--      1, 'New York', 0),
--
--     ('NW', 'Northwind', 0, 'Northwind Prod 3',
--      '172.30.0.5', 'northwind_prod3',
--      NULL, NULL, 0, 'sqlserver-prod',
--      1, 'Tokyo', 0),
--
--     ('NW', 'Northwind', 0, 'Northwind Prod 4',
--      '172.30.0.5', 'northwind_prod4',
--      NULL, NULL, 0, 'sqlserver-prod',
--      1, 'London', 0);
-- GO
--
-- PRINT 'Inserted Prod rows into jdbc_table_store';
-- GO


-- =============================================================================
-- VERIFICATION
-- =============================================================================

SELECT * FROM dbo.jdbc_table_store;
GO

EXEC dbo.usp_GetFlywayTargets;
GO
