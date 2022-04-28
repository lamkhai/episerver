--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 24    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[MetaClass]...';


GO
ALTER TABLE [dbo].[MetaClass] ALTER COLUMN [Description] NVARCHAR (MAX) NULL;

ALTER TABLE [dbo].[MetaClass] ALTER COLUMN [FieldListChangedSqlScript] NVARCHAR (MAX) NULL;


GO
PRINT N'Altering [dbo].[MetaField]...';


GO
ALTER TABLE [dbo].[MetaField] ALTER COLUMN [Description] NVARCHAR (MAX) NULL;


GO
PRINT N'Altering [dbo].[mdpsp_sys_UpdateMetaClass]...';


GO
ALTER PROCEDURE [dbo].[mdpsp_sys_UpdateMetaClass]
	@MetaClassId 	INT,
	@Namespace		NVARCHAR(1024),
	@Name			NVARCHAR(256),
	@FriendlyName	NVARCHAR(256),
	@Description	NVARCHAR(MAX),
	@Tag			IMAGE
AS
	UPDATE MetaClass SET Namespace = @Namespace, Name = @Name, FriendlyName = @FriendlyName, Description = @Description, Tag = @Tag WHERE MetaClassId = @MetaClassId
GO
PRINT N'Altering [dbo].[mdpsp_sys_UpdateMetaSqlScriptTemplate]...';


GO
ALTER PROCEDURE [dbo].[mdpsp_sys_UpdateMetaSqlScriptTemplate]
	@MetaClassId 	INT,
	@FieldListChanged	NVARCHAR(MAX)
AS
	UPDATE MetaClass SET FieldListChangedSqlScript = @FieldListChanged WHERE MetaClassId = @MetaClassId
GO
PRINT N'Altering [dbo].[mdpsp_sys_AddMetaField]...';


GO
ALTER PROCEDURE [dbo].[mdpsp_sys_AddMetaField]
	@Namespace 		NVARCHAR(1024) = N'Mediachase.MetaDataPlus.User',
	@Name		NVARCHAR(256),
	@FriendlyName	NVARCHAR(256),
	@Description	NVARCHAR(MAX),
	@DataTypeId	INT,
	@Length	INT,
	@AllowNulls	BIT,
	@MultiLanguageValue BIT,
	@AllowSearch	BIT,
	@IsEncrypted	BIT,
	@Retval 	INT OUTPUT
AS
BEGIN
	-- Step 0. Prepare
	SET NOCOUNT ON
	SET @Retval = -1

    BEGIN TRAN
	    DECLARE @DataTypeVariable	INT
	    DECLARE @DataTypeLength	INT

	    SELECT @DataTypeVariable = Variable, @DataTypeLength = Length FROM MetaDataType WHERE DataTypeId = @DataTypeId

	    IF (@Length <= 0 OR @Length > @DataTypeLength )
		    SET @Length = @DataTypeLength

	    -- Step 2. Insert a record in to MetaField table.
	    INSERT INTO [MetaField]  ([Namespace], [Name], [FriendlyName], [Description], [DataTypeId], [Length], [AllowNulls],  [MultiLanguageValue], [AllowSearch], [IsEncrypted])
		    VALUES(@Namespace, @Name,  @FriendlyName, @Description, @DataTypeId, @Length, @AllowNulls, @MultiLanguageValue, @AllowSearch, @IsEncrypted)

	    IF @@ERROR <> 0 GOTO ERR

	    SET @Retval = IDENT_CURRENT('[MetaField]')

	    COMMIT TRAN
    RETURN

ERR:
	SET @Retval = -1
	ROLLBACK TRAN
    RETURN
END
GO
PRINT N'Altering [dbo].[mdpsp_sys_UpdateMetaField]...';


GO
ALTER PROCEDURE [dbo].[mdpsp_sys_UpdateMetaField]
	@MetaFieldId 	INT,
	@Namespace 	NVARCHAR(1024) = N'Mediachase.MetaDataPlus.User',
	@FriendlyName	NVARCHAR(256),
	@Description	NVARCHAR(MAX),
	@Tag		IMAGE
AS
	UPDATE MetaField SET Namespace = @Namespace, FriendlyName = @FriendlyName, Description = @Description, Tag = @Tag WHERE MetaFieldId = @MetaFieldId
GO
PRINT N'Altering [dbo].[mdpsp_sys_AddMetaAttribute]...';


GO
ALTER PROCEDURE [dbo].[mdpsp_sys_AddMetaAttribute]
	@AttrOwnerId		INT,
	@AttrOwnerType	INT,
	@Key			NVARCHAR(256),
	@Value			NVARCHAR(MAX)
AS
	IF ( (SELECT COUNT(*) FROM MetaAttribute WHERE AttrOwnerId = @AttrOwnerId AND AttrOwnerType = @AttrOwnerType AND [Key] = @Key) = 0)
	BEGIN
		-- Insert
		INSERT INTO MetaAttribute (AttrOwnerId, AttrOwnerType, [Key], [Value] ) VALUES (@AttrOwnerId, @AttrOwnerType, @Key, @Value)
	END
	ELSE
	BEGIN
		-- Update
		UPDATE MetaAttribute SET [Value] = @Value  WHERE AttrOwnerId = @AttrOwnerId AND AttrOwnerType = @AttrOwnerType AND [Key] = @Key
	END
GO
PRINT N'Altering [dbo].[mdpsp_sys_CreateMetaClass]...';


GO
ALTER PROCEDURE [dbo].[mdpsp_sys_CreateMetaClass]
	@Namespace 		NVARCHAR(1024),
	@Name 		NVARCHAR(256),
	@FriendlyName		NVARCHAR(256),
	@TableName 		NVARCHAR(256),
	@ParentClassId 		INT,
	@IsSystem		BIT,
	@IsAbstract		BIT	=	0,
	@Description 		NVARCHAR(MAX),
	@Retval 		INT OUTPUT
AS
BEGIN
	-- Step 0. Prepare
	SET NOCOUNT ON
	SET @Retval = -1

BEGIN TRAN
	-- Step 1. Insert a new record in to the MetaClass table
	INSERT INTO [MetaClass] ([Namespace], [Name], [FriendlyName], [Description], [TableName], [ParentClassId], [PrimaryKeyName], [IsSystem], [IsAbstract])
		VALUES (@Namespace, @Name, @FriendlyName, @Description, @TableName, @ParentClassId, 'undefined', @IsSystem, @IsAbstract)

	IF @@ERROR <> 0 GOTO ERR

	SET @Retval = @@IDENTITY
	
	IF @IsSystem = 1
	BEGIN
		IF NOT EXISTS(SELECT * FROM sysobjects WHERE [name] = @TableName AND [type] = 'U')
		BEGIN
			RAISERROR ('Wrong System TableName.', 16,1 )
			GOTO ERR
		END

		-- Step 3-2. Insert a new record in to the MetaField table
		INSERT INTO [MetaField] ([Namespace], [Name], [FriendlyName], [SystemMetaClassId], [DataTypeId], [Length], [AllowNulls], [MultiLanguageValue], [AllowSearch], [IsEncrypted])
			 SELECT @Namespace + N'.' + @Name, SC.[name], SC.[name], @Retval, MDT.[DataTypeId], SC.[length], SC.[isnullable], 0, 0, 0  FROM syscolumns AS SC
				INNER JOIN sysobjects SO ON SO.[id] = SC.[id]
				INNER JOIN systypes ST ON ST.[xtype] = SC.[xtype]
				INNER JOIN MetaDataType MDT ON LOWER(MDT.[Name]) = LOWER(ST.[name]) COLLATE DATABASE_DEFAULT
			WHERE SO.[id] = OBJECT_ID(@TableName) AND OBJECTPROPERTY(SO.[id], N'IsTable') = 1 AND ST.[name]<>'sysname'
			ORDER BY colorder

		IF @@ERROR<> 0 GOTO ERR

		-- Step 3-2. Insert a new record in to the MetaClassMetaFieldRelation table
		INSERT INTO [MetaClassMetaFieldRelation] (MetaClassId, MetaFieldId)
			SELECT @Retval, MetaFieldId FROM MetaField WHERE [SystemMetaClassId] = @Retval
	END
	ELSE
	BEGIN
		IF @IsAbstract = 0
		BEGIN
			DECLARE @IsCatalogMetaClass BIT
			SET @IsCatalogMetaClass = dbo.mdpfn_sys_IsInheritedFromMetaClass(@Retval, 'CatalogEntry')
			IF @IsCatalogMetaClass = 0 	SET @IsCatalogMetaClass = dbo.mdpfn_sys_IsInheritedFromMetaClass(@Retval, 'CatalogNode')
			
			IF EXISTS(SELECT * FROM MetaClass WHERE MetaClassId = @ParentClassId /* AND @IsSystem = 1 */ )
			BEGIN
				-- Step 3-2. Insert a new record in to the MetaClassMetaFieldRelation table
				INSERT INTO [MetaClassMetaFieldRelation]  (MetaClassId, MetaFieldId)
					SELECT @Retval, MetaFieldId FROM MetaField WHERE [SystemMetaClassId] = @ParentClassId
			END

			IF @@ERROR<> 0 GOTO ERR
			
			IF @IsCatalogMetaClass = 0
			BEGIN
				-- Step 2. Create the @TableName table.
				EXEC('CREATE TABLE [dbo].[' + @TableName  + '] ([ObjectId] [int] NOT NULL , [CreatorId] [nvarchar](100), [Created] [datetime], [ModifierId] [nvarchar](100) , [Modified] [datetime] )')

				IF @@ERROR <> 0 GOTO ERR

				EXEC('ALTER TABLE [dbo].[' + @TableName  + '] WITH NOCHECK ADD CONSTRAINT [PK_' + @TableName  + '] PRIMARY KEY  CLUSTERED ([ObjectId])')

				IF @@ERROR <> 0 GOTO ERR

				-- Step 2-2. Create the @TableName_Localization table
				EXEC('CREATE TABLE [dbo].[' + @TableName + '_Localization] ([Id] [int] IDENTITY (1, 1)  NOT NULL, [ObjectId] [int] NOT NULL , [ModifierId] [nvarchar](100), [Modified] [datetime], [Language] nvarchar(20) NOT NULL)')

				IF @@ERROR<> 0 GOTO ERR

				EXEC('ALTER TABLE [dbo].[' + @TableName  + '_Localization] WITH NOCHECK ADD CONSTRAINT [PK_' + @TableName  + '_Localization] PRIMARY KEY  CLUSTERED ([Id])')

				IF @@ERROR<> 0 GOTO ERR

				EXEC ('CREATE NONCLUSTERED INDEX IX_' + @TableName + '_Localization_Language ON dbo.' + @TableName + '_Localization ([Language])')

				IF @@ERROR<> 0 GOTO ERR

				EXEC ('CREATE UNIQUE NONCLUSTERED INDEX IX_' + @TableName + '_Localization_ObjectId ON dbo.' + @TableName + '_Localization (ObjectId,[Language])')

				IF @@ERROR<> 0 GOTO ERR
				
				declare @system_root_class_id int
				;with cte as (
					select MetaClassId, ParentClassId, IsSystem
					from MetaClass
					where MetaClassId = @ParentClassId
					union all
					select mc.MetaClassId, mc.ParentClassId, mc.IsSystem
					from cte
					join MetaClass mc on cte.ParentClassId = mc.MetaClassId and cte.IsSystem = 0
				)
				select @system_root_class_id = MetaClassId
				from cte
				where IsSystem = 1

				if exists (select 1 from MetaClass where MetaClassId = @ParentClassId and IsSystem = 1)
				begin
					declare @parent_table sysname
					declare @parent_key_column sysname
					select @parent_table = mc.TableName, @parent_key_column = c.name
					from MetaClass mc
					join sys.key_constraints kc on kc.parent_object_id = OBJECT_ID('[dbo].[' + mc.TableName + ']', 'U')
					join sys.index_columns ic on kc.parent_object_id = ic.object_id and kc.unique_index_id = ic.index_id
					join sys.columns c on ic.object_id = c.object_id and ic.column_id = c.column_id
					where mc.MetaClassId = @system_root_class_id
						and kc.type = 'PK'
						and ic.index_column_id = 1
					
					declare @child_table nvarchar(4000)
					declare child_tables cursor local for select @TableName as table_name union all select @TableName + '_Localization'
					open child_tables
					while 1=1
					begin
						fetch next from child_tables into @child_table
						if @@FETCH_STATUS != 0 break
						
						declare @fk_name nvarchar(4000) = 'FK_' + @child_table + '_' + @parent_table
						
						declare @pdeletecascade nvarchar(30) = ' on delete cascade'
						if (@child_table like '%_Localization'
							and @Namespace = 'Mediachase.Commerce.Orders.System') 
							begin
							set @pdeletecascade = ''
							end

						declare @fk_sql nvarchar(4000) =
							'alter table [dbo].[' + @child_table + '] add ' +
							case when LEN(@fk_name) <= 128 then 'constraint [' + @fk_name + '] ' else '' end +
							'foreign key (ObjectId) references [dbo].[' + @parent_table + '] ([' + @parent_key_column + '])'+ @pdeletecascade + ' on update cascade'
													
						execute dbo.sp_executesql @fk_sql
					end
					close child_tables
					
					if @@ERROR != 0 goto ERR
				end

				EXEC mdpsp_sys_CreateMetaClassProcedure @Retval
				IF @@ERROR <> 0 GOTO ERR
			END
		END
	END

	-- Update PK Value
	DECLARE @PrimaryKeyName	NVARCHAR(256)
	SELECT @PrimaryKeyName = name FROM sysobjects WHERE OBJECTPROPERTY(id, N'IsPrimaryKey') = 1 and parent_obj = OBJECT_ID(@TableName) and OBJECTPROPERTY(parent_obj, N'IsUserTable') = 1

	IF @PrimaryKeyName IS NOT NULL
		UPDATE [MetaClass] SET PrimaryKeyName = @PrimaryKeyName WHERE MetaClassId = @Retval

	COMMIT TRAN
RETURN

ERR:
	ROLLBACK TRAN
	SET @Retval = -1
