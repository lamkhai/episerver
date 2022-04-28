--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 5, @patch int = 4    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionCatalog_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersionCatalog_Save] 
GO

CREATE PROCEDURE [dbo].[ecfVersionCatalog_Save]
	@VersionCatalogs dbo.[udttVersionCatalog] readonly,
	@PublishAction bit
AS
BEGIN
	DECLARE @WorkIds table (WorkId int, DefaultLanguage nvarchar(20))

	MERGE dbo.ecfVersionCatalog AS TARGET
	USING @VersionCatalogs AS SOURCE
	ON (TARGET.WorkId = SOURCE.WorkId)
	WHEN MATCHED THEN 
		UPDATE SET DefaultCurrency = SOURCE.DefaultCurrency,
				   WeightBase = SOURCE.WeightBase,
				   LengthBase = SOURCE.LengthBase,
				   DefaultLanguage = SOURCE.DefaultLanguage,
				   Languages = SOURCE.Languages,
				   IsPrimary = SOURCE.IsPrimary,
				   UriSegment = SOURCE.UriSegment,
				   [Owner] = SOURCE.[Owner]
	WHEN NOT MATCHED THEN
		INSERT (WorkId, DefaultCurrency, WeightBase, LengthBase, DefaultLanguage, Languages, IsPrimary, UriSegment, [Owner])
		VALUES (SOURCE.WorkId, SOURCE.DefaultCurrency, SOURCE.WeightBase, SOURCE.LengthBase, SOURCE.DefaultLanguage, SOURCE.Languages, SOURCE.IsPrimary, SOURCE.UriSegment, SOURCE.[Owner])
	OUTPUT inserted.WorkId, inserted.DefaultLanguage INTO @WorkIds;

	IF @PublishAction = 1
	BEGIN
		DECLARE @Catalogs udttObjectWorkId

		INSERT INTO @Catalogs
			(ObjectId, ObjectTypeId, LanguageName, WorkId)
			SELECT c.ObjectId, c.ObjectTypeId, w.DefaultLanguage, c.WorkId
			FROM ecfVersion c INNER JOIN @WorkIds w ON c.WorkId = w.WorkId
			WHERE c.ObjectTypeId = 2
		-- Note that @Catalogs.LanguageName is @WorkIds.DefaultLanguage
		
		DECLARE @CatalogId int, @MasterLanguageName nvarchar(20), @Languages nvarchar(512)
		DECLARE @ObjectIdsTemp TABLE(ObjectId INT)
		DECLARE catalogCursor CURSOR FOR SELECT DISTINCT ObjectId FROM @Catalogs
		
		OPEN catalogCursor  
		FETCH NEXT FROM catalogCursor INTO @CatalogId
		
		WHILE @@FETCH_STATUS = 0  
		BEGIN
			SELECT @MasterLanguageName = v.DefaultLanguage, @Languages = v.Languages
			FROM @VersionCatalogs v
			INNER JOIN @Catalogs c ON c.WorkId = v.WorkId
			WHERE c.ObjectId = @CatalogId
						
			-- when publishing a Catalog, we need to update all drafts to have the same DefaultLanguage as the published one.
			UPDATE d SET 
				d.DefaultLanguage = @MasterLanguageName
			FROM ecfVersionCatalog d
			INNER JOIN ecfVersion v ON d.WorkId = v.WorkId
			WHERE v.ObjectTypeId = 2 AND v.ObjectId = @CatalogId
			
			-- and also update MasterLanguageName and CurrentLanguageRemovedFlag of contents that's related to Catalog
			-- catalogs
			UPDATE v SET 
				CurrentLanguageRemoved = CASE WHEN CHARINDEX(v.LanguageName + ';', @Languages + ';') > 0 THEN 0 ELSE 1 END,
				MasterLanguageName = @MasterLanguageName
			FROM ecfVersion v
			WHERE v.ObjectTypeId = 2 AND v.ObjectId = @CatalogId
						
			--nodes
			DELETE FROM @ObjectIdsTemp
			INSERT INTO @ObjectIdsTemp
				SELECT n.CatalogNodeId
				FROM CatalogNode n
				WHERE n.CatalogId = @CatalogId

			UPDATE v SET 
				CurrentLanguageRemoved = CASE WHEN CHARINDEX(v.LanguageName + ';', @Languages + ';') > 0 THEN 0 ELSE 1 END,
				MasterLanguageName = @MasterLanguageName
			FROM ecfVersion v
			INNER JOIN @ObjectIdsTemp t ON t.ObjectId = v.ObjectId
			WHERE v.ObjectTypeId = 1
				  AND (CurrentLanguageRemoved <> CASE WHEN CHARINDEX(v.LanguageName + ';', @Languages + ';') > 0 THEN 0 ELSE 1 END
					   OR MasterLanguageName <> @MasterLanguageName)
			
			--entries
			DELETE FROM @ObjectIdsTemp
			INSERT INTO @ObjectIdsTemp
				SELECT e.CatalogEntryId
				FROM CatalogEntry e
				WHERE e.CatalogId = @CatalogId

			UPDATE v SET 
				CurrentLanguageRemoved = CASE WHEN CHARINDEX(v.LanguageName + ';', @Languages + ';') > 0 THEN 0 ELSE 1 END,
				MasterLanguageName = @MasterLanguageName
			FROM ecfVersion v
			INNER JOIN @ObjectIdsTemp t ON t.ObjectId = v.ObjectId
			WHERE v.ObjectTypeId = 0
				  AND (CurrentLanguageRemoved <> CASE WHEN CHARINDEX(v.LanguageName + ';', @Languages + ';') > 0 THEN 0 ELSE 1 END
					   OR MasterLanguageName <> @MasterLanguageName)
			
			
			FETCH NEXT FROM catalogCursor INTO @CatalogId
		END
		
		CLOSE catalogCursor  
		DEALLOCATE catalogCursor;  
	END
END
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 5, 4, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
