--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 0, @patch int = 8    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO

ALTER TABLE [dbo].[OrderGroupNote] DROP CONSTRAINT FK_OrderGroupNote_OrderGroup
GO

ALTER TABLE [dbo].[OrderGroupNote]  WITH CHECK ADD  CONSTRAINT [FK_OrderGroupNote_OrderGroup] FOREIGN KEY([OrderGroupId])
    REFERENCES [dbo].[OrderGroup]([OrderGroupId])
    ON UPDATE CASCADE
    ON DELETE CASCADE
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 8, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
