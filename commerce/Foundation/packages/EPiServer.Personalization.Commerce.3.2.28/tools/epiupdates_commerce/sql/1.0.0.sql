--beginvalidatingquery
IF EXISTS
(
    SELECT 1
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'dbo'
          AND TABLE_NAME = 'SchemaVersion'
)
BEGIN
    select 1,
           'Upgrading database'
END
ELSE
    select -1,
           'Not an EPiServer Commerce database'
--endvalidatingquery 
GO

IF NOT EXISTS
(
    SELECT *
    FROM dbo.sysobjects
    WHERE id = object_id(N'[dbo].[CatalogEntryChange]')
          AND OBJECTPROPERTY(id, N'IsTable') = 1
)
    CREATE TABLE [dbo].[CatalogEntryChange]
    (
        [Id] [bigint] IDENTITY(1, 1) NOT NULL,
        [EntryCode] [nvarchar](255) NOT NULL,
        CONSTRAINT [PK_CatalogEntryChange]
            PRIMARY KEY CLUSTERED ([Id] ASC)
            WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON,
                  ALLOW_PAGE_LOCKS = ON
                 ) ON [PRIMARY]
    ) ON [PRIMARY]
GO

IF EXISTS
(
    SELECT *
    FROM dbo.sysobjects
    WHERE id = object_id(N'[dbo].[ecf_CatalogEntryChange_Insert]')
          AND OBJECTPROPERTY(id, N'IsProcedure') = 1
)
    DROP PROCEDURE [dbo].[ecf_CatalogEntryChange_Insert]
GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntryChange_Insert] 
	@Changes [udttIdTable] READONLY
AS
BEGIN
    INSERT INTO CatalogEntryChange
    SELECT e.Code
    FROM CatalogEntry e
    INNER JOIN @Changes c
    ON c.ID = e.CatalogEntryId
END
GO

IF EXISTS
(
    SELECT *
    FROM dbo.sysobjects
    WHERE id = object_id(N'[dbo].[ecf_CatalogEntryChange_Delete]')
          AND OBJECTPROPERTY(id, N'IsProcedure') = 1
)
    DROP PROCEDURE [dbo].[ecf_CatalogEntryChange_Delete]
GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntryChange_Delete]
    @FromId bigint,
    @ToId bigint
AS
BEGIN
    DELETE CatalogEntryChange
    WHERE Id >= @FromId 
		  AND Id <= @ToId
END
GO

IF EXISTS
(
    SELECT *
    FROM dbo.sysobjects
    WHERE id = object_id(N'[dbo].[ecf_CatalogEntryChange_Get]')
          AND OBJECTPROPERTY(id, N'IsProcedure') = 1
)
    DROP PROCEDURE [dbo].[ecf_CatalogEntryChange_Get]
GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntryChange_Get] 
	@RecordsToRetrieve INT
AS
BEGIN
    SELECT TOP (@RecordsToRetrieve)
        Id,
        EntryCode
    FROM CatalogEntryChange
    ORDER BY Id ASC
END
GO
