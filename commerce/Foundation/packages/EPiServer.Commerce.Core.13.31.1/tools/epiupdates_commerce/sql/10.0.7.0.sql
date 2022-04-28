--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 7    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Dropping [dbo].[CatalogItemAsset].[IX_CatalogItemAsset_NodeId]...';


GO
DROP INDEX [IX_CatalogItemAsset_NodeId]
    ON [dbo].[CatalogItemAsset];


GO
PRINT N'Dropping [dbo].[ecfVersion].[IDX_ecfVersion_Indexed_ContentId]...';


GO
DROP INDEX [IDX_ecfVersion_Indexed_ContentId]
    ON [dbo].[ecfVersion];


GO
PRINT N'Dropping [dbo].[CatalogItemAsset].[IX_CatalogItemAsset_EntryId]...';


GO
DROP INDEX [IX_CatalogItemAsset_EntryId]
    ON [dbo].[CatalogItemAsset];


GO
PRINT N'Dropping [dbo].[ecfVersionAsset].[IDX_ecfVersionAsset_WorkId]...';


GO
DROP INDEX [IDX_ecfVersionAsset_WorkId]
    ON [dbo].[ecfVersionAsset];


GO
PRINT N'Dropping [dbo].[DF_CatalogItemAsset_CatalogEntryId]...';


GO
ALTER TABLE [dbo].[CatalogItemAsset] DROP CONSTRAINT [DF_CatalogItemAsset_CatalogEntryId];


GO
PRINT N'Dropping [dbo].[DF_CatalogItemAsset_CatalogNodeId]...';


GO
ALTER TABLE [dbo].[CatalogItemAsset] DROP CONSTRAINT [DF_CatalogItemAsset_CatalogNodeId];


GO
PRINT N'Dropping [dbo].[CatalogItemAsset].[PK_CatalogItemAsset]...';


ALTER TABLE [dbo].[CatalogItemAsset] DROP CONSTRAINT [PK_CatalogItemAsset]
GO
PRINT N'Creating [dbo].[CatalogItemAsset].[PK_CatalogItemAsset]...';

ALTER TABLE [dbo].[CatalogItemAsset] ADD  CONSTRAINT [PK_CatalogItemAsset] PRIMARY KEY CLUSTERED 
(
    [CatalogEntryId] ASC,
    [CatalogNodeId] ASC,
    [AssetType] ASC,
    [AssetKey] ASC
)

GO
PRINT N'Creating [dbo].[CatalogItemAsset].[IX_CatalogItemAsset_NodeId]...';


GO
CREATE NONCLUSTERED INDEX [IX_CatalogItemAsset_NodeId]
    ON [dbo].[CatalogItemAsset]([CatalogNodeId] ASC)
    INCLUDE([GroupName], [SortOrder]);


GO
PRINT N'Creating [dbo].[ecfVersion].[IDX_ecfVersion_Indexed_ContentId]...';


GO
CREATE NONCLUSTERED INDEX [IDX_ecfVersion_Indexed_ContentId]
    ON [dbo].[ecfVersion]([ObjectId] ASC, [ObjectTypeId] ASC, [CatalogId] ASC)
    INCLUDE([LanguageName], [MasterLanguageName], [Status]);


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_AssetKey]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_AssetKey]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_Components]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_Components]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntrySearch_GetResults]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntrySearch_GetResults]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogItem_AssetKey]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogItem_AssetKey]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_Asset]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_Asset]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_SyncEntryData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncEntryData]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_SyncNodeData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncNodeData]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_UpdateVersionsMasterLanguage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_UpdateVersionsMasterLanguage]';


GO
PRINT N'Refreshing [dbo].[ecfVersionAsset_InsertForMasterLanguage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersionAsset_InsertForMasterLanguage]';


GO
PRINT N'Refreshing [dbo].[ecfVersionAsset_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersionAsset_ListByWorkIds]';


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
PRINT N'Refreshing [dbo].[ecf_CatalogEntryByCode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntryByCode]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByWorkIds]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_CatalogEntry]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_CatalogEntry]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 7, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
