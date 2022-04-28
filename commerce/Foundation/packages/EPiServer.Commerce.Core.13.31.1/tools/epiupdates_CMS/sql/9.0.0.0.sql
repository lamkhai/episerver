--beginvalidatingquery
IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[DraftStore_DeleteById]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
    SELECT 0, 'Already created DraftStore_DeleteById stored procedure'
ELSE
	SELECT 1, 'Creating DraftStore_DeleteById stored procedure'
--endvalidatingquery

GO

-- Removing Serialize Catalog Meta Data Job
DECLARE @JobID uniqueidentifier 
SELECT @JobID = pkID FROM dbo.tblScheduledItem WHERE AssemblyName = 'EPiServer.Business.Commerce' 
    AND TypeName = 'EPiServer.Business.Commerce.ScheduledJobs.SerializeDataIndexJob'
IF @JobID IS NOT NULL
    EXECUTE netSchedulerRemove @JobID
GO
-- End of removing Serialize Catalog Meta Data Job

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[DraftStore_DeleteByID]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[DraftStore_DeleteByID] 
GO
CREATE PROCEDURE [dbo].[DraftStore_DeleteByID]
	@IDTable [dbo].[IDTable] READONLY
AS
BEGIN
    DELETE b FROM tblBigTable b INNER JOIN @IDTable i ON b.pkId = i.ID
END
GO

IF NOT EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='WorkIDMappingTable')
BEGIN
	CREATE TYPE [dbo].[WorkIDMappingTable] AS TABLE(
		[ContentLinkID] [int] NOT NULL, 
		[OldWorkID] [int] NULL,
		[NewWorkID] [int] NOT NULL,
		[LanguageName] nvarchar(20) NULL
	)
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[tblProjectItem_MigrateWorkID]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[tblProjectItem_MigrateWorkID] 
GO
CREATE PROCEDURE [dbo].[tblProjectItem_MigrateWorkID]
	@WorkIDTable [dbo].[WorkIDMappingTable] READONLY
AS
BEGIN
	UPDATE p SET p.ContentLinkWorkID = w.NewWorkID
	FROM tblProjectItem p
	INNER JOIN @WorkIDTable w ON p.ContentLinkID = w.ContentLinkID
	WHERE p.ContentLinkProvider = 'CatalogContent' AND p.ContentLinkWorkID = w.OldWorkID
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[tblProjectItem_MigrateInactiveContentID]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[tblProjectItem_MigrateInactiveContentID] 
GO
CREATE PROCEDURE [dbo].[tblProjectItem_MigrateInactiveContentID]
	@WorkIDTable [dbo].[WorkIDMappingTable] READONLY
AS
BEGIN
	UPDATE p SET p.ContentLinkWorkID = w.NewWorkID
	FROM tblProjectItem p
	INNER JOIN @WorkIDTable w ON p.ContentLinkID = w.ContentLinkID AND p.[Language] = w.LanguageName COLLATE DATABASE_DEFAULT
	WHERE p.ContentLinkProvider = 'CatalogContent' 
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[GetCatalogContentDraftOfProjectItems]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[GetCatalogContentDraftOfProjectItems] 
GO
CREATE PROCEDURE [dbo].[GetCatalogContentDraftOfProjectItems]
	@WorkIDTable [dbo].[WorkIDMappingTable] READONLY,
	@BatchSize INT
AS
BEGIN
	IF EXISTS (SELECT * FROM sys.views WHERE name ='VW_EPiServer.Commerce.Catalog.Provider.CatalogContentDraft') 
	BEGIN
		 SELECT TOP (@BatchSize) draft.* 
		 FROM [dbo].[VW_EPiServer.Commerce.Catalog.Provider.CatalogContentDraft] draft
		 INNER JOIN @WorkIDTable w ON w.ContentLinkID = draft.ContentId AND w.OldWorkID = draft.ContentWorkId
		 ORDER BY draft.StoreId ASC
	END
END
GO