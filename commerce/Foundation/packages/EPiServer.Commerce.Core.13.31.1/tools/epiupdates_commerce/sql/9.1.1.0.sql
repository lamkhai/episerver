--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 9, @minor int = 1, @patch int = 1    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Dropping [dbo].[IX_CatalogAssociation]...';


GO
ALTER TABLE [dbo].[CatalogAssociation] DROP CONSTRAINT [IX_CatalogAssociation];


GO
PRINT N'Creating [dbo].[IX_CatalogAssociation]...';


GO
ALTER TABLE [dbo].[CatalogAssociation]
    ADD CONSTRAINT [IX_CatalogAssociation] UNIQUE NONCLUSTERED ([CatalogEntryId] ASC, [AssociationName] ASC);


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(9, 1, 1, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
