-- =============================================================================
-- create_usp_GetFlywayTargets.sql
-- Run in SSMS against the flyway_registry database to create the stored
-- procedure used by the GitLab pipeline to retrieve deployment targets.
-- =============================================================================

USE flyway_registry;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetFlywayTargets
    @location         NVARCHAR(50) = NULL,  -- NULL = all locations
    @available_only   BIT          = 1,     -- 1 = skip unavailable databases
    @jdbc_port        INT          = 1433,  -- embedded in returned jdbc_url
    @include_replicas BIT          = 1      -- 0 = primaries only
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

        -- Ready-to-use JDBC connection string for Flyway
        N'jdbc:sqlserver://' + [dbserver]
            + N':' + CAST(@jdbc_port AS NVARCHAR(10))
            + N';databaseName=' + [db]
            + N';encrypt=false;trustServerCertificate=true'
            AS [jdbc_url]

    FROM
        dbo.jdbc_table_store

    WHERE
        (@available_only   = 0 OR [available]  = 1)
        AND (@location     IS NULL OR [location]   = @location)
        AND (@include_replicas = 1 OR [replicated] = 0)

    ORDER BY
        [location],
        [type],
        [id],
        [dbserver];
END
GO

PRINT 'usp_GetFlywayTargets created successfully.';
