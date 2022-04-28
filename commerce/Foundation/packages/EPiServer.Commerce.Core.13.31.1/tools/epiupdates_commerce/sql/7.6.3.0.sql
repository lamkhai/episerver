--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 6, @patch int = 3    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Creating [dbo].[mdpfn_sys_IsCatalogMetaClass]...';


GO
CREATE FUNCTION [dbo].[mdpfn_sys_IsCatalogMetaClass]
(
	@MetaClassId INT
)
RETURNS BIT
AS
BEGIN
	DECLARE @IsCatalogMetaClass BIT
    SET @IsCatalogMetaClass = (SELECT [dbo].[mdpfn_sys_IsInheritedFromMetaClass](@MetaClassId, 'CatalogEntry'))
	IF @IsCatalogMetaClass = 0
	    SET @IsCatalogMetaClass = (SELECT [dbo].[mdpfn_sys_IsInheritedFromMetaClass](@MetaClassId, 'CatalogNode'))
    RETURN @IsCatalogMetaClass
END
GO
PRINT N'Altering [dbo].[mdpfn_sys_IsCatalogMetaDataTable]...';


GO
ALTER FUNCTION [dbo].[mdpfn_sys_IsCatalogMetaDataTable]
(
	@tableName nvarchar(256)
)
RETURNS BIT
AS
BEGIN
	DECLARE @IsCatalogMetaClass BIT
    DECLARE @MetaClassId INT
    SET @MetaClassId = (SELECT MetaClassId FROM MetaClass WHERE TableName = @tableName)
    SET @IsCatalogMetaClass = (SELECT [dbo].[mdpfn_sys_IsCatalogMetaClass](@MetaClassId))
    RETURN @IsCatalogMetaClass
END
GO
PRINT N'Creating [dbo].[mdpsp_sys_MetaFieldAllowNulls]...';


GO
CREATE PROCEDURE [dbo].[mdpsp_sys_MetaFieldAllowNulls]
    @MetaFieldId int,
    @AllowNulls bit
as
begin
    set nocount on

    if not exists (select 1 from MetaField where MetaFieldId = @MetaFieldId)
    begin
        raiserror('The specified meta field does not exists or is a system field.', 16, 1)
    end
    else
    begin
		if @AllowNulls = 0 and
			exists (select 1 from MetaField f where f.MetaFieldId = @MetaFieldId AND f.AllowNulls = 1) and
			exists (select 1 from MetaClassMetaFieldRelation r where r.MetaFieldId = @MetaFieldId and [dbo].[mdpfn_sys_IsCatalogMetaClass](r.MetaClassId) = 0)
		begin
			raiserror('Switching AllowNulls to 0 is only supported for catalog meta fields.', 16, 1)
		end
		else
		begin
			update MetaField
			set AllowNulls = @AllowNulls
			where MetaFieldId = @MetaFieldId
		end
    end
end
GO
PRINT N'Refreshing [dbo].[mdpsp_sys_AddMetaFieldToMetaClass]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_AddMetaFieldToMetaClass]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_DeleteMetaClass]...';


GO
SET ANSI_NULLS, QUOTED_IDENTIFIER OFF;


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_DeleteMetaClass]';


GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON;


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]...';


GO
SET ANSI_NULLS, QUOTED_IDENTIFIER OFF;


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]';


GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON;


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_GetMetaKey]...';


GO
SET ANSI_NULLS, QUOTED_IDENTIFIER OFF;


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_GetMetaKey]';


GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON;


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_LoadDictionarySingleItemUsages]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_LoadDictionarySingleItemUsages]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 6, 3, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
