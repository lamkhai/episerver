--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 15    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Dropping [dbo].[ecfVersion_ListByWorkIds]...';


GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'ecfVersion_ListByWorkIds')

DROP PROCEDURE [dbo].[ecfVersion_ListByWorkIds];


GO
PRINT N'Altering [dbo].[CatalogEntry]...';


GO
ALTER TABLE [dbo].[CatalogEntry]
    ADD [IsPublished] BIT DEFAULT 0 NOT NULL;


GO
PRINT N'Creating [dbo].[ecfVersion_Insert_Update]...';


GO
CREATE TRIGGER [ecfVersion_Insert_Update]
ON [dbo].[ecfVersion]
FOR INSERT, UPDATE
as BEGIN
declare @isPublished bit
    -- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	
	SELECT  @isPublished = IsPublished
	FROM CatalogEntry
	    INNER JOIN inserted ON CatalogEntry.CatalogEntryId = inserted.ObjectId
							and inserted.ObjectTypeId = 0
	IF(@isPublished = 0)
	UPDATE CatalogEntry
    SET  CatalogEntry.IsPublished = CASE inserted.Status
										 WHEN 4 THEN 1
										 WHEN 5 THEN 1
										 ELSE 0
									END
	FROM CatalogEntry
	    INNER JOIN inserted ON CatalogEntry.CatalogEntryId = inserted.ObjectId
							and inserted.ObjectTypeId = 0
END
GO
PRINT N'Creating [dbo].[ecfVersion_ListByCatalogWorkIds]...';


