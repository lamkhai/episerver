--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 1, @patch int = 2    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]...';


GO
ALTER PROCEDURE [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]
	@ContentDraftProperty dbo.udttCatalogContentProperty READONLY
AS
BEGIN	
	
	DECLARE @propertyData udttCatalogContentProperty

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		--update encrypted field: support only LongString field
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO @propertyData (
			WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number,
			FloatNumber, [Money], [Decimal], [Date], [Binary], String,
			LongString,
			[Guid], [IsNull])
		SELECT
			ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, cdp.LanguageName, cdp.Boolean, cdp.Number,
			cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
			CASE WHEN cdp.IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(cdp.LongString, 1) ELSE cdp.LongString END AS LongString, 
			cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd
		ON	ccd.ObjectId = cdp.ObjectId AND
			ccd.ObjectTypeId = cdp.ObjectTypeId AND
			ccd.LanguageName = cdp.LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 OR ccd.IsCommonDraft = 1 --Draft properties of published version/common draft will be sync

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO @propertyData (
			WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number,
			FloatNumber, [Money], [Decimal], [Date], [Binary], String, LongString, [Guid], [IsNull])
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, cdp.LanguageName, cdp.Boolean, cdp.Number,
			cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, cdp.LongString, cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd
		ON	ccd.ObjectId = cdp.ObjectId AND
			ccd.ObjectTypeId = cdp.ObjectTypeId AND
			ccd.LanguageName = cdp.LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 OR ccd.IsCommonDraft = 1 --Draft properties of published version/common draft will be sync
	END

	-- delete rows where values have been nulled out
	DELETE A 
	FROM [dbo].[ecfVersionProperty] A
	INNER JOIN @propertyData T
	ON	A.WorkId = T.WorkId AND 
		A.MetaFieldId = T.MetaFieldId AND
		T.[IsNull] = 1

	-- now null rows are handled, so remove them to not insert empty rows
	DELETE FROM @propertyData
	WHERE [IsNull] = 1

	-- update/insert items which are not in input
	MERGE	[dbo].[ecfVersionProperty] as A
	USING	@propertyData as I
	ON		A.WorkId = I.WorkId AND
			A.MetaFieldId = I.MetaFieldId 
	WHEN	MATCHED 
		-- update the ecfVersionProperty for existing row
		THEN UPDATE SET 		
			A.LanguageName = I.LanguageName,	
			A.Boolean = I.Boolean, 
			A.Number = I.Number, 
			A.FloatNumber = I.FloatNumber, 
			A.[Money] = I.[Money], 
			A.[Decimal] = I.[Decimal],
			A.[Date] = I.[Date], 
			A.[Binary] = I.[Binary], 
			A.[String] = I.[String], 
			A.LongString = I.LongString, 
			A.[Guid] = I.[Guid]

	WHEN	NOT MATCHED BY TARGET 
		-- insert new record if the record is does not exist in ecfVersionProperty table
		THEN 
			INSERT (
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.WorkId, I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	--Sync version properties with version
	UPDATE [dbo].[ecfversion]
     SET [StartPublish] = I.[Date]
	FROM @PropertyData as I
	INNER JOIN [dbo].[ecfversion] E 
		ON E.[WorkId] = I.[WorkId] 
	WHERE I.[MetaFieldName] = 'Epi_StartPublish'
	 
	  
	UPDATE [dbo].[ecfversion]
     SET [StopPublish] = I.[Date]
	FROM @PropertyData as I
	INNER JOIN [dbo].[ecfversion] E
		ON E.[WorkId] = I.[WorkId]
	WHERE I.[MetaFieldName] = 'Epi_StopPublish'

	UPDATE [dbo].[ecfversion]
     SET [Status] = CASE when I.[Boolean] = 0 THEN 2
					ELSE 4 END
	FROM @PropertyData as I
	INNER JOIN [dbo].[ecfversion] E
		ON E.[WorkId] = I.[WorkId]
	WHERE I.[MetaFieldName] = 'Epi_IsPublished'

END
GO
PRINT N'Refreshing [dbo].[ecfVersion_SyncEntryData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncEntryData]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_SyncNodeData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncNodeData]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 1, 2, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
