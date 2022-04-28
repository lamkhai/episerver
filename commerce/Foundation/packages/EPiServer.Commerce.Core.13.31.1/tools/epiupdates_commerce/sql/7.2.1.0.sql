--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 2, @patch int = 1    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO

IF EXISTS (SELECT * FROM sysobjects WHERE id = object_id(N'[dbo].[mdpfn_sys_IsCatalogMetaDataTable]') AND xtype IN (N'FN', N'IF', N'TF'))
    DROP FUNCTION [dbo].[mdpfn_sys_IsCatalogMetaDataTable]
GO

CREATE FUNCTION [dbo].[mdpfn_sys_IsCatalogMetaDataTable]
(
	@tableName nvarchar(256)
)
RETURNS BIT
AS
BEGIN
	DECLARE @IsCatalogMetaClass BIT
    DECLARE @MetaClassId INT
    SET @MetaClassId = (SELECT MetaClassId FROM MetaClass WHERE TableName = @tableName)
    SET @IsCatalogMetaClass = (SELECT [dbo].[mdpfn_sys_IsInheritedFromMetaClass](@MetaClassId, 'CatalogEntry'))
	IF @IsCatalogMetaClass = 0
	    SET @IsCatalogMetaClass = (SELECT [dbo].[mdpfn_sys_IsInheritedFromMetaClass](@MetaClassId, 'CatalogNode'))
    RETURN @IsCatalogMetaClass
END
GO

IF EXISTS (SELECT * FROM sysobjects WHERE id = object_id(N'[dbo].[mdpfn_sys_IsInheritedFromMetaClass]') AND xtype IN (N'FN', N'IF', N'TF'))
    DROP FUNCTION [dbo].[mdpfn_sys_IsInheritedFromMetaClass]
GO

CREATE FUNCTION [dbo].[mdpfn_sys_IsInheritedFromMetaClass]
(
	@MetaClassId INT,
	@ParentClassName NVARCHAR(256)
)
RETURNS BIT
AS
BEGIN
    DECLARE @ParentClassId INT
	DECLARE @IsCatalogMetaClass Bit
    IF EXISTS(SELECT MetaClassId FROM MetaClass WHERE ParentClassId = (SELECT MetaClassId FROM MetaClass WHERE Name = @ParentClassName) AND MetaClassId = @MetaClassId)
    	RETURN 1
    ELSE
    BEGIN
	    SET @ParentClassId = ( SELECT ParentClassId FROM MetaClass WHERE MetaClassId = @MetaClassId )
	    IF @ParentClassId = 0
	    	RETURN 0
	    SET @IsCatalogMetaClass = (SELECT [dbo].[mdpfn_sys_IsInheritedFromMetaClass](@ParentClassId, @ParentClassName))
	END
	RETURN @IsCatalogMetaClass
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_CreateMetaClassProcedure]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mdpsp_sys_CreateMetaClassProcedure] 
GO

create procedure [dbo].[mdpsp_sys_CreateMetaClassProcedure]
    @MetaClassId int
