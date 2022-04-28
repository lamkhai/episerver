--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 19    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Dropping [dbo].[FK_ShippingCountry_Country]...';


GO
ALTER TABLE [dbo].[ShippingCountry] DROP CONSTRAINT [FK_ShippingCountry_Country];


GO
PRINT N'Dropping [dbo].[FK_StateProvince_Country]...';


GO
ALTER TABLE [dbo].[StateProvince] DROP CONSTRAINT [FK_StateProvince_Country];


GO
PRINT N'Dropping [dbo].[mc_OrderGroupNotesUpdate]...';


GO
DROP PROCEDURE [dbo].[mc_OrderGroupNotesUpdate];


GO
PRINT N'Dropping [dbo].[udttOrderGroupNote]...';


GO
DROP TYPE [dbo].[udttOrderGroupNote];


GO
PRINT N'Creating [dbo].[udttOrderGroupNote]...';


GO
CREATE TYPE [dbo].[udttOrderGroupNote] AS TABLE (
    [OrderNoteId]  INT              NULL,
    [OrderGroupId] INT              NOT NULL,
    [CustomerId]   UNIQUEIDENTIFIER NOT NULL,
    [Title]        NVARCHAR (255)   NULL,
    [Type]         NVARCHAR (50)    NULL,
    [Detail]       NTEXT            NULL,
    [Created]      DATETIME         NOT NULL,
    [LineItemId]   INT              NULL,
    [IsModified]   BIT              NOT NULL);


GO
PRINT N'Starting rebuilding table [dbo].[Country]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_Country] (
    [CountryId] INT            IDENTITY (1, 1) NOT NULL,
    [Name]      NVARCHAR (100) NULL,
    [Ordering]  INT            NULL,
    [Visible]   BIT            NULL,
    [Code]      NVARCHAR (3)   NULL,
    CONSTRAINT [tmp_ms_xx_constraint_Country_PK1] PRIMARY KEY NONCLUSTERED ([CountryId] ASC)
);

CREATE CLUSTERED INDEX [tmp_ms_xx_index_IX_Country_Code1]
    ON [dbo].[tmp_ms_xx_Country]([Code] ASC);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[Country])
    BEGIN
        SET IDENTITY_INSERT [dbo].[tmp_ms_xx_Country] ON;
        INSERT INTO [dbo].[tmp_ms_xx_Country] ([Code], [CountryId], [Name], [Ordering], [Visible])
        SELECT   [Code],
                 [CountryId],
                 [Name],
                 [Ordering],
                 [Visible]
        FROM     [dbo].[Country]
        ORDER BY [Code] ASC;
        SET IDENTITY_INSERT [dbo].[tmp_ms_xx_Country] OFF;
    END

DROP TABLE [dbo].[Country];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_Country]', N'Country';

EXECUTE sp_rename N'[dbo].[Country].[tmp_ms_xx_index_IX_Country_Code1]', N'IX_Country_Code', N'INDEX';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_Country_PK1]', N'Country_PK', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Creating [dbo].[FK_ShippingCountry_Country]...';


GO
ALTER TABLE [dbo].[ShippingCountry] WITH NOCHECK
    ADD CONSTRAINT [FK_ShippingCountry_Country] FOREIGN KEY ([CountryId]) REFERENCES [dbo].[Country] ([CountryId]);


GO
PRINT N'Creating [dbo].[FK_StateProvince_Country]...';


GO
ALTER TABLE [dbo].[StateProvince] WITH NOCHECK
    ADD CONSTRAINT [FK_StateProvince_Country] FOREIGN KEY ([CountryId]) REFERENCES [dbo].[Country] ([CountryId]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating [dbo].[mc_OrderGroupNotesUpdate]...';


GO
CREATE PROCEDURE [dbo].[mc_OrderGroupNotesUpdate]
@OrderGroupId int,
@OrderGroupNotes udttOrderGroupNote readonly
AS
BEGIN
SET NOCOUNT ON;

;WITH CTE AS
(SELECT * FROM dbo.OrderGroupNote 
WHERE OrderGroupId = @OrderGroupId)

MERGE CTE AS T
USING @OrderGroupNotes AS S
ON T.OrderNoteId = S.OrderNoteId

WHEN NOT MATCHED BY TARGET
	THEN INSERT (
		[OrderGroupId],
		[CustomerId],
		[Title],
		[Type],
		[Detail],
		[Created],
		[LineItemId])
	VALUES(S.OrderGroupId,
		S.CustomerId,
		S.Title,
		S.Type,
		S.Detail,
		S.Created,
		S.LineItemId)
WHEN NOT MATCHED BY SOURCE
	THEN DELETE
WHEN MATCHED AND (S.IsModified = 1) THEN 
UPDATE SET
	[OrderGroupId] = S.OrderGroupId,
	[CustomerId] = S.CustomerId,
	[Title] = S.Title,
	[Type] = S.Type,
	[Detail] = S.Detail,
	[Created] = S.Created,
	[LineItemId] = S.LineItemId;
END
GO
PRINT N'Refreshing [dbo].[ecf_Country]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Country]';


GO
PRINT N'Refreshing [dbo].[ecf_Country_Code]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Country_Code]';


GO
PRINT N'Refreshing [dbo].[ecf_Country_CountryId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Country_CountryId]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 19, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
