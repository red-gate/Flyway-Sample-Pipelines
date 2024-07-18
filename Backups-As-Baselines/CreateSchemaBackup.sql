-- Variables for source and cloned database names
DECLARE @SourceDB NVARCHAR(128) = N'AdventureWorks';
DECLARE @BackupDB NVARCHAR(128) = @SourceDB + N'_Schema';

-- Clone the source database schema only
DBCC CLONEDATABASE (@SourceDB, @BackupDB) WITH NO_STATISTICS, NO_QUERYSTORE, VERIFY_CLONEDB;

-- Backup the cloned database
DECLARE @BackupPath NVARCHAR(256) = N'C:\WorkingFolders\FWD\AutoRodent\backups\AutoBackup.bak';

-- Construct the BACKUP DATABASE command
DECLARE @BackupCommand NVARCHAR(MAX) = 
    N'BACKUP DATABASE [' + @BackupDB + N'] TO DISK = ''' + @BackupPath + N''' WITH INIT, FORMAT, MEDIANAME = ''SQLServerBackups'', NAME = ''Full Backup of ' + @BackupDB + N''';';

-- Execute the BACKUP DATABASE command
EXEC sp_executesql @BackupCommand;


