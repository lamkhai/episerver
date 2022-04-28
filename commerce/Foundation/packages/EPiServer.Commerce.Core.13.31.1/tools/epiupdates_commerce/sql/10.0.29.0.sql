--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 29    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

PRINT N'Updating [dbo].[MetaField] table...';
GO

UPDATE dbo.[MetaField]
SET [LENGTH] = -1
FROM dbo.[MetaField] mf
INNER JOIN MetaDataType mdt ON mf.DataTypeId = mdt.DataTypeId
WHERE mdt.Name IN('NText', 'LongString', 'LongHtmlString') AND mf.Length <= 16
GO

PRINT N'Updating MetaClass procedures ...';
GO

EXECUTE mdpsp_sys_CreateMetaClassProcedureAll 
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 29, GETUTCDATE()) 
GO 

--endUpdatingDatabaseVersion 
