--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 13    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Dropping [dbo].[ShippingCountry].[IX_ShippingCountry_ShippingMethodId]...';


GO
DROP INDEX [IX_ShippingCountry_ShippingMethodId]
    ON [dbo].[ShippingCountry];


GO
PRINT N'Dropping [dbo].[ShippingMethodCase].[IX_ShippingMethodCase_ShippingMethodId]...';


GO
DROP INDEX [IX_ShippingMethodCase_ShippingMethodId]
    ON [dbo].[ShippingMethodCase];


GO
PRINT N'Dropping [dbo].[ShippingMethodParameter].[IX_ShippingMethodParameter_ShippingMethodId]...';


GO
DROP INDEX [IX_ShippingMethodParameter_ShippingMethodId]
    ON [dbo].[ShippingMethodParameter];


GO
PRINT N'Dropping [dbo].[ShippingRegion].[IX_ShippingRegion_ShippingMethodId]...';


GO
DROP INDEX [IX_ShippingRegion_ShippingMethodId]
    ON [dbo].[ShippingRegion];


GO
PRINT N'Dropping [dbo].[FK_ShippingCountry_Country]...';


GO
ALTER TABLE [dbo].[ShippingCountry] DROP CONSTRAINT [FK_ShippingCountry_Country];


GO
PRINT N'Dropping [dbo].[FK_ShippingCountry_ShippingMethod]...';


GO
ALTER TABLE [dbo].[ShippingCountry] DROP CONSTRAINT [FK_ShippingCountry_ShippingMethod];


GO
PRINT N'Dropping [dbo].[FK_ShippingMethodCase_JurisdictionGroup]...';


GO
ALTER TABLE [dbo].[ShippingMethodCase] DROP CONSTRAINT [FK_ShippingMethodCase_JurisdictionGroup];


GO
PRINT N'Dropping [dbo].[ShippingMethod_ShippingMethodCase_FK1]...';


GO
ALTER TABLE [dbo].[ShippingMethodCase] DROP CONSTRAINT [ShippingMethod_ShippingMethodCase_FK1];


GO
PRINT N'Dropping [dbo].[FK_ShippingMethodParameter_ShippingMethod]...';


GO
ALTER TABLE [dbo].[ShippingMethodParameter] DROP CONSTRAINT [FK_ShippingMethodParameter_ShippingMethod];


GO
PRINT N'Dropping [dbo].[FK_ShippingRegion_ShippingMethod]...';


GO
ALTER TABLE [dbo].[ShippingRegion] DROP CONSTRAINT [FK_ShippingRegion_ShippingMethod];


GO
PRINT N'Dropping [dbo].[StateProvince_ShippingRegion_FK1]...';


GO
ALTER TABLE [dbo].[ShippingRegion] DROP CONSTRAINT [StateProvince_ShippingRegion_FK1];


GO
PRINT N'Dropping [dbo].[IX_ShippingMethod]...';


GO
ALTER TABLE [dbo].[ShippingMethod] DROP CONSTRAINT [IX_ShippingMethod];

GO
PRINT N'Dropping clustered indexes...';

GO
ALTER TABLE [dbo].[ShippingCountry] DROP CONSTRAINT [PK_ShippingCountry]

GO
ALTER TABLE [dbo].[ShippingMethodCase] DROP CONSTRAINT [ShippingMethodCase_PK]

GO
ALTER TABLE [dbo].[ShippingMethodParameter] DROP CONSTRAINT [PK_ShippingMethodParameter]

GO
ALTER TABLE [dbo].[ShippingRegion] DROP CONSTRAINT [ShippingRegion_PK]

GO

CREATE CLUSTERED INDEX [IX_ShippingCountry_ShippingMethodId]
    ON [dbo].[ShippingCountry]([ShippingMethodId] ASC);

GO

CREATE CLUSTERED INDEX [IX_ShippingMethodCase_ShippingMethodId]
    ON [dbo].[ShippingMethodCase]([ShippingMethodId] ASC);

