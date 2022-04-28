--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
	BEGIN 
	declare @major int = 7, @minor int = 0, @patch int = 3    
	IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
		select 0,'Already correct database version' 
	ELSE 
		select 1, 'Upgrading database' 
	END 
ELSE 
	select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 


-- Drop Mediachase CMS Store Procedures
DECLARE @sqlRemoveRedundantStoreProcedures VARCHAR(MAX)

SET @sqlRemoveRedundantStoreProcedures = (
SELECT
    'DROP PROCEDURE [' + ROUTINE_SCHEMA + '].[' + ROUTINE_NAME + '] ' 
FROM 
    INFORMATION_SCHEMA.ROUTINES
WHERE [ROUTINE_TYPE] = 'PROCEDURE' 
	AND ([ROUTINE_NAME] like 'cms[_]fs%'
	OR [ROUTINE_NAME] like 'cms[_]GlobalVariables%'
	OR [ROUTINE_NAME] like 'cms[_]menu%'
	OR [ROUTINE_NAME] like 'cms[_]Navigation%'
	OR [ROUTINE_NAME] like 'cms[_]Page%'
	OR [ROUTINE_NAME] like 'cms[_]Site%'
	OR [ROUTINE_NAME] like 'cms[_]Templates%'
	OR [ROUTINE_NAME] like 'cms[_]Workflow%'
	OR [ROUTINE_NAME] like 'cms[_]LanguageInfo%'
	OR [ROUTINE_NAME] like 'dps[_]%'
	OR [ROUTINE_NAME] = 'ecf_Site'
	OR [ROUTINE_NAME] like 'main[_]%'
	)
FOR XML PATH ('')
)

EXEC (@sqlRemoveRedundantStoreProcedures)
GO

-- Drop constraints before dropping tables
IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = N'FK_dps_Node_dps_NodeType')
	BEGIN
		ALTER TABLE [dbo].[dps_Node] DROP CONSTRAINT [FK_dps_Node_dps_NodeType]
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = N'FK_dps_Node_dps_PageDocument')
	BEGIN
		ALTER TABLE [dbo].[dps_Node] DROP CONSTRAINT [FK_dps_Node_dps_PageDocument]
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = N'FK_NavigationCommand_NavigationItems')
	BEGIN
		ALTER TABLE [dbo].[NavigationCommand] DROP CONSTRAINT [FK_NavigationCommand_NavigationItems]
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = N'FK_main_WorkflowStatusAccess_main_WorkflowStatus')
	BEGIN
		ALTER TABLE [dbo].[WorkflowStatusAccess] DROP CONSTRAINT [FK_main_WorkflowStatusAccess_main_WorkflowStatus]
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = N'FK_main_WorkflowStatus_main_Workflow')
	BEGIN
		ALTER TABLE [dbo].[WorkflowStatus] DROP CONSTRAINT [FK_main_WorkflowStatus_main_Workflow]
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = N'FK_NavigationParams_NavigationItems')
	BEGIN
		ALTER TABLE [dbo].[NavigationParams] DROP CONSTRAINT [FK_NavigationParams_NavigationItems]
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = N'FK_main_PageVersion_main_LanguageInfo')
	BEGIN
		ALTER TABLE [dbo].[main_PageVersion] DROP CONSTRAINT [FK_main_PageVersion_main_LanguageInfo]
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = N'FK_main_PageVersion_main_PageTree')
	BEGIN
		ALTER TABLE [dbo].[main_PageVersion] DROP CONSTRAINT [FK_main_PageVersion_main_PageTree]
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = N'FK_main_PageVersion_main_Templates')
	BEGIN
		ALTER TABLE [dbo].[main_PageVersion] DROP CONSTRAINT [FK_main_PageVersion_main_Templates]
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = N'FK_dps_ControlStorage_dps_Control')
	BEGIN
		ALTER TABLE [dbo].[dps_ControlStorage] DROP CONSTRAINT [FK_dps_ControlStorage_dps_Control]
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = N'FK_dps_Control_dps_Node')
	BEGIN
		ALTER TABLE [dbo].[dps_Control] DROP CONSTRAINT [FK_dps_Control_dps_Node]
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = N'FK_main_MenuItem_Resources_main_MenuItem')
	BEGIN
		ALTER TABLE [dbo].[main_MenuItem_Resources] DROP CONSTRAINT [FK_main_MenuItem_Resources_main_MenuItem]
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = N'FK_main_MenuItem_main_Menu')
	BEGIN
		ALTER TABLE [dbo].[main_MenuItem] DROP CONSTRAINT [FK_main_MenuItem_main_Menu]
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = N'FK_SiteSecurity_Site')
	BEGIN
		ALTER TABLE [dbo].[SiteSecurity] DROP CONSTRAINT [FK_SiteSecurity_Site]
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = N'FK_SiteLanguage_Site')
	BEGIN
		ALTER TABLE [dbo].[SiteLanguage] DROP CONSTRAINT [FK_SiteLanguage_Site]
	END
GO

