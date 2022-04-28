--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 9    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[CatalogContentProperty_LoadAllLanguages]...';


GO
ALTER PROCEDURE [dbo].[CatalogContentProperty_LoadAllLanguages]
	@ObjectId int,
	@ObjectTypeId int,
	@MetaClassId int
AS
BEGIN   
	EXEC mdpsp_sys_OpenSymmetricKey

	SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.CultureSpecific, P.MetaFieldName, P.LanguageName,
						P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], 
						CASE WHEN (F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1 )
						THEN dbo.mdpfn_sys_EncryptDecryptString(P.LongString, 0) 
						ELSE P.LongString END AS LongString, 
						P.[Guid]  
	FROM dbo.CatalogContentProperty P
	INNER JOIN MetaField F ON P.MetaFieldId = F.MetaFieldId
	WHERE ObjectId = @ObjectId AND
			ObjectTypeId = @ObjectTypeId AND
			MetaClassId = @MetaClassId

	EXEC mdpsp_sys_CloseSymmetricKey
	
	-- Select CatalogContentEx data
	EXEC CatalogContentEx_Load @ObjectId, @ObjectTypeId
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 9, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