GO

CREATE CLUSTERED INDEX [IX_ShippingMethodParameter_ShippingMethodId]
    ON [dbo].[ShippingMethodParameter]([ShippingMethodId] ASC);

GO
CREATE CLUSTERED INDEX [ShippingRegion_ShippingMethodId]
    ON [dbo].[ShippingRegion]([ShippingMethodId] ASC);


GO
PRINT N'Creating [dbo].[IX_ShippingMethod]...';


GO
ALTER TABLE [dbo].[ShippingMethod]
    ADD CONSTRAINT [IX_ShippingMethod] UNIQUE NONCLUSTERED ([LanguageId] ASC, [IsActive] DESC, [Name] ASC);


GO
PRINT N'Creating [dbo].[FK_ShippingCountry_Country]...';


GO
ALTER TABLE [dbo].[ShippingCountry] WITH NOCHECK
    ADD CONSTRAINT [FK_ShippingCountry_Country] FOREIGN KEY ([CountryId]) REFERENCES [dbo].[Country] ([CountryId]);


GO
PRINT N'Creating [dbo].[FK_ShippingCountry_ShippingMethod]...';


GO
ALTER TABLE [dbo].[ShippingCountry] WITH NOCHECK
    ADD CONSTRAINT [FK_ShippingCountry_ShippingMethod] FOREIGN KEY ([ShippingMethodId]) REFERENCES [dbo].[ShippingMethod] ([ShippingMethodId]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating [dbo].[FK_ShippingMethodCase_JurisdictionGroup]...';


GO
ALTER TABLE [dbo].[ShippingMethodCase] WITH NOCHECK
    ADD CONSTRAINT [FK_ShippingMethodCase_JurisdictionGroup] FOREIGN KEY ([JurisdictionGroupId]) REFERENCES [dbo].[JurisdictionGroup] ([JurisdictionGroupId]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating [dbo].[ShippingMethod_ShippingMethodCase_FK1]...';


GO
ALTER TABLE [dbo].[ShippingMethodCase] WITH NOCHECK
    ADD CONSTRAINT [ShippingMethod_ShippingMethodCase_FK1] FOREIGN KEY ([ShippingMethodId]) REFERENCES [dbo].[ShippingMethod] ([ShippingMethodId]);


GO
PRINT N'Creating [dbo].[FK_ShippingMethodParameter_ShippingMethod]...';


GO
ALTER TABLE [dbo].[ShippingMethodParameter] WITH NOCHECK
    ADD CONSTRAINT [FK_ShippingMethodParameter_ShippingMethod] FOREIGN KEY ([ShippingMethodId]) REFERENCES [dbo].[ShippingMethod] ([ShippingMethodId]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating [dbo].[FK_ShippingRegion_ShippingMethod]...';


GO
ALTER TABLE [dbo].[ShippingRegion] WITH NOCHECK
    ADD CONSTRAINT [FK_ShippingRegion_ShippingMethod] FOREIGN KEY ([ShippingMethodId]) REFERENCES [dbo].[ShippingMethod] ([ShippingMethodId]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating [dbo].[StateProvince_ShippingRegion_FK1]...';


GO
ALTER TABLE [dbo].[ShippingRegion] WITH NOCHECK
    ADD CONSTRAINT [StateProvince_ShippingRegion_FK1] FOREIGN KEY ([StateProvinceId]) REFERENCES [dbo].[StateProvince] ([StateProvinceId]);


GO
PRINT N'Refreshing [dbo].[ecf_ShippingMethod_Language]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_ShippingMethod_Language]';


GO
PRINT N'Refreshing [dbo].[ecf_ShippingMethod_Market]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_ShippingMethod_Market]';


GO
PRINT N'Refreshing [dbo].[ecf_ShippingMethod_ShippingMethodId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_ShippingMethod_ShippingMethodId]';


GO
PRINT N'Refreshing [dbo].[ecf_ShippingMethod_GetCases]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_ShippingMethod_GetCases]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 13, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
