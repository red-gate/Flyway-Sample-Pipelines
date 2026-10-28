CREATE TABLE [dbo].[Orders]
(
[OrderID] [int] NOT NULL IDENTITY(1, 1),
[CustomerID] [nchar] (5) NULL,
[EmployeeID] [int] NULL,
[OrderDate] [datetime] NULL,
[RequiredDate] [datetime] NULL,
[ShippedDate] [datetime] NULL,
[ShipVia] [int] NULL,
[Freight] [money] NULL CONSTRAINT [DF_Orders_Freight] DEFAULT ((0)),
[ShipName] [nvarchar] (40) NULL,
[ShipAddress] [nvarchar] (60) NULL,
[ShipCity] [nvarchar] (15) NULL,
[ShipRegion] [nvarchar] (15) NULL,
[ShipPostalCode] [nvarchar] (10) NULL,
[ShipCountry] [nvarchar] (15) NULL
)
GO
ALTER TABLE [dbo].[Orders] ADD CONSTRAINT [PK_Orders] PRIMARY KEY CLUSTERED ([OrderID])
GO
CREATE NONCLUSTERED INDEX [CustomerID] ON [dbo].[Orders] ([CustomerID])
GO
CREATE NONCLUSTERED INDEX [CustomersOrders] ON [dbo].[Orders] ([CustomerID])
GO
CREATE NONCLUSTERED INDEX [EmployeeID] ON [dbo].[Orders] ([EmployeeID])
GO
CREATE NONCLUSTERED INDEX [EmployeesOrders] ON [dbo].[Orders] ([EmployeeID])
GO
CREATE NONCLUSTERED INDEX [OrderDate] ON [dbo].[Orders] ([OrderDate])
GO
CREATE NONCLUSTERED INDEX [ShippedDate] ON [dbo].[Orders] ([ShippedDate])
GO
CREATE NONCLUSTERED INDEX [ShipPostalCode] ON [dbo].[Orders] ([ShipPostalCode])
GO
CREATE NONCLUSTERED INDEX [ShippersOrders] ON [dbo].[Orders] ([ShipVia])
GO
ALTER TABLE [dbo].[Orders] ADD CONSTRAINT [FK_Orders_Customers] FOREIGN KEY ([CustomerID]) REFERENCES [dbo].[Customers] ([CustomerID])
GO
ALTER TABLE [dbo].[Orders] ADD CONSTRAINT [FK_Orders_Employees] FOREIGN KEY ([EmployeeID]) REFERENCES [dbo].[Employees] ([EmployeeID])
GO
ALTER TABLE [dbo].[Orders] ADD CONSTRAINT [FK_Orders_Shippers] FOREIGN KEY ([ShipVia]) REFERENCES [dbo].[Shippers] ([ShipperID])
GO
