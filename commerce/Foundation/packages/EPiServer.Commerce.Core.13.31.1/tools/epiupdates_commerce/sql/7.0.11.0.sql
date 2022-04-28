--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 0, @patch int = 11    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

-- modifying stored procedure ecfVersion_UpdateCurrentLanguageRemoved
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_UpdateCurrentLanguageRemoved]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersion_UpdateCurrentLanguageRemoved]
GO

CREATE PROCEDURE [dbo].[ecfVersion_UpdateCurrentLanguageRemoved]
	@ObjectId			int,
	@ObjectTypeId		int
AS
BEGIN
	CREATE TABLE #RecursiveContents (ObjectId INT, ObjectTypeId INT)
	DECLARE @catalogId INT

	-- in case node content
	IF @ObjectTypeId = 1 
	BEGIN
		-- Get all nodes and entries under the @objectId
		DECLARE @catalogNodeIds udttCatalogNodeList
		INSERT INTO @catalogNodeIds VALUES (@ObjectId)

		DECLARE @hierarchy udttCatalogNodeList
		INSERT @hierarchy EXEC ecf_CatalogNode_GetAllChildNodes @catalogNodeIds

		INSERT INTO #RecursiveContents (ObjectId, ObjectTypeId) SELECT CatalogNodeId, 1 FROM @hierarchy

		INSERT INTO #RecursiveContents (ObjectId, ObjectTypeId)
		SELECT DISTINCT ce.CatalogEntryId, 0
		FROM CatalogEntry ce
		INNER JOIN NodeEntryRelation ner ON ce.CatalogEntryId = ner.CatalogEntryId
		INNER JOIN @hierarchy h ON h.CatalogNodeId = ner.CatalogNodeId

		-- get CatalogId from node content
		SELECT @catalogId = CatalogId FROM CatalogNode WHERE CatalogNodeId = @ObjectId
	END
	ELSE
	BEGIN
		-- in case entry content, just update for only entry
		INSERT INTO #RecursiveContents (ObjectId, ObjectTypeId)
		VALUES (@ObjectId, @ObjectTypeId)

		-- get CatalogId from entry content
		SELECT @catalogId = CatalogId FROM CatalogEntry WHERE CatalogEntryId = @ObjectId
	END

	UPDATE v
	SET		CurrentLanguageRemoved = CASE WHEN cl.LanguageCode = v.LanguageName COLLATE DATABASE_DEFAULT THEN 0 ELSE 1 END
	FROM	ecfVersion v
	INNER JOIN #RecursiveContents r 
				ON r.ObjectId = v.ObjectId and r.ObjectTypeId = v.ObjectTypeId
	LEFT JOIN CatalogLanguage cl ON v.LanguageName = cl.LanguageCode AND cl.CatalogId = @catalogId

	DROP TABLE #RecursiveContents
END
GO
-- end modifying stored procedure ecfVersion_UpdateCurrentLanguageRemoved

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 11, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