GO
CREATE PROCEDURE [dbo].[ecfVersion_ListByCatalogWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	
	SELECT draft.*, c.ContentGuid, NULL AS ClassTypeId, NULL AS MetaClassId, c.IsActive AS IsPublished, NULL AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId AND draft.ObjectId = links.ObjectId AND draft.ObjectTypeId = links.ObjectTypeId
	INNER JOIN [Catalog] c ON c.CatalogId = links.ObjectId AND links.ObjectTypeId = 2
	INNER JOIN CatalogLanguage cl ON draft.CatalogId = cl.CatalogId AND draft.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT

	EXEC [ecfVersionProperty_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionAsset_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionCatalog_ListByWorkIds] @ContentLinks

END
GO
PRINT N'Creating [dbo].[ecfVersion_ListByEntryWorkIds]...';


GO
CREATE PROCEDURE [dbo].[ecfVersion_ListByEntryWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	SELECT draft.*, e.ContentGuid, e.ClassTypeId, e.MetaClassId, e.IsPublished AS IsPublished, NULL AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId AND draft.ObjectId = links.ObjectId AND draft.ObjectTypeId = links.ObjectTypeId
	INNER JOIN CatalogEntry e ON links.ObjectId = e.CatalogEntryId AND links.ObjectTypeId = 0
	INNER JOIN CatalogLanguage cl ON draft.CatalogId = cl.CatalogId AND draft.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT
	
	
	EXEC [ecfVersionProperty_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionAsset_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionVariation_ListByWorkIds] @ContentLinks

	--get relations for entry versions
	SELECT TOP 1 r.CatalogEntryId, r.CatalogNodeId, r.CatalogId
	FROM NodeEntryRelation r
	INNER JOIN CatalogNode n ON r.CatalogNodeId = n.CatalogNodeId
	INNER JOIN dbo.ecfVersion v ON v.ObjectTypeId = 0 AND v.ObjectId = r.CatalogEntryId AND r.CatalogId = n.CatalogId
	INNER JOIN @ContentLinks l ON l.WorkId = v.WorkId
	INNER JOIN CatalogLanguage cl ON v.CatalogId = cl.CatalogId AND v.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT
	WHERE r.IsPrimary = 1
END
GO
PRINT N'Creating [dbo].[ecfVersion_ListByNodeWorkIds]...';


GO
CREATE PROCEDURE [dbo].[ecfVersion_ListByNodeWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	
	SELECT draft.*, n.ContentGuid, NULL AS ClassTypeId, n.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, n.ParentNodeId AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId AND draft.ObjectId = links.ObjectId AND draft.ObjectTypeId = links.ObjectTypeId
	INNER JOIN CatalogNode n ON links.ObjectId = n.CatalogNodeId AND links.ObjectTypeId = 1
	INNER JOIN CatalogLanguage cl ON draft.CatalogId = cl.CatalogId AND draft.LanguageName = cl.LanguageCode
	LEFT JOIN ecfVersionProperty p ON  p.WorkId = draft.WorkId
										AND p.MetaFieldName = 'Epi_IsPublished' COLLATE DATABASE_DEFAULT

	EXEC [ecfVersionProperty_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionAsset_ListByWorkIds] @ContentLinks

END
GO
PRINT N'Refreshing [dbo].[CatalogContent_GetDefaultIndividualPublishStatus]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContent_GetDefaultIndividualPublishStatus]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_DeleteByObjectId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_DeleteByObjectId]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_Load]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_Load]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_LoadBatch]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_LoadBatch]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_Save]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_Save]';


GO
PRINT N'Refreshing [dbo].[CatalogItemChange_Count]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogItemChange_Count]';


GO
PRINT N'Refreshing [dbo].[CatalogItemChange_Insert]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogItemChange_Insert]';


GO
PRINT N'Refreshing [dbo].[ecf_AllCatalogEntry_CatalogId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_AllCatalogEntry_CatalogId]';


GO
PRINT N'Refreshing [dbo].[ecf_Catalog_GetAllChildEntries]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Catalog_GetAllChildEntries]';


GO
PRINT N'Refreshing [dbo].[ecf_Catalog_GetChildrenEntries]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Catalog_GetChildrenEntries]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogAssociation_CatalogEntryCode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogAssociation_CatalogEntryCode]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogAssociation_CatalogId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogAssociation_CatalogId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogAssociationByName]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogAssociationByName]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogContentTypeGetUsage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogContentTypeGetUsage]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogContentTypeIsUsed]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogContentTypeIsUsed]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_AssetKey]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_AssetKey]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_Associated]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_Associated]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_AssociatedByCode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_AssociatedByCode]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_CatalogId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_CatalogId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_CatalogName]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_CatalogName]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeCode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeCode]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_CatalogNodeId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_CatalogNodeId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_Delete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_Delete]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_List]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_List]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_ListSimple]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_ListSimple]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_Name]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_Name]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_ParentEntryId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_ParentEntryId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_SearchInsertList]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_SearchInsertList]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_UriLanguage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_UriLanguage]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_UriSegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_UriSegment]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntryByCode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntryByCode]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntryItemSeo_List]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntryItemSeo_List]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntrySearch_GetResults]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntrySearch_GetResults]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogItem_AssetKey]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogItem_AssetKey]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogItemSeo_FindUriSegmentConflicts]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogItemSeo_FindUriSegmentConflicts]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_ChildEntryCount]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_ChildEntryCount]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_GetAllChildEntries]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_GetAllChildEntries]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_GetChildrenEntries]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_GetChildrenEntries]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_GetDeleteResults]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_GetDeleteResults]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogRelation]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogRelation]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogRelationByChildEntryId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogRelationByChildEntryId]';


GO
PRINT N'Refreshing [dbo].[ecf_CheckExistEntryNodeByCode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CheckExistEntryNodeByCode]';


GO
PRINT N'Refreshing [dbo].[ecf_GetCatalogEntryCodesByGuids]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_GetCatalogEntryCodesByGuids]';


GO
PRINT N'Refreshing [dbo].[ecf_GetCatalogEntryCodesByIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_GetCatalogEntryCodesByIds]';


GO
PRINT N'Refreshing [dbo].[ecf_GetCatalogEntryIdsByCodes]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_GetCatalogEntryIdsByCodes]';


GO
PRINT N'Refreshing [dbo].[ecf_GetCatalogEntryIdsByContentGuids]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_GetCatalogEntryIdsByContentGuids]';


GO
PRINT N'Refreshing [dbo].[ecf_Guid_FindEntity]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Guid_FindEntity]';


GO
PRINT N'Refreshing [dbo].[ecf_GuidEntry_Find]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_GuidEntry_Find]';


GO
PRINT N'Refreshing [dbo].[ecf_GuidEntry_Get]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_GuidEntry_Get]';


GO
PRINT N'Refreshing [dbo].[ecf_PriceDetail_List]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_PriceDetail_List]';


GO
PRINT N'Refreshing [dbo].[ecf_PropertyDefinitionGetUsage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_PropertyDefinitionGetUsage]';


GO
PRINT N'Refreshing [dbo].[ecf_PropertyDefinitionIsUsed]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_PropertyDefinitionIsUsed]';


GO
PRINT N'Refreshing [dbo].[ecf_reporting_LowStock]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_reporting_LowStock]';


GO
PRINT N'Refreshing [dbo].[ecf_reporting_ProductBestSellers]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_reporting_ProductBestSellers]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_DeleteByObjectId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_DeleteByObjectId]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_DeleteByObjectIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_DeleteByObjectIds]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_DeleteByWorkId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_DeleteByWorkId]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListMatchingSegments]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListMatchingSegments]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_SyncEntryData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncEntryData]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_UpdateMasterLanguage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_UpdateMasterLanguage]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_UpdateVersionsMasterLanguage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_UpdateVersionsMasterLanguage]';


GO
PRINT N'Refreshing [dbo].[mdpsp_GetChildBySegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_GetChildBySegment]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_GetMetaKey]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_GetMetaKey]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_CatalogEntry]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_CatalogEntry]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 15, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
