--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 5, @patch int = 1    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

-- create SP mdpsp_sys_DeleteMetaFieldFromMetaClass
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass] 
GO
CREATE PROCEDURE [dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]
	@MetaClassId	INT,
	@MetaFieldId	INT
AS
BEGIN
	IF NOT EXISTS(SELECT * FROM MetaClassMetaFieldRelation WHERE MetaFieldId = @MetaFieldId AND MetaClassId = @MetaClassId)
	BEGIN
		--RAISERROR ('Wrong @MetaFieldId and @MetaClassId.', 16, 1)
		-- GOTO ERR
		RETURN
	END

	-- Step 0. Prepare
	SET NOCOUNT ON

	DECLARE @MetaFieldName NVARCHAR(256)
	DECLARE @MetaFieldOwnerTable NVARCHAR(256)
	DECLARE @BaseMetaFieldOwnerTable NVARCHAR(256)
	DECLARE @IsAbstractClass BIT

	-- Step 1. Find a Field Name
	-- Step 2. Find a TableName
	IF NOT EXISTS(SELECT * FROM MetaField MF WHERE MetaFieldId = @MetaFieldId AND SystemMetaClassId = 0 )
	BEGIN
		RAISERROR ('Wrong @MetaFieldId.', 16, 1)
		GOTO ERR
	END

	SELECT @MetaFieldName = MF.[Name] FROM MetaField MF WHERE MetaFieldId = @MetaFieldId AND SystemMetaClassId = 0

	IF NOT EXISTS(SELECT * FROM MetaClass MC WHERE MetaClassId = @MetaClassId AND IsSystem = 0)
	BEGIN
		RAISERROR ('Wrong @MetaClassId.', 16, 1)
		GOTO ERR
	END

	SELECT @BaseMetaFieldOwnerTable = MC.TableName, @IsAbstractClass = MC.IsAbstract FROM MetaClass MC
		WHERE MetaClassId = @MetaClassId AND IsSystem = 0

	SET @MetaFieldOwnerTable = @BaseMetaFieldOwnerTable
	
	DECLARE @IsCatalogMetaClass BIT
	SET @IsCatalogMetaClass = dbo.mdpfn_sys_IsCatalogMetaDataTable(@MetaFieldOwnerTable)

	IF @@ERROR <> 0 GOTO ERR

	BEGIN TRAN

	IF @IsAbstractClass = 0
	BEGIN
		EXEC mdpsp_sys_DeleteMetaKeyObjects @MetaClassId, @MetaFieldId
		IF @@ERROR <> 0 GOTO ERR

		IF @IsCatalogMetaClass = 0
		BEGIN
			-- Step 3. Delete Constrains
			EXEC mdpsp_sys_DeleteDContrainByTableAndField @MetaFieldOwnerTable, @MetaFieldName

			IF @@ERROR <> 0 GOTO ERR
			
			-- Step 4. Delete Field
			EXEC ('ALTER TABLE ['+@MetaFieldOwnerTable+'] DROP COLUMN [' + @MetaFieldName + ']')

			IF @@ERROR <> 0 GOTO ERR
			
			-- Update 2007/10/05: Remove meta field from Localization table (if table exists)
			SET @MetaFieldOwnerTable = @BaseMetaFieldOwnerTable + '_Localization'

			if exists (select * from dbo.sysobjects where id = object_id(@MetaFieldOwnerTable) and OBJECTPROPERTY(id, N'IsUserTable') = 1)
			begin
				-- a). Delete constraints
				EXEC mdpsp_sys_DeleteDContrainByTableAndField @MetaFieldOwnerTable, @MetaFieldName
				-- a). Drop column
				EXEC ('ALTER TABLE ['+@MetaFieldOwnerTable+'] DROP COLUMN [' + @MetaFieldName + ']')
			end
		END
		ELSE
		BEGIN
			-- Delete the appropriated property from both Property and Draft Property tables.
			DELETE FROM CatalogContentProperty WHERE MetaFieldId = @MetaFieldId AND MetaClassId = @MetaClassId
			DELETE FROM ecfVersionProperty WHERE MetaFieldId = @MetaFieldId AND MetaClassId = @MetaClassId
		END
	END

	-- Step 5. Delete Field Info Record
	DELETE FROM MetaClassMetaFieldRelation WHERE MetaFieldId = @MetaFieldId AND MetaClassId = @MetaClassId
	IF @@ERROR <> 0 GOTO ERR

	IF @IsAbstractClass = 0 AND @IsCatalogMetaClass = 0
	BEGIN
		EXEC mdpsp_sys_CreateMetaClassProcedure @MetaClassId

		IF @@ERROR <> 0 GOTO ERR
	END

	COMMIT TRAN
	RETURN
ERR:
	ROLLBACK TRAN

	RETURN @@Error
END

GO
-- end of creating SP mdpsp_sys_DeleteMetaFieldFromMetaClass

DECLARE @metaClassId int, @metaFieldId int
SET @metaClassId = (SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'LineItemEx')
SET @metaFieldId = (SELECT TOP 1 MetaFieldId from MetaField WHERE Name = 'Epi_FreeQuantity')

EXEC dbo.mdpsp_sys_DeleteMetaFieldFromMetaClass @MetaClassId, @MetaFieldId
EXEC dbo.mdpsp_sys_DeleteMetaField @MetaFieldId
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 5, 1, GETUTCDATE())
GO 

--endUpdatingDatabaseVersion 