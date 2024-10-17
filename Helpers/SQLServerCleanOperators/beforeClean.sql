
-- Remove system versioning

DECLARE
  @schema VARCHAR(50)
, @table VARCHAR(100)
, @sql NVARCHAR(MAX) = N'';
DECLARE cursTemporalTables CURSOR FAST_FORWARD READ_ONLY FOR
SELECT
  SCHEMA_NAME (t.schema_id) AS temporal_table_schema
, t.name AS temporal_table_name
FROM
  sys.tables t
  LEFT OUTER JOIN sys.tables h
    ON t.history_table_id = h.object_id
WHERE t.temporal_type = 2
ORDER BY
  temporal_table_schema
, temporal_table_name;
OPEN cursTemporalTables;
FETCH NEXT FROM cursTemporalTables
INTO
  @schema
, @table;
WHILE @@FETCH_STATUS = 0
BEGIN
  SELECT @sql += N'ALTER TABLE ' + src + N' SET (SYSTEM_VERSIONING = OFF);
    
    DROP TABLE ' + hist + N';'
  FROM
    ( SELECT
        src = QUOTENAME (SCHEMA_NAME (t.schema_id)) + N'.' + QUOTENAME (t.name)
      , hist = QUOTENAME (SCHEMA_NAME (h.schema_id)) + N'.' + QUOTENAME (h.name)
      FROM
        sys.tables AS t
        INNER JOIN sys.tables AS h
          ON t.history_table_id = h.[object_id]
      WHERE
        t.temporal_type   = 2
        AND t.[schema_id] = SCHEMA_ID (@schema)
        AND t.name        = @table) AS x;
  EXEC sys.sp_executesql @sql;
  FETCH NEXT FROM cursTemporalTables
  INTO
    @schema
  , @table;
END;
CLOSE cursTemporalTables;
DEALLOCATE cursTemporalTables;
