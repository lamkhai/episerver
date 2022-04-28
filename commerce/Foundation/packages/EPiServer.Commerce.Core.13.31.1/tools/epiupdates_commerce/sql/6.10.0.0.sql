--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 10, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

-- alter table PromotionInformation
ALTER TABLE PromotionInformation DROP CONSTRAINT [PK_PromotionInformationId]
GO
ALTER TABLE PromotionInformation ADD CONSTRAINT [PK_PromotionInformationId] PRIMARY KEY NONCLUSTERED ([PromotionInformationId] ASC)
GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 10, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