as
begin
    set nocount on
    begin try
        declare @CRLF nchar(1) = CHAR(10)
        declare @MetaClassName nvarchar(256)
        declare @TableName sysname
        declare @IsEntryMetaClass bit = 0
        declare @IsNodeMetaClass bit = 0

        select @MetaClassName = Name, @TableName = TableName from MetaClass where MetaClassId = @MetaClassId
        SET @IsEntryMetaClass = (SELECT [dbo].[mdpfn_sys_IsInheritedFromMetaClass](@MetaClassId, 'CatalogEntry'))
        SET @IsNodeMetaClass = (SELECT [dbo].[mdpfn_sys_IsInheritedFromMetaClass](@MetaClassId, 'CatalogNode'))

        if @MetaClassName is null raiserror('Metaclass not found.',16,1)

        declare @azureCompatible bit
        SET @azureCompatible = (SELECT TOP 1 AzureCompatible FROM dbo.AzureCompatible)
        
        -- get required info for each field
        declare @ParameterIndex int
        declare @ColumnName sysname
        declare @FieldIsMultilanguage bit
        declare @FieldIsEncrypted bit
        declare @FieldIsNullable bit
        declare @ColumnDataType sysname
        declare fields cursor local for
            select
                mfindex.ParameterIndex,
                mf.Name as ColumnName,
                mf.MultiLanguageValue as FieldIsMultilanguage,
                mf.IsEncrypted as FieldIsEncrypted,
                mf.AllowNulls,
                mdt.SqlName + case
                        when mdt.Variable = 1 then '(' + CAST(mf.Length as nvarchar) + ')'
                        when mf.DataTypeId in (5,24) and mfprecis.Value is not null and mfscale.Value is not null then '(' + cast(mfprecis.Value as nvarchar) + ',' + cast(mfscale.Value as nvarchar) + ')'
                        else '' end as ColumnDataType
            from (
                select ROW_NUMBER() over (order by innermf.Name) as ParameterIndex, innermf.MetaFieldId
                from MetaField innermf
                where innermf.SystemMetaClassId = 0
                  and exists (select 1 from MetaClassMetaFieldRelation cfr where cfr.MetaClassId = @MetaClassId and cfr.MetaFieldId = innermf.MetaFieldId)) mfindex
            join MetaField mf on mfindex.MetaFieldId = mf.MetaFieldId
            join MetaDataType mdt on mf.DataTypeId = mdt.DataTypeId
            left outer join MetaAttribute mfprecis on mf.MetaFieldId = mfprecis.AttrOwnerId and mfprecis.AttrOwnerType = 2 and mfprecis.[Key] = 'MdpPrecision'
            left outer join MetaAttribute mfscale on mf.MetaFieldId = mfscale.AttrOwnerId and mfscale.AttrOwnerType = 2 and mfscale.[Key] = 'MdpScale'

        -- aggregate field parts into lists for stored procedures
        declare @ParameterName nvarchar(max)
        declare @ColumnReadBase nvarchar(max)
        declare @ColumnReadLocal nvarchar(max)
        declare @WriteValue nvarchar(max)
        declare @ParameterDefinitions nvarchar(max) = ''
        declare @UnlocalizedSelectValues nvarchar(max) = ''
        declare @LocalizedSelectValues nvarchar(max) = ''
        declare @AllInsertColumns nvarchar(max) = ''
        declare @AllInsertValues nvarchar(max) = ''
        declare @BaseInsertColumns nvarchar(max) = ''
        declare @BaseInsertValues nvarchar(max) = ''
        declare @LocalInsertColumns nvarchar(max) = ''
        declare @LocalInsertValues nvarchar(max) = ''
        declare @AllUpdateActions nvarchar(max) = ''
        declare @BaseUpdateActions nvarchar(max) = ''
        declare @LocalUpdateActions nvarchar(max) = ''
        open fields
        while 1=1
        begin
            fetch next from fields into @ParameterIndex, @ColumnName, @FieldIsMultilanguage, @FieldIsEncrypted, @FieldIsNullable, @ColumnDataType
            if @@FETCH_STATUS != 0 break

            set @ParameterName = '@f' + cast(@ParameterIndex as nvarchar(10))
            set @ColumnReadBase = case when @azureCompatible <> 1 and @FieldIsEncrypted = 1 then 'dbo.mdpfn_sys_EncryptDecryptString(T.[' + @ColumnName + '],0)' + ' as [' + @ColumnName + ']' else 'T.[' + @ColumnName + ']' end
            set @ColumnReadLocal = case when @azureCompatible <> 1 and @FieldIsEncrypted = 1 then 'dbo.mdpfn_sys_EncryptDecryptString(L.[' + @ColumnName + '],0)' + ' as [' + @ColumnName + ']' else 'L.[' + @ColumnName + ']' end
            set @WriteValue = case when @azureCompatible <> 1 and @FieldIsEncrypted = 1 then 'dbo.mdpfn_sys_EncryptDecryptString(' + @ParameterName + ',1)' else @ParameterName end

            set @ParameterDefinitions = @ParameterDefinitions + ',' + @ParameterName + ' ' + @ColumnDataType
            set @UnlocalizedSelectValues = @UnlocalizedSelectValues + ',' + @ColumnReadBase
            set @LocalizedSelectValues = @LocalizedSelectValues + ',' + case when @FieldIsMultilanguage = 1 then @ColumnReadLocal else @ColumnReadBase end
            set @AllInsertColumns = @AllInsertColumns + ',[' + @ColumnName + ']'
            set @AllInsertValues = @AllInsertValues + ',' + @WriteValue
            set @BaseInsertColumns = @BaseInsertColumns + case when @FieldIsMultilanguage = 0 then ',[' + @ColumnName + ']' else '' end
            set @BaseInsertValues = @BaseInsertValues + case when @FieldIsMultilanguage = 0 then ',' + @WriteValue else '' end
            set @LocalInsertColumns = @LocalInsertColumns + case when @FieldIsMultilanguage = 1 then ',[' + @ColumnName + ']' else '' end
            set @LocalInsertValues = @LocalInsertValues + case when @FieldIsMultilanguage = 1 then ',' + @WriteValue else '' end
            set @AllUpdateActions = @AllUpdateActions + ',[' + @ColumnName + ']=' + @WriteValue
            set @BaseUpdateActions = @BaseUpdateActions + ',[' + @ColumnName + ']=' + case when @FieldIsMultilanguage = 0 then @WriteValue when @FieldIsNullable = 1 then 'null' else 'default' end
            set @LocalUpdateActions = @LocalUpdateActions + ',[' + @ColumnName + ']=' + case when @FieldIsMultilanguage = 1 then @WriteValue when @FieldIsNullable = 1 then 'null' else 'default' end
        end
        close fields

        declare @OpenEncryptionKey nvarchar(max)
        declare @CloseEncryptionKey nvarchar(max)
        if exists(  select 1
                    from MetaField mf
                    join MetaClassMetaFieldRelation cfr on mf.MetaFieldId = cfr.MetaFieldId
                    where cfr.MetaClassId = @MetaClassId and mf.SystemMetaClassId = 0 and mf.IsEncrypted = 1) and @azureCompatible <> 1
        begin
            set @OpenEncryptionKey = 'exec mdpsp_sys_OpenSymmetricKey' + @CRLF
            set @CloseEncryptionKey = 'exec mdpsp_sys_CloseSymmetricKey' + @CRLF
        end
        else
        begin
            set @OpenEncryptionKey = ''
            set @CloseEncryptionKey = ''
        end

        -- create stored procedures
        declare @procedures table (name sysname, defn nvarchar(max), verb nvarchar(max))
        IF @IsEntryMetaClass = 1 OR @IsNodeMetaClass = 1
        BEGIN
            insert into @procedures (name, defn)
            values ('mdpsp_avto_' + @TableName + '_ListSpecificRecord',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_ListSpecificRecord] @Language nvarchar(20),@Count int as' + @CRLF +
                'begin' + @CRLF +
                    'if exists (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N''' + @TableName + ''') ' + @CRLF +
                    'begin' + @CRLF +
                        @OpenEncryptionKey +
                        'select TOP(@Count) T.ObjectId,C.IsActive,C.StartDate StartPublish,C.EndDate StopPublish,C.CatalogId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @LocalizedSelectValues + @CRLF +
                        'from [' + @TableName + '] T' + @CRLF +
                        'left join [' + @TableName + '_Localization] L on T.ObjectId=L.ObjectId and L.Language=@Language ' + @CRLF +
                        'inner join Catalog' + CASE WHEN @IsEntryMetaClass = 1 THEN 'Entry' ELSE 'Node' END + ' C on T.ObjectId = C.Catalog' + CASE WHEN @IsEntryMetaClass = 1 THEN 'Entry' ELSE 'Node' END + 'Id' + @CRLF +
                        'order by T.ObjectId ASC ' + @CRLF +
                        @CloseEncryptionKey +
                    'end' + @CRLF +
                'end' + @CRLF)

            insert into @procedures (name, defn)
            values ('mdpsp_avto_' + @TableName + '_DeleteSpecificRecord',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_DeleteSpecificRecord] @IdsToDelete dbo.udttIdTable readonly as' + @CRLF +
                'begin' + @CRLF +
                'DELETE M FROM [' + @TableName + '] M INNER JOIN @IdsToDelete I ON M.ObjectId = I.ID' + @CRLF +
                'DELETE M FROM [' + @TableName + '_Localization] M INNER JOIN @IdsToDelete I ON M.ObjectId = I.ID' + @CRLF +
                'end' + @CRLF)
        END
        ELSE
        BEGIN
            insert into @procedures (name, defn)
            values ('mdpsp_avto_' + @TableName + '_Get',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_Get] @ObjectId int,@Language nvarchar(20)=null as ' + @CRLF +
                'begin' + @CRLF +
                @OpenEncryptionKey +
                'if @Language is null select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @UnlocalizedSelectValues + @CRLF +
                'from [' + @TableName + '] T where ObjectId=@ObjectId' + @CRLF +
                'else select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @LocalizedSelectValues + @CRLF +
                'from [' + @TableName + '] T' + @CRLF +
                'left join [' + @TableName + '_Localization] L on T.ObjectId=L.ObjectId and L.Language=@Language' + @CRLF +
                'where T.ObjectId= @ObjectId' + @CRLF +
                @CloseEncryptionKey +
                'end' + @CRLF)

            insert into @procedures (name, defn)
            values ('mdpsp_avto_' + @TableName + '_Update',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_Update]' + @CRLF +
                '@ObjectId int,@Language nvarchar(20)=null,@CreatorId nvarchar(100),@Created datetime,@ModifierId nvarchar(100),@Modified datetime,@Retval int out' + @ParameterDefinitions + ' as' + @CRLF +
                'begin' + @CRLF +
                'set nocount on' + @CRLF +
                'declare @ins bit' + @CRLF +
                'begin try' + @CRLF +
                'begin transaction' + @CRLF +
                @OpenEncryptionKey +
                'if @ObjectId=-1 select @ObjectId=isnull(MAX(ObjectId),0)+1, @Retval=@ObjectId, @ins=0 from [' + @TableName + ']' + @CRLF +
                'else set @ins=case when exists(select 1 from [' + @TableName + '] where ObjectId=@ObjectId) then 0 else 1 end' + @CRLF +
                'if @Language is null' + @CRLF +
                'begin' + @CRLF +
                '  if @ins=1 insert [' + @TableName + '] (ObjectId,CreatorId,Created,ModifierId,Modified' + @AllInsertColumns + ')' + @CRLF +
                '  values (@ObjectId,@CreatorId,@Created,@ModifierId,@Modified' + @AllInsertValues + ')' + @CRLF +
                '  else update [' + @TableName + '] set CreatorId=@CreatorId,Created=@Created,ModifierId=@ModifierId,Modified=@Modified' + @AllUpdateActions + @CRLF +
                '  where ObjectId=@ObjectId' + @CRLF +
                'end' + @CRLF +
                'else' + @CRLF +
                'begin' + @CRLF +
                '  if @ins=1 insert [' + @TableName + '] (ObjectId,CreatorId,Created,ModifierId,Modified' + @BaseInsertColumns + ')' + @CRLF +
                '  values (@ObjectId,@CreatorId,@Created,@ModifierId,@Modified' + @BaseInsertValues + ')' + @CRLF +
                '  else update [' + @TableName + '] set CreatorId=@CreatorId,Created=@Created,ModifierId=@ModifierId,Modified=@Modified' + @BaseUpdateActions + @CRLF +
                '  where ObjectId=@ObjectId' + @CRLF +
                '  if not exists (select 1 from [' + @TableName + '_Localization] where ObjectId=@ObjectId and Language=@Language)' + @CRLF +
                '  insert [' + @TableName + '_Localization] (ObjectId,Language,ModifierId,Modified' + @LocalInsertColumns + ')' + @CRLF +
                '  values (@ObjectId,@Language,@ModifierId,@Modified' + @LocalInsertValues + ')' + @CRLF +
                '  else update [' + @TableName + '_Localization] set ModifierId=@ModifierId,Modified=@Modified' + @LocalUpdateActions + @CRLF +
                '  where ObjectId=@ObjectId and Language=@language' + @CRLF +
                'end' + @CRLF +
                @CloseEncryptionKey +
                'commit transaction' + @CRLF +
                'end try' + @CRLF +
                'begin catch' + @CRLF +
                '  declare @m nvarchar(4000),@v int,@t int' + @CRLF +
                '  select @m=ERROR_MESSAGE(),@v=ERROR_SEVERITY(),@t=ERROR_STATE()' + @CRLF +
                '  rollback transaction' + @CRLF +
                '  raiserror(@m, @v, @t)' + @CRLF +
                'end catch' + @CRLF +
                'end' + @CRLF)

            insert into @procedures (name, defn)
            values ('mdpsp_avto_' + @TableName + '_Delete',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_Delete] @ObjectId int as' + @CRLF +
                'begin' + @CRLF +
                'delete [' + @TableName + '] where ObjectId=@ObjectId' + @CRLF +
                'delete [' + @TableName + '_Localization] where ObjectId=@ObjectId' + @CRLF +
                'exec mdpsp_sys_DeleteMetaKeyObjects ' + CAST(@MetaClassId as nvarchar(10)) + ',-1,@ObjectId' + @CRLF +
                'end' + @CRLF)

            insert into @procedures (name, defn)
            values ('mdpsp_avto_' + @TableName + '_List',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_List] @Language nvarchar(20)=null,@select_list nvarchar(max)='''',@search_condition nvarchar(max)='''' as' + @CRLF +
                'begin' + @CRLF +
                @OpenEncryptionKey +
                'if @Language is null select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @UnlocalizedSelectValues + ' from [' + @TableName + '] T' + @CRLF +
                'else select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @LocalizedSelectValues + @CRLF +
                'from [' + @TableName + '] T' + @CRLF +
                'left join [' + @TableName + '_Localization] L on T.ObjectId=L.ObjectId and L.Language=@Language' + @CRLF +
                @CloseEncryptionKey +
                'end' + @CRLF)

            insert into @procedures (name, defn)
            values ('mdpsp_avto_' + @TableName + '_Search',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_Search] @Language nvarchar(20)=null,@select_list nvarchar(max)='''',@search_condition nvarchar(max)='''' as' + @CRLF +
                'begin' + @CRLF +
                'if len(@select_list)>0 set @select_list='',''+@select_list' + @CRLF +
                @OpenEncryptionKey +
                'if @Language is null exec(''select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @UnlocalizedSelectValues + '''+@select_list+'' from [' + @TableName + '] T ''+@search_condition)' + @CRLF +
                'else exec(''select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @LocalizedSelectValues + '''+@select_list+'' from [' + @TableName + '] T left join [' + @TableName + '_Localization] L on T.ObjectId=L.ObjectId and L.Language=@Language ''+@search_condition)' + @CRLF +
                @CloseEncryptionKey +
                'end' + @CRLF)
        END

        update tgt
        set verb = case when r.ROUTINE_NAME is null then 'create ' else 'alter ' end
        from @procedures tgt
        left outer join INFORMATION_SCHEMA.ROUTINES r on r.ROUTINE_SCHEMA COLLATE DATABASE_DEFAULT = 'dbo' and r.ROUTINE_NAME COLLATE DATABASE_DEFAULT = tgt.name COLLATE DATABASE_DEFAULT

        -- install procedures
        declare @sqlstatement nvarchar(max)
        declare procedure_cursor cursor local for select verb + defn from @procedures
        open procedure_cursor
        while 1=1
        begin
            fetch next from procedure_cursor into @sqlstatement
            if @@FETCH_STATUS != 0 break
            exec(@sqlstatement)
        end
        close procedure_cursor
    end try
    begin catch
        declare @m nvarchar(4000), @v int, @t int
        select @m = ERROR_MESSAGE(), @v = ERROR_SEVERITY(), @t = ERROR_STATE()
        raiserror(@m,@v,@t)
    end catch
