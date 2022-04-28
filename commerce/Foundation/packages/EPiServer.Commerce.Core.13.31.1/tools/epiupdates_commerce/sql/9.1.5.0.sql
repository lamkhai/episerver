--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 9, @minor int = 1, @patch int = 5    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Creating [dbo].[ShippingCountry].[IX_ShippingCountry_ShippingMethodId]...';


GO
CREATE NONCLUSTERED INDEX [IX_ShippingCountry_ShippingMethodId]
    ON [dbo].[ShippingCountry]([ShippingMethodId] ASC);


GO
PRINT N'Creating [dbo].[ShippingMethodCase].[IX_ShippingMethodCase_ShippingMethodId]...';


GO
CREATE NONCLUSTERED INDEX [IX_ShippingMethodCase_ShippingMethodId]
    ON [dbo].[ShippingMethodCase]([ShippingMethodId] ASC);


GO
PRINT N'Creating [dbo].[ShippingMethodParameter].[IX_ShippingMethodParameter_ShippingMethodId]...';


GO
CREATE NONCLUSTERED INDEX [IX_ShippingMethodParameter_ShippingMethodId]
    ON [dbo].[ShippingMethodParameter]([ShippingMethodId] ASC);


GO
PRINT N'Creating [dbo].[ShippingRegion].[IX_ShippingRegion_ShippingMethodId]...';


GO
CREATE NONCLUSTERED INDEX [IX_ShippingRegion_ShippingMethodId]
    ON [dbo].[ShippingRegion]([ShippingMethodId] ASC);


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(9, 1, 5, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
