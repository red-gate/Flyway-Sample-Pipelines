-- Support for multiple schema names; drop all table constraints
--------------------------------------------------
declare @name varchar(100)
declare @table varchar(100)
declare @schema varchar(100)

-- Drop all table constraints: this goes through alter table

declare c cursor for
	select a.name as [constraint], b.name as [table], OBJECT_SCHEMA_NAME(b.id) as [schema]
		from dbo.sysobjects a
		inner join dbo.sysobjects b on a.parent_obj = b.id
		where a.xtype in ('F','D','C','UQ') and b.xtype='U'
open c
fetch next from c into @name, @table, @schema
while @@FETCH_STATUS = 0
begin
	exec ('alter table [' + @schema + '].[' + @table + '] drop constraint [' + @name + ']')
	fetch next from c into @name, @table, @schema
end
close c
deallocate c

GO

if exists (select * from dbo.sysobjects where name='TestFramework_DropAll' and xtype='P')
	drop procedure TestFramework_DropAll

GO

create procedure TestFramework_DropAll (@xtype varchar(2), @drop varchar(20))
as
begin
	declare @name varchar(100), @id bigint, @schema varchar(100)
	declare c cursor for select name, id, OBJECT_SCHEMA_NAME(id) from dbo.sysobjects where xtype=@xtype
	open c
	fetch next from c into @name, @id, @schema
	while @@FETCH_STATUS = 0
	begin
		if @name != 'TestFramework_DropAll' and @schema != 'sys'
			exec ('DROP ' + @drop + ' [' + @schema + '].[' + @name + ']')
		fetch next from c into @name, @id, @schema
	end
	close c
	deallocate c
end

GO

-- Drop stuff in this order to avoid dependency errors

exec TestFramework_DropAll 'V', 'view'
GO
exec TestFramework_DropAll 'FN', 'function'
GO
exec TestFramework_DropAll 'IF', 'function'
GO
exec TestFramework_DropAll 'TF', 'function'
GO
exec TestFramework_DropAll 'U', 'table'
GO
exec TestFramework_DropAll 'P', 'procedure'
GO


-- User defined types are a special case as they are not listed in sysobjects

declare c cursor for
	select name from sys.types where is_user_defined=1
declare @name varchar(100)
open c
fetch next from c into @name
while @@FETCH_STATUS = 0
begin
	exec ('drop type [' + @name + ']')
	fetch next from c into @name
end
close c
deallocate c

GO


-- Drop schemas except for standard/built-in ones

declare c cursor for
	select name from sys.schemas where name not in ('dbo','guest','INFORMATION_SCHEMA','sys')
declare @name varchar(100)
open c
fetch next from c into @name
while @@FETCH_STATUS = 0
begin
	exec ('drop schema [' + @name + ']')
	fetch next from c into @name
end
close c
deallocate c

GO


exec TestFramework_DropAll 'D', 'default'
GO


drop procedure TestFramework_DropAll

GO
