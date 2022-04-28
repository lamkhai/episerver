--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 1    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[CatalogContentProperty_Load]...';


GO
ALTER PROCEDURE [dbo].[CatalogContentProperty_Load]
	@ObjectId int,
	@ObjectTypeId int,
	@MetaClassId int,
	@Language nvarchar(50)
AS
BEGIN
	DECLARE @catalogId INT
	DECLARE @FallbackLanguage nvarchar(50)

	SET @catalogId = CASE WHEN @ObjectTypeId = 0 THEN
							(SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @ObjectId)
							WHEN @ObjectTypeId = 1 THEN							
							(SELECT CatalogId FROM CatalogNode WHERE CatalogNodeId = @ObjectId)
						END
	SELECT @FallbackLanguage = DefaultLanguage FROM dbo.[Catalog] WHERE CatalogId = @catalogId

	-- load from fallback language only if @Language is not existing language of catalog.
	-- in other work, fallback language is used for invalid @Language value only.
	IF @Language NOT IN (SELECT LanguageCode FROM dbo.CatalogLanguage WHERE CatalogId = @catalogId)
		SET @Language = @FallbackLanguage
    
	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 --Fields will be encrypted only when DB does not support Azure
		BEGIN
		EXEC mdpsp_sys_OpenSymmetricKey

		SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
							P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], 
							CASE WHEN (F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1 )
							THEN dbo.mdpfn_sys_EncryptDecryptString(P.LongString, 0) 
							ELSE P.LongString END AS LongString, 
							P.[Guid]  
		FROM dbo.CatalogContentProperty P
		INNER JOIN MetaField F ON P.MetaFieldId = F.MetaFieldId
		WHERE ObjectId = @ObjectId AND
				ObjectTypeId = @ObjectTypeId AND
				MetaClassId = @MetaClassId AND
				((F.MultiLanguageValue = 1 AND LanguageName = @Language COLLATE DATABASE_DEFAULT) OR ((F.MultiLanguageValue = 0 AND LanguageName = @FallbackLanguage COLLATE DATABASE_DEFAULT)))

		EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
		SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
							P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], 
							P.LongString, 
							P.[Guid]
		FROM dbo.CatalogContentProperty P
		WHERE ObjectId = @ObjectId AND
				ObjectTypeId = @ObjectTypeId AND
				MetaClassId = @MetaClassId AND
				((P.CultureSpecific = 1 AND LanguageName = @Language COLLATE DATABASE_DEFAULT) OR ((P.CultureSpecific = 0 AND LanguageName = @FallbackLanguage COLLATE DATABASE_DEFAULT)))
		END

	-- Select CatalogContentEx data
	EXEC CatalogContentEx_Load @ObjectId, @ObjectTypeId
END
GO
PRINT N'Altering [dbo].[ecfVersionProperty_ListByWorkIds]...';


GO
ALTER PROCEDURE [dbo].[ecfVersionProperty_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	CREATE TABLE #nonMasterLinks (
		ObjectId INT, 
		ObjectTypeId INT, 
		WorkId INT,
		MasterWorkId INT
	)

	INSERT INTO #nonMasterLinks
	SELECT l.ObjectId, l.ObjectTypeId, l.WorkId, NULL
	FROM @ContentLinks l
	INNER JOIN ecfVersion d ON l.WorkId = d.WorkId
	WHERE d.LanguageName <> d.MasterLanguageName COLLATE DATABASE_DEFAULT

	UPDATE l SET MasterWorkId = d.WorkId
	FROM #nonMasterLinks l
	INNER JOIN ecfVersion d ON d.ObjectId = l.ObjectId AND d.ObjectTypeId = l.ObjectTypeId
	WHERE d.[Status] = 4 AND d.LanguageName = d.MasterLanguageName COLLATE DATABASE_DEFAULT

	DECLARE @IsAzureCompatible BIT
	SET @IsAzureCompatible = dbo.mdpfn_sys_IsAzureCompatible()

	IF @IsAzureCompatible = 1
	BEGIN

		-- select property for draft that is master language one or multi language property
		SELECT links.WorkId, draftProperty.ObjectId, draftProperty.ObjectTypeId, draftProperty.MetaFieldId, draftProperty.MetaClassId, draftProperty.MetaFieldName, draftProperty.LanguageName,
				draftProperty.[Boolean], draftProperty.[Number], draftProperty.[FloatNumber], draftProperty.[Money], draftProperty.[Decimal], draftProperty.[Date], draftProperty.[Binary], draftProperty.[String], 
				draftProperty.[LongString], 
				draftProperty.[Guid]
		FROM ecfVersionProperty draftProperty
		INNER JOIN @ContentLinks links ON links.WorkId = draftProperty.WorkId
		
		-- and fall back property
		UNION ALL
		SELECT links.WorkId, draftProperty.ObjectId, draftProperty.ObjectTypeId, draftProperty.MetaFieldId, draftProperty.MetaClassId, draftProperty.MetaFieldName, draftProperty.LanguageName,
				draftProperty.[Boolean], draftProperty.[Number], draftProperty.[FloatNumber], draftProperty.[Money], draftProperty.[Decimal], draftProperty.[Date], draftProperty.[Binary], draftProperty.[String], 
                draftProperty.LongString, 
				draftProperty.[Guid]
		FROM ecfVersionProperty draftProperty
		INNER JOIN #nonMasterLinks links ON links.MasterWorkId = draftProperty.WorkId
		WHERE draftProperty.CultureSpecific = 0

	END
	ELSE
	BEGIN
		-- Open and Close SymmetricKey do nothing if the system does not support encryption
		EXEC mdpsp_sys_OpenSymmetricKey
		-- select property for draft that is master language one or multi language property
		SELECT links.WorkId, draftProperty.ObjectId, draftProperty.ObjectTypeId, draftProperty.MetaFieldId, draftProperty.MetaClassId, draftProperty.MetaFieldName, draftProperty.LanguageName,
				draftProperty.[Boolean], draftProperty.[Number], draftProperty.[FloatNumber], draftProperty.[Money], draftProperty.[Decimal], draftProperty.[Date], draftProperty.[Binary], draftProperty.[String], 
				CASE WHEN (F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1) 
					THEN dbo.mdpfn_sys_EncryptDecryptString(draftProperty.LongString, 0) 
					ELSE draftProperty.LongString END as LongString, 
				draftProperty.[Guid]
		FROM ecfVersionProperty draftProperty
		INNER JOIN MetaField F ON F.MetaFieldId = draftProperty.MetaFieldId
		INNER JOIN @ContentLinks links ON links.WorkId = draftProperty.WorkId
		
		-- and fall back property
		UNION ALL
		SELECT links.WorkId, draftProperty.ObjectId, draftProperty.ObjectTypeId, draftProperty.MetaFieldId, draftProperty.MetaClassId, draftProperty.MetaFieldName, draftProperty.LanguageName,
				draftProperty.[Boolean], draftProperty.[Number], draftProperty.[FloatNumber], draftProperty.[Money], draftProperty.[Decimal], draftProperty.[Date], draftProperty.[Binary], draftProperty.[String], 
				CASE WHEN (F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1) 
					THEN dbo.mdpfn_sys_EncryptDecryptString(draftProperty.LongString, 0) 
					ELSE draftProperty.LongString END as LongString, 
				draftProperty.[Guid]
		FROM ecfVersionProperty draftProperty
		INNER JOIN MetaField F ON F.MetaFieldId = draftProperty.MetaFieldId
		INNER JOIN #nonMasterLinks links ON links.MasterWorkId = draftProperty.WorkId
		WHERE F.MultiLanguageValue = 0
		
		EXEC mdpsp_sys_CloseSymmetricKey

	END

	DROP TABLE #nonMasterLinks
END
GO
PRINT N'Altering [dbo].[mdpsp_GetChildBySegment]...';


GO
ALTER PROCEDURE [dbo].[mdpsp_GetChildBySegment]
	@parentNodeId int,
	@catalogId int = 0,
	@UriSegment nvarchar(255)
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

	SELECT
		S.CatalogNodeId as ChildId,
		S.LanguageCode,
		1 as ContentType
	FROM CatalogItemSeo S WITH (NOLOCK)
		INNER JOIN CatalogNode N WITH (NOLOCK) ON N.CatalogNodeId = S.CatalogNodeId
		LEFT OUTER JOIN CatalogNodeRelation NR ON NR.ChildNodeId = S.CatalogNodeId
	WHERE
		UriSegment = @UriSegment AND N.IsActive = 1 AND
		((N.ParentNodeId = @parentNodeId AND (N.CatalogId = @catalogId OR @catalogId = 0))
		OR
		(NR.ParentNodeId = @parentNodeId AND (NR.CatalogId = @catalogId OR @catalogId = 0)))

	UNION ALL

	(SELECT
		S.CatalogEntryId as ChildId,
		S.LanguageCode,
		0 as ContentType
	FROM CatalogItemSeo S  WITH (NOLOCK)
		INNER JOIN CatalogEntry E ON E.CatalogEntryId = S.CatalogEntryId
		LEFT OUTER JOIN NodeEntryRelation ER ON ER.CatalogEntryId = S.CatalogEntryId
	WHERE
		UriSegment = @UriSegment AND E.IsActive = 1 AND
		((ER.CatalogNodeId = @parentNodeId AND (ER.CatalogId = @catalogId OR @catalogId = 0))
		OR
		(@parentNodeId = 0 AND E.CatalogId = @catalogId))

	EXCEPT

	SELECT
		S.CatalogEntryId as ChildId,
		S.LanguageCode,
		0 as ContentType
	FROM CatalogItemSeo S  WITH (NOLOCK)
		INNER JOIN CatalogEntry E ON E.CatalogEntryId = S.CatalogEntryId 
		INNER JOIN NodeEntryRelation ER ON ER.CatalogEntryId = S.CatalogEntryId AND ER.IsPrimary = 1
	WHERE
		UriSegment = @UriSegment 
		AND E.CatalogId = @catalogId)
END
GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByWorkIds]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 1, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
