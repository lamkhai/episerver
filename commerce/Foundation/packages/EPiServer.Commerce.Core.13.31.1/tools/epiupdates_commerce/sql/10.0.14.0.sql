--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 14    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

PRINT N'Updating data for [dbo].[MetaField] table ...';

GO

Update MetaField Set AllowNulls = 0 Where [Namespace] ='Mediachase.Commerce.Orders.System' AND [Name] ='CreditCardNumber'
GO
Update MetaField Set AllowNulls = 0 Where [Namespace] ='Mediachase.Commerce.Orders.System' AND [Name] ='CreditCardSecurityCode'
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 14, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion
