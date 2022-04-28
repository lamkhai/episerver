--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 0, @patch int = 15    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionProperty_SyncPublishedVersion]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersionProperty_SyncPublishedVersion]
GO
CREATE PROCEDURE [dbo].[ecfVersionProperty_SyncPublishedVersion]
	@ContentDraftProperty dbo.udttCatalogContentProperty READONLY,
	@ObjectId INT,
	@ObjectTypeId INT,
	@LanguageName NVARCHAR(20)
AS
BEGIN
	IF ((SELECT COUNT(*) FROM @ContentDraftProperty) = 0)
	BEGIN 
		DELETE [ecfVersionProperty] WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId
		RETURN
	END

	CREATE TABLE #TempProp(WorkId INT, ObjectId INT, ObjectTypeId INT, MetaFieldId INT, MetaClassId INT, MetaFieldName NVARCHAR(510), LanguageName NVARCHAR(100), Boolean BIT, Number INT, FloatNumber FLOAT,
								[Money] Money, [Decimal] Decimal(38,9), [Date] DATE, [Binary] BINARY, [String] NVARCHAR(900), LongString NVARCHAR(MAX), [Guid] UNIQUEIDENTIFIER, [IsNull] BIT) 

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		DECLARE @RowInsertedCount INT
		--update encrypted field: support only LongString field
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO #TempProp
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, @LanguageName, cdp.Boolean, cdp.Number, cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
				CASE WHEN F.IsEncrypted	= 1 THEN dbo.mdpfn_sys_EncryptDecryptString(cdp.LongString, 1) ELSE cdp.LongString END AS LongString, 
				cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd ON ccd.ObjectId = cdp.ObjectId 
										  AND ccd.ObjectTypeId = cdp.ObjectTypeId 
										  AND ccd.LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
		INNER JOIN MetaField F ON F.MetaFieldId = cdp.MetaFieldId
		WHERE ccd.[Status] = 4 --Draft properties of published version will be sync
		
		SET @RowInsertedCount = @@ROWCOUNT

		EXEC mdpsp_sys_CloseSymmetricKey
		
		IF @RowInsertedCount > 0
			BEGIN
			DELETE A 
				FROM [dbo].[ecfVersionProperty] A
				INNER JOIN #TempProp T ON A.WorkId = T.WorkId AND 
										  A.MetaFieldId = T.MetaFieldId AND
										  T.[IsNull] = 1
			END
		ELSE--return if there is no publish version
			BEGIN
			 RETURN
			END
		
	END
	ELSE
	BEGIN
		INSERT INTO #TempProp
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, @LanguageName, cdp.Boolean, cdp.Number, cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
				cdp.LongString, cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd ON ccd.ObjectId = cdp.ObjectId 
										  AND ccd.ObjectTypeId = cdp.ObjectTypeId 
										  AND ccd.LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 --Draft properties of published version will be sync

		IF @@ROWCOUNT > 0
			BEGIN
			DELETE A 
				FROM [dbo].[ecfVersionProperty] A
				INNER JOIN #TempProp T ON A.WorkId = T.WorkId AND 
									      A.MetaFieldId = T.MetaFieldId AND
										  T.[IsNull] = 1
			END
		ELSE--return if there is no publish version
			BEGIN
			 RETURN
			END
	END

	DELETE FROM #TempProp
	WHERE [IsNull] = 1

	-- update/insert items which are not in input
	MERGE	[dbo].[ecfVersionProperty] as A
	USING	#TempProp as I
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
   WHEN	NOT  MATCHED BY TARGET
		-- insert new record if the record is does not exist in ecfVersionProperty table
		THEN 
			INSERT 
				(WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES
				(I.WorkId, I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				 I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	DROP TABLE #TempProp
END
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 15, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion