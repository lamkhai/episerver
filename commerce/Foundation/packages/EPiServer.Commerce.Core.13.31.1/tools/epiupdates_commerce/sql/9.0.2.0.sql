--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 9, @minor int = 0, @patch int = 2    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
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

	-- Open and Close SymmetricKey do nothing if the system does not support encryption
	EXEC mdpsp_sys_OpenSymmetricKey
	-- select property for draft that is master language one or multi language property
	SELECT links.WorkId, draftProperty.ObjectId, draftProperty.ObjectTypeId, draftProperty.MetaFieldId, draftProperty.MetaClassId, draftProperty.MetaFieldName, draftProperty.LanguageName,
			draftProperty.[Boolean], draftProperty.[Number], draftProperty.[FloatNumber], draftProperty.[Money], draftProperty.[Decimal], draftProperty.[Date], draftProperty.[Binary], draftProperty.[String], 
			CASE WHEN (@IsAzureCompatible = 0 AND F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1) 
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
			CASE WHEN (@IsAzureCompatible = 0 AND F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1) 
				THEN dbo.mdpfn_sys_EncryptDecryptString(draftProperty.LongString, 0) 
				ELSE draftProperty.LongString END as LongString, 
			draftProperty.[Guid]
	FROM ecfVersionProperty draftProperty
	INNER JOIN MetaField F ON F.MetaFieldId = draftProperty.MetaFieldId
	INNER JOIN #nonMasterLinks links ON links.MasterWorkId = draftProperty.WorkId
	WHERE F.MultiLanguageValue = 0
	
	EXEC mdpsp_sys_CloseSymmetricKey

	DROP TABLE #nonMasterLinks
END
GO
PRINT N'Altering [dbo].[PromotionInformationGetRedemptions]...';


GO
ALTER PROCEDURE [dbo].[PromotionInformationGetRedemptions]
	@PromotionGuids [dbo].[udttContentGuidList] READONLY,
	@CustomerId UNIQUEIDENTIFIER = NULL,
	@ExcludeOrderFormId INT = NULL
AS
BEGIN

	IF @CustomerId IS NULL
		BEGIN

			SELECT p.PromotionGuid, COUNT(*) AS TotalRedemptions, 0 AS CustomerRedemptions 
			FROM PromotionInformation p
			INNER JOIN OrderForm  o
			ON p.OrderFormId = o.OrderFormId
			WHERE PromotionGuid IN (SELECT DISTINCT ContentGuid FROM @PromotionGuids) AND IsRedeemed = 1 
				  AND o.OrigOrderFormId is null
			GROUP BY p.PromotionGuid;

		END
	ELSE
		BEGIN

		    CREATE TABLE #Totals(PromotionGuid UNIQUEIDENTIFIER, TotalRedemptions INT);

			INSERT INTO #Totals 
			SELECT p.PromotionGuid, COUNT(*) AS TotalRedemptions
			FROM PromotionInformation p
			INNER JOIN OrderForm  o
			ON p.OrderFormId = o.OrderFormId
			WHERE PromotionGuid IN (SELECT DISTINCT ContentGuid FROM @PromotionGuids) AND (p.OrderFormId != @ExcludeOrderFormId OR @ExcludeOrderFormId IS NULL) AND IsRedeemed = 1
				  AND o.OrigOrderFormId is null
			GROUP BY p.PromotionGuid;

			SELECT PromotionLevel.PromotionGuid AS PromotionGuid, TotalRedemptions = PromotionLevel.TotalRedemptions, COUNT(CustomerId) AS CustomerRedemptions
			FROM dbo.PromotionInformation AS CustomerLevel 
			RIGHT JOIN #Totals AS PromotionLevel	
			ON CustomerLevel.PromotionGuid = PromotionLevel.PromotionGuid AND CustomerLevel.CustomerId = @CustomerId AND CustomerLevel.OrderFormId != @ExcludeOrderFormId
			GROUP BY PromotionLevel.PromotionGuid, PromotionLevel.TotalRedemptions;

			DROP TABLE #Totals;

		END
END
GO
PRINT N'Creating [dbo].[PromotionInformationDeleteByPromotionGuid]...';


GO
CREATE PROCEDURE [dbo].[PromotionInformationDeleteByPromotionGuid]
	@PromotionGuid UNIQUEIDENTIFIER
AS
BEGIN
	DELETE FROM PromotionInformation
	WHERE PromotionGuid = @PromotionGuid;
END
GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByWorkIds]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(9, 0, 2, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
