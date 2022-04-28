--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 11    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Creating [dbo].[ecf_GetCatalogEntryCodesByGuids]...';


GO
CREATE PROCEDURE [dbo].[ecf_GetCatalogEntryCodesByGuids]
	@ContentGuids udttContentGuidList READONLY
AS
BEGIN
	SELECT e.ContentGuid CatalogEntryGuid, e.Code Code from [CatalogEntry] e
	INNER JOIN @ContentGuids k  ON e.ContentGuid = k.ContentGuid
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 11, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
