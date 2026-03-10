-- =============================================================================
-- usp_GetFlywayTargets.sql
-- Example calls to the stored procedure from SSMS.
-- Run against the flyway_registry database.
-- =============================================================================

USE flyway_registry;
GO

-- All available targets, all locations
EXEC dbo.usp_GetFlywayTargets;

-- London only
EXEC dbo.usp_GetFlywayTargets @location = N'London';

-- New York, primaries only
EXEC dbo.usp_GetFlywayTargets @location = N'New York', @include_replicas = 0;

-- Tokyo, custom port
EXEC dbo.usp_GetFlywayTargets @location = N'Tokyo', @jdbc_port = 1434;

-- All locations including unavailable databases
EXEC dbo.usp_GetFlywayTargets @available_only = 0;
