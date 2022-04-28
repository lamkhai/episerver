--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 10, @patch int = 6    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

IF EXISTS (SELECT 1 
                 FROM INFORMATION_SCHEMA.TABLES 
                 WHERE  TABLE_NAME = 'Cls_Address')

BEGIN
ALTER TABLE Cls_Address ALTER COLUMN Name NVARCHAR(128) NOT NULL
ALTER TABLE Cls_Address ALTER COLUMN Email NVARCHAR(256)
END
GO

 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 10, 6, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
