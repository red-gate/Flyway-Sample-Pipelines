CREATE TABLE [dbo].[Employees]
(
[EmployeeID] [int] NOT NULL IDENTITY(1, 1),
[LastName] [nvarchar] (20) NOT NULL,
[FirstName] [nvarchar] (10) NOT NULL,
[Title] [nvarchar] (30) NULL,
[TitleOfCourtesy] [nvarchar] (25) NULL,
[BirthDate] [datetime] NULL,
[HireDate] [datetime] NULL,
[Address] [nvarchar] (60) NULL,
[City] [nvarchar] (15) NULL,
[Region] [nvarchar] (15) NULL,
[PostalCode] [nvarchar] (10) NULL,
[Country] [nvarchar] (15) NULL,
[HomePhone] [nvarchar] (24) NULL,
[Extension] [nvarchar] (4) NULL,
[Photo] [image] NULL,
[Notes] [ntext] NULL,
[ReportsTo] [int] NULL,
[PhotoPath] [nvarchar] (255) NULL
)
GO
ALTER TABLE [dbo].[Employees] ADD CONSTRAINT [CK_Birthdate] CHECK (([BirthDate]<getdate()))
GO
ALTER TABLE [dbo].[Employees] ADD CONSTRAINT [PK_Employees] PRIMARY KEY CLUSTERED ([EmployeeID])
GO
CREATE NONCLUSTERED INDEX [LastName] ON [dbo].[Employees] ([LastName])
GO
CREATE NONCLUSTERED INDEX [PostalCode] ON [dbo].[Employees] ([PostalCode])
GO
ALTER TABLE [dbo].[Employees] ADD CONSTRAINT [FK_Employees_Employees] FOREIGN KEY ([ReportsTo]) REFERENCES [dbo].[Employees] ([EmployeeID])
GO
