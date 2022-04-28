--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 12    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Dropping [dbo].[CatalogItemSeo].[IX_CatalogItemSeo_CatalogEntryId]...';


GO
DROP INDEX [IX_CatalogItemSeo_CatalogEntryId]
    ON [dbo].[CatalogItemSeo];

GO
ALTER TABLE [dbo].[CatalogItemSeo] DROP CONSTRAINT [PK_CatalogItemSeo]
GO

ALTER TABLE [dbo].[CatalogItemSeo] ADD  CONSTRAINT [PK_CatalogItemSeo] PRIMARY KEY NONCLUSTERED 
(
    [Uri] ASC,
    [LanguageCode] ASC
)
GO

CREATE CLUSTERED INDEX [IX_CatalogItemSeo_CatalogEntryId] ON [dbo].[CatalogItemSeo]
(
    [CatalogEntryId] ASC
)

GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry]';


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
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_Name]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_Name]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_ParentEntryId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_ParentEntryId]';


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
PRINT N'Refreshing [dbo].[ecf_CatalogEntryItemSeo_ValidateUri]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntryItemSeo_ValidateUri]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntrySearch_GetResults]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntrySearch_GetResults]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogItemSeo_FindUriSegmentConflicts]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogItemSeo_FindUriSegmentConflicts]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_CatalogId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_CatalogId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_CatalogName]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_CatalogName]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_CatalogParentNode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_CatalogParentNode]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_Code]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_Code]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_List]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_List]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_SiteId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_SiteId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_UriLanguage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_UriLanguage]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNodeItemSeo_ValidateUri]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUri]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_CatalogNode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_CatalogNode]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_SyncEntryData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncEntryData]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_SyncNodeData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncNodeData]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_UpdateSeoByObjectIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_UpdateSeoByObjectIds]';


GO
PRINT N'Refreshing [dbo].[mdpsp_GetChildBySegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_GetChildBySegment]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_CatalogEntry]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_CatalogEntry]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_CatalogParentNodeCode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_CatalogParentNodeCode]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 12, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
