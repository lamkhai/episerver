--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 0, @patch int = 9    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Creating [dbo].[CatalogItemChange]...';


GO
CREATE TABLE [dbo].[CatalogItemChange] (
    [CatalogEntryId] INT NOT NULL,
    [CatalogId]      INT NOT NULL,
    [IsBeingIndexed] BIT NOT NULL,
    CONSTRAINT [PK_CatalogItemChange] PRIMARY KEY CLUSTERED ([CatalogEntryId] ASC, [CatalogId] ASC, [IsBeingIndexed] ASC)
);


GO
PRINT N'Creating unnamed constraint on [dbo].[CatalogItemChange]...';


GO
ALTER TABLE [dbo].[CatalogItemChange]
    ADD DEFAULT (0) FOR [IsBeingIndexed];


GO
PRINT N'Creating [dbo].[CatalogItemChange_Clear]...';


GO
CREATE PROCEDURE [dbo].[CatalogItemChange_Clear]
AS
BEGIN
	TRUNCATE TABLE CatalogItemChange
END
GO
PRINT N'Creating [dbo].[CatalogItemChange_Count]...';


GO
CREATE PROCEDURE [dbo].[CatalogItemChange_Count]
@CatalogId INT
AS
BEGIN
	DELETE ci FROM CatalogItemChange ci 
  	LEFT JOIN CatalogEntry ce ON ce.CatalogEntryId = ci.CatalogEntryId
      	WHERE ce.CatalogEntryId IS NULL

	SELECT COUNT(CatalogEntryId) FROM CatalogItemChange WHERE CatalogId = @CatalogId
END
GO
PRINT N'Creating [dbo].[CatalogItemChange_Delete]...';


GO
CREATE PROCEDURE [dbo].[CatalogItemChange_Delete]
@Ids udttIdTable READONLY
AS
BEGIN
	DELETE CI FROM CatalogItemChange CI
	INNER JOIN @Ids IDS ON CI.CatalogEntryId = IDS.ID
	WHERE CI.IsBeingIndexed = 1
END
GO
PRINT N'Creating [dbo].[CatalogItemChange_Insert]...';


GO
CREATE PROCEDURE [dbo].[CatalogItemChange_Insert]
@EntryIds [udttIdTable]  READONLY
AS
BEGIN
	INSERT INTO CatalogItemChange (CatalogEntryId, CatalogId)
	SELECT
		C.ID, CE.CatalogId
	FROM @EntryIds C
	INNER JOIN CatalogEntry CE ON C.ID = CE.CatalogEntryId
	LEFT JOIN CatalogItemChange CI ON  C.ID = CI.CatalogEntryId
	WHERE CI.CatalogEntryId IS NULL OR CI.IsBeingIndexed = 1
END
GO
PRINT N'Creating [dbo].[CatalogItemChange_Load]...';


GO
CREATE PROCEDURE [dbo].[CatalogItemChange_Load]
@CatalogId INT
AS
BEGIN
	DECLARE @EntryIds [udttIdTable]
	UPDATE TOP (10000) CatalogItemChange SET IsBeingIndexed = 1
	OUTPUT inserted.CatalogEntryId INTO @EntryIds WHERE CatalogId = @CatalogId
	SELECT ID FROM @EntryIds
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 0, 9, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
