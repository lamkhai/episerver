--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 9, @minor int = 1, @patch int = 2    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Dropping [dbo].[CatalogContentEx].[IDX_CatalogContentEx_Indexed_Ids]...';


GO
DROP INDEX [IDX_CatalogContentEx_Indexed_Ids]
    ON [dbo].[CatalogContentEx];


GO
PRINT N'Starting rebuilding table [dbo].[CatalogContentEx]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_CatalogContentEx] (
    [ObjectId]     INT            NOT NULL,
    [ObjectTypeId] INT            NOT NULL,
    [CreatedBy]    NVARCHAR (256) NULL,
    [Created]      DATETIME       NULL,
    [ModifiedBy]   NVARCHAR (256) NULL,
    [Modified]     DATETIME       NULL,
    CONSTRAINT [tmp_ms_xx_constraint_PK_CatalogContentEx1] PRIMARY KEY CLUSTERED ([ObjectId] ASC, [ObjectTypeId] ASC)
);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[CatalogContentEx])
    BEGIN
        INSERT INTO [dbo].[tmp_ms_xx_CatalogContentEx] ([ObjectId], [ObjectTypeId], [CreatedBy], [Created], [ModifiedBy], [Modified])
        SELECT   [ObjectId],
                 [ObjectTypeId],
                 [CreatedBy],
                 [Created],
                 [ModifiedBy],
                 [Modified]
        FROM     [dbo].[CatalogContentEx]
        ORDER BY [ObjectId] ASC, [ObjectTypeId] ASC;
    END

DROP TABLE [dbo].[CatalogContentEx];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_CatalogContentEx]', N'CatalogContentEx';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_CatalogContentEx1]', N'PK_CatalogContentEx', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Altering [dbo].[ecfVersion_UpdateVersionsMasterLanguage]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_UpdateVersionsMasterLanguage]
	@Objects dbo.udttObjectWorkId READONLY
AS
BEGIN
	DECLARE @temp TABLE(ObjectId INT, ObjectTypeId INT, CatalogId INT, MasterLanguage NVARCHAR(40))

	INSERT INTO @temp (ObjectId, ObjectTypeId, CatalogId, MasterLanguage)
	SELECT e.CatalogEntryId ObjectId, o.ObjectTypeId, e.CatalogId, c.DefaultLanguage FROM CatalogEntry e
	INNER JOIN @Objects o ON e.CatalogEntryId = o.ObjectId and o.ObjectTypeId = 0
	INNER JOIN Catalog c ON c.CatalogId = e.CatalogId
	UNION ALL
	SELECT n.CatalogNodeId ObjectId, o.ObjectTypeId, n.CatalogId, c.DefaultLanguage FROM CatalogNode n
	INNER JOIN @Objects o ON n.CatalogNodeId = o.ObjectId and o.ObjectTypeId = 1
	INNER JOIN Catalog c ON c.CatalogId = n.CatalogId

	DECLARE @oldWorkIds TABLE (WorkId INT, ObjectId INT, ObjectTypeId INT, LanguageName NVARCHAR(40), MasterLanguage NVARCHAR(40))

	UPDATE v
	SET
		MasterLanguageName = t.MasterLanguage,
		CatalogId = t.CatalogId
		OUTPUT deleted.WorkId, deleted.ObjectId, deleted.ObjectTypeId, deleted.LanguageName, deleted.MasterLanguageName
		INTO @oldWorkIds
	FROM ecfVersion v
	INNER JOIN @temp t ON t.ObjectId = v.ObjectId AND t.ObjectTypeId = v.ObjectTypeId

	-- update ecfVersionAsset with new workIds master language
	UPDATE va
	SET va.WorkId = v.WorkId
	FROM ecfVersionAsset va
	INNER JOIN @oldWorkIds o ON o.WorkId = va.WorkId AND o.LanguageName = o.MasterLanguage COLLATE DATABASE_DEFAULT
	INNER JOIN ecfVersion v ON v.ObjectId = o.ObjectId AND v.ObjectTypeId = o.ObjectTypeId AND v.LanguageName = v.MasterLanguageName COLLATE DATABASE_DEFAULT
END
GO
PRINT N'Creating [dbo].[ecfVersionAsset_InsertForMasterLanguage]...';


GO
CREATE PROCEDURE [dbo].[ecfVersionAsset_InsertForMasterLanguage]
	@CatalogId INT
AS
BEGIN
	DELETE a
	FROM ecfVersionAsset a
	INNER JOIN ecfVersion v on a.WorkId = v.WorkId
	WHERE v.LanguageName <> v.MasterLanguageName AND v.CatalogId = @CatalogId

	INSERT INTO ecfVersionAsset
	SELECT v.WorkId, a.AssetType, a.AssetKey, a.GroupName, a.SortOrder
	FROM ecfVersion v
		INNER JOIN CatalogItemAsset a ON (v.ObjectId = a.CatalogEntryId AND v.ObjectTypeId = 0)
	WHERE v.LanguageName = v.MasterLanguageName COLLATE DATABASE_DEFAULT AND v.CatalogId = @CatalogId
		AND (v.Status = 4 OR v.IsCommonDraft = 1)

	INSERT INTO ecfVersionAsset
	SELECT v.WorkId, a.AssetType, a.AssetKey, a.GroupName, a.SortOrder
	FROM ecfVersion v
		INNER JOIN CatalogItemAsset a ON (v.ObjectId = a.CatalogNodeId AND v.ObjectTypeId = 1)
	WHERE v.LanguageName = v.MasterLanguageName COLLATE DATABASE_DEFAULT AND v.CatalogId = @CatalogId
		AND (v.Status = 4 OR v.IsCommonDraft = 1)
END
GO
PRINT N'Refreshing [dbo].[CatalogContentEx_Load]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentEx_Load]';


GO
PRINT N'Refreshing [dbo].[CatalogContentEx_Save]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentEx_Save]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_LoadBatch]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_LoadBatch]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_Load]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_Load]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_LoadAllLanguages]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_LoadAllLanguages]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_Migrate]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_Migrate]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_Save]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_Save]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(9, 1, 2, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
