--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 5, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

-- create IsGift meta field
DECLARE @metaClassId int, @metaDataTypeId int, @metaFieldId int
SET @metaClassId = (SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'LineItemEx')
SET @metaDataTypeId = (SELECT TOP 1 DataTypeId from MetaDataType WHERE Name = 'Boolean')

IF @metaClassId IS NOT NULL
BEGIN
	IF NOT EXISTS(SELECT 1 FROM [dbo].[MetaField] WHERE [Name] = N'Epi_IsGift')
	BEGIN		  
		EXEC mdpsp_sys_AddMetaField 'Mediachase.Commerce.Orders.LineItem',
			'Epi_IsGift',
			'IsGift Property',
			'The property is specified only for LineItem class. It indicates whether a line item is a gift item or not.',
			@metaDataTypeId,
			8,
			1,
			0,
			0,
			0,
			@Retval = @metaFieldId OUTPUT
	
		EXEC mdpsp_sys_AddMetaFieldToMetaClass @metaClassId, @metaFieldId, 0
	END
END
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 5, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