end

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_CreateMetaClass]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mdpsp_sys_CreateMetaClass] 
GO

CREATE PROCEDURE [dbo].[mdpsp_sys_CreateMetaClass]
	@Namespace 		NVARCHAR(1024),
	@Name 		NVARCHAR(256),
	@FriendlyName		NVARCHAR(256),
	@TableName 		NVARCHAR(256),
	@ParentClassId 		INT,
	@IsSystem		BIT,
	@IsAbstract		BIT	=	0,
	@Description 		NTEXT,
	@Retval 		INT OUTPUT
AS
BEGIN
	-- Step 0. Prepare
	SET NOCOUNT ON
	SET @Retval = -1

BEGIN TRAN
	-- Step 1. Insert a new record in to the MetaClass table
	INSERT INTO [MetaClass] ([Namespace],[Name], [FriendlyName],[Description], [TableName], [ParentClassId], [PrimaryKeyName], [IsSystem], [IsAbstract])
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
		INSERT INTO [MetaField]  ([Namespace], [Name], [FriendlyName], [SystemMetaClassId], [DataTypeId], [Length], [AllowNulls],  [MultiLanguageValue], [AllowSearch], [IsEncrypted])
			 SELECT @Namespace+ N'.' + @Name, SC .[name] , SC .[name] , @Retval ,MDT .[DataTypeId], SC .[length], SC .[isnullable], 0, 0, 0  FROM syscolumns AS SC
				INNER JOIN sysobjects SO ON SO.[id] = SC.[id]
				INNER JOIN systypes ST ON ST.[xtype] = SC.[xtype]
				INNER JOIN MetaDataType MDT ON MDT.[Name] = ST.[name] COLLATE DATABASE_DEFAULT
			WHERE SO.[id]  = object_id( @TableName) and OBJECTPROPERTY( SO.[id], N'IsTable') = 1 and ST.name<>'sysname'
			ORDER BY colorder

		IF @@ERROR<> 0 GOTO ERR

		-- Step 3-2. Insert a new record in to the MetaClassMetaFieldRelation table
		INSERT INTO [MetaClassMetaFieldRelation]  (MetaClassId, MetaFieldId)
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

EXEC mdpsp_sys_CreateMetaClassProcedureAll
GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 2, 1, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