-- Drop Mediachase CMS tables
IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'dps_Control')
	BEGIN
		DROP TABLE [dps_Control]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'dps_ControlStorage')
	BEGIN
		DROP TABLE [dps_ControlStorage]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'dps_Node')
	BEGIN
		DROP TABLE [dps_Node]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'dps_NodeType')
	BEGIN
		DROP TABLE [dps_NodeType]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'dps_PageDocument')
	BEGIN
		DROP TABLE [dps_PageDocument]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'dps_TemporaryStorage')
	BEGIN
		DROP TABLE [dps_TemporaryStorage]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'main_GlobalVariables')
	BEGIN
		DROP TABLE [main_GlobalVariables]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'main_LanguageInfo')
	BEGIN
		DROP TABLE [main_LanguageInfo]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'main_Menu')
	BEGIN
		DROP TABLE [main_Menu]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'main_MenuItem')
	BEGIN
		DROP TABLE [main_MenuItem]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'main_MenuItem_Resources')
	BEGIN
		DROP TABLE [main_MenuItem_Resources]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'main_PageAttributes')
	BEGIN
		DROP TABLE [main_PageAttributes]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'main_PageState')
	BEGIN
		DROP TABLE [main_PageState]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'main_PageTree')
	BEGIN
		DROP TABLE [main_PageTree]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'main_PageTreeAccess')
	BEGIN
		DROP TABLE [main_PageTreeAccess]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'main_PageVersion')
	BEGIN
		DROP TABLE [main_PageVersion]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'main_Templates')
	BEGIN
		DROP TABLE [main_Templates]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'NavigationCommand')
	BEGIN
		DROP TABLE [NavigationCommand]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'NavigationItems')
	BEGIN
		DROP TABLE [NavigationItems]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'NavigationParams')
	BEGIN
		DROP TABLE [NavigationParams]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'Site')
	BEGIN
		DROP TABLE [Site]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'SiteLanguage')
	BEGIN
		DROP TABLE [SiteLanguage]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'SiteSecurity')
	BEGIN
		DROP TABLE [SiteSecurity]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'Workflow')
	BEGIN
		DROP TABLE [Workflow]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'WorkflowStatus')
	BEGIN
		DROP TABLE [WorkflowStatus]; 
	END
GO

IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'WorkflowStatusAccess')
	BEGIN
		DROP TABLE [WorkflowStatusAccess]; 
	END
GO

IF EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_NodeEntryRelation_Indexed_CatalogEntryId' AND object_id = OBJECT_ID('NodeEntryRelation'))
	BEGIN
        DROP INDEX [IX_NodeEntryRelation_Indexed_CatalogEntryId] ON [dbo].[NodeEntryRelation];
	END
GO

CREATE NONCLUSTERED INDEX [IX_NodeEntryRelation_Indexed_CatalogEntryId] ON [dbo].[NodeEntryRelation] ([CatalogEntryId])
INCLUDE([CatalogId], [CatalogNodeId], [SortOrder])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

GO

IF EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CatalogEntryRelation_Indexed_ChildEntryId' AND object_id = OBJECT_ID('CatalogEntryRelation'))
	BEGIN
		DROP INDEX [IX_CatalogEntryRelation_Indexed_ChildEntryId] ON [dbo].[CatalogEntryRelation];
	END
GO

CREATE NONCLUSTERED INDEX [IX_CatalogEntryRelation_Indexed_ChildEntryId] ON [dbo].[CatalogEntryRelation] ([ChildEntryId])
INCLUDE([ParentEntryId], [RelationTypeId], [Quantity], [GroupName], [SortOrder])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

GO

-- Add Epi_IsPublished, Epi_StartPublish, Epi_StopPublish column to Catalog MetaData tables, so the migration process would work
DECLARE @MetaClassTable NVARCHAR(256), @MetaQuery_tmp nvarchar(max)
DECLARE tables_cursor CURSOR FOR
	SELECT c.TableName FROM MetaClass c WHERE dbo.mdpfn_sys_IsCatalogMetaDataTable(c.TableName) = 1
OPEN tables_cursor
	FETCH NEXT FROM tables_cursor INTO @MetaClassTable 
WHILE(@@FETCH_STATUS = 0)
BEGIN
	SET @MetaQuery_tmp = '
		IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N''Epi_IsPublished'' AND Object_ID = Object_ID('''+@MetaClassTable+'''))
			ALTER TABLE '+@MetaClassTable+' ADD Epi_IsPublished bit
		IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N''Epi_IsPublished'' AND Object_ID = Object_ID('''+@MetaClassTable+'_Localization''))
			ALTER TABLE '+@MetaClassTable+'_Localization ADD Epi_IsPublished bit
		IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N''Epi_StartPublish'' AND Object_ID = Object_ID('''+@MetaClassTable+'''))
			ALTER TABLE '+@MetaClassTable+' ADD Epi_StartPublish DateTime
		IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N''Epi_StartPublish'' AND Object_ID = Object_ID('''+@MetaClassTable+'_Localization''))
			ALTER TABLE '+@MetaClassTable+'_Localization ADD Epi_StartPublish DateTime
		IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N''Epi_StopPublish'' AND Object_ID = Object_ID('''+@MetaClassTable+'''))
			ALTER TABLE '+@MetaClassTable+' ADD Epi_StopPublish DateTime
		IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N''Epi_StopPublish'' AND Object_ID = Object_ID('''+@MetaClassTable+'_Localization''))
			ALTER TABLE '+@MetaClassTable+'_Localization ADD Epi_StopPublish DateTime
		'
			
	EXEC(@MetaQuery_tmp)
	FETCH NEXT FROM tables_cursor INTO @MetaClassTable
END
CLOSE tables_cursor
DEALLOCATE tables_cursor
GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 3, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