RETURN
END
GO
PRINT N'Refreshing [dbo].[ecf_CatalogContentTypeGetUsage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogContentTypeGetUsage]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogContentTypeIsUsed]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogContentTypeIsUsed]';


GO
PRINT N'Refreshing [dbo].[ecf_OrderSearch]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_OrderSearch]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_Payment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_Payment]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_CheckReplaceUser]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_CheckReplaceUser]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_CreateMetaClassProcedure]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_CreateMetaClassProcedure]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_CreateMetaClassProcedureAll]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_CreateMetaClassProcedureAll]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_DeleteMetaClassProcedure]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_DeleteMetaClassProcedure]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_GetMetaKey]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_GetMetaKey]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_LoadChildMetaClassList]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_LoadChildMetaClassList]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_LoadDictionarySingleItemUsages]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_LoadDictionarySingleItemUsages]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_LoadMetaClassById]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_LoadMetaClassById]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_LoadMetaClassByName]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_LoadMetaClassByName]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_LoadMetaClassByNamespace]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_LoadMetaClassByNamespace]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_LoadMetaClassList]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_LoadMetaClassList]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_LoadMetaClassListByMetaField]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_LoadMetaClassListByMetaField]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_MetaFieldAllowMultiLanguage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_MetaFieldAllowMultiLanguage]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_MetaFieldIsEncrypted]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_MetaFieldIsEncrypted]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_RefreshSystemMetaClassInfo]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_RefreshSystemMetaClassInfo]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_RefreshSystemMetaClassInfoAll]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_RefreshSystemMetaClassInfoAll]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_RegisterMetaFieldInSystemClass]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_RegisterMetaFieldInSystemClass]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_ReplaceUser]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_ReplaceUser]';


GO
PRINT N'Refreshing [dbo].[ecf_Load_OrderGroup]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Load_OrderGroup]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_OrderGroup]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_OrderGroup]';


GO
PRINT N'Refreshing [dbo].[ecf_Load_PaymentPlan_OrderGroupId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Load_PaymentPlan_OrderGroupId]';


GO
PRINT N'Refreshing [dbo].[ecf_Load_PurchaseOrder_OrderGroupId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Load_PurchaseOrder_OrderGroupId]';


GO
PRINT N'Refreshing [dbo].[ecf_Load_ShoppingCart_OrderGroupId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Load_ShoppingCart_OrderGroupId]';


GO
PRINT N'Refreshing [dbo].[ecf_GetMostRecentOrder]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_GetMostRecentOrder]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_PaymentPlan_Customer]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_PaymentPlan_Customer]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_PaymentPlan_CustomerAndName]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_PaymentPlan_CustomerAndName]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_PurchaseOrder_Customer]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_PurchaseOrder_Customer]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_PurchaseOrder_CustomerAndName]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_PurchaseOrder_CustomerAndName]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_ShoppingCart_Customer]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_ShoppingCart_Customer]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_ShoppingCart_CustomerAndName]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_ShoppingCart_CustomerAndName]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_Load]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_Load]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_LoadAllLanguages]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_LoadAllLanguages]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_LoadBatch]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_LoadBatch]';


GO
PRINT N'Refreshing [dbo].[ecf_PropertyDefinitionGetUsage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_PropertyDefinitionGetUsage]';


GO
PRINT N'Refreshing [dbo].[ecf_PropertyDefinitionIsUsed]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_PropertyDefinitionIsUsed]';


GO
PRINT N'Refreshing [dbo].[ecfVersionProperty_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersionProperty_ListByWorkIds]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_AddMetaDictionary]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_AddMetaDictionary]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_DeleteMetaField]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_DeleteMetaField]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_GetUniqueFieldName]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_GetUniqueFieldName]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_LoadMetaDictionary]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_LoadMetaDictionary]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_LoadMetaField]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_LoadMetaField]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_LoadMetaFieldByName]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_LoadMetaFieldByName]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_LoadMetaFieldByNamespace]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_LoadMetaFieldByNamespace]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_LoadMetaFieldList]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_LoadMetaFieldList]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_LoadMetaFieldListByMetaClassId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_LoadMetaFieldListByMetaClassId]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_MetaFieldAllowNulls]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_MetaFieldAllowNulls]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_MetaFieldAllowSearch]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_MetaFieldAllowSearch]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_UpdateMetaDictionary]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_UpdateMetaDictionary]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByCatalogWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByCatalogWorkIds]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByEntryWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByEntryWorkIds]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByNodeWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByNodeWorkIds]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_AddMetaFieldToMetaClass]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_AddMetaFieldToMetaClass]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_DeleteMetaClass]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_DeleteMetaClass]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_PaymentPlan]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_PaymentPlan]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_PurchaseOrder]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_PurchaseOrder]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_ShoppingCart]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_ShoppingCart]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 24, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
