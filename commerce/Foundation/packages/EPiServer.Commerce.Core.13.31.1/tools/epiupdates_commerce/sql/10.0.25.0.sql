--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 25    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[ecf_CatalogNode_Asset]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogNode_Asset]
    @CatalogNodeId int
AS
BEGIN
	SELECT A.* from [CatalogItemAsset] A
	WHERE
		A.CatalogNodeId = @CatalogNodeId
		AND A.CatalogNodeId > 0 -- Force using filtered index
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 25, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
