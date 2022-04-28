--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 23    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[CatalogContentProperty_SaveBatch]...';


GO

ALTER PROCEDURE [dbo].[CatalogContentProperty_SaveBatch]
	@ContentProperty dbo.udttCatalogContentProperty readonly,
	@Data dbo.[udttCatalogContentEx] readonly,
	@SyncVersion bit = 1
AS
BEGIN
	--delete items which are not in input
	DELETE A
	FROM [dbo].[CatalogContentProperty] A
	INNER JOIN @ContentProperty I
	ON	A.ObjectId = I.ObjectId AND
		A.ObjectTypeId = I.ObjectTypeId AND
		LOWER(A.LanguageName) = LOWER(I.LanguageName) COLLATE DATABASE_DEFAULT AND
		A.MetaFieldId = I.MetaFieldId
	WHERE I.[IsNull] = 1

	--update encrypted field: support only LongString field
	DECLARE @propertyData dbo.udttCatalogContentProperty

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
		BEGIN
			EXEC mdpsp_sys_OpenSymmetricKey

			INSERT INTO @propertyData (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String],
				LongString,
				[Guid])
			SELECT
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String],
				CASE WHEN IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(LongString, 1) ELSE LongString END AS LongString,
				[Guid]
			FROM @ContentProperty
			WHERE [IsNull] = 0

			EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
			INSERT INTO @propertyData (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			SELECT
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid]
			FROM @ContentProperty
			WHERE [IsNull] = 0
		END

	-- update/insert items which are not in input
	MERGE	[dbo].[CatalogContentProperty] as A
	USING	@propertyData as I
	ON		A.ObjectId = I.ObjectId AND
			A.ObjectTypeId = I.ObjectTypeId AND
			A.MetaFieldId = I.MetaFieldId AND
			LOWER(A.LanguageName) = LOWER(I.LanguageName) COLLATE DATABASE_DEFAULT
	WHEN	MATCHED
		-- update the CatalogContentProperty for existing row
		THEN UPDATE SET
			A.MetaClassId = I.MetaClassId,
			A.MetaFieldName = I.MetaFieldName,
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

	WHEN NOT MATCHED BY TARGET
		-- insert new record if the record does not exist in CatalogContentProperty table
		THEN
			INSERT (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.CultureSpecific, I.Boolean, I.Number,
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	-- Update ecfVersionProperty
	IF (@SyncVersion = 1)
	BEGIN
		EXEC ecfVersionProperty_SyncBatchPublishedVersion @ContentProperty
	END

	-- Update CatalogContentEx
	EXEC CatalogContentEx_Save @Data
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 23, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
