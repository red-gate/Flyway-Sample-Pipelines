CREATE TABLE [dbo].[EmployeeTerritories]
(
[EmployeeID] [int] NOT NULL,
[TerritoryID] [nvarchar] (20) NOT NULL
)
GO
ALTER TABLE [dbo].[EmployeeTerritories] ADD CONSTRAINT [PK_EmployeeTerritories] PRIMARY KEY NONCLUSTERED ([EmployeeID], [TerritoryID])
GO
ALTER TABLE [dbo].[EmployeeTerritories] ADD CONSTRAINT [FK_EmployeeTerritories_Employees] FOREIGN KEY ([EmployeeID]) REFERENCES [dbo].[Employees] ([EmployeeID])
GO
ALTER TABLE [dbo].[EmployeeTerritories] ADD CONSTRAINT [FK_EmployeeTerritories_Territories] FOREIGN KEY ([TerritoryID]) REFERENCES [dbo].[Territories] ([TerritoryID])
GO
