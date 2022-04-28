--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 0, @patch int = 11    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[ecf_ApplicationLog_DeletedEntries]...';


GO
ALTER PROCEDURE [dbo].[ecf_ApplicationLog_DeletedEntries]
	@lastBuild datetime  
AS
BEGIN

SELECT [ObjectKey]
	  ,[ObjectType]
	  ,[Username]
	  ,[Created]
  FROM [dbo].[ApplicationLog]
  WHERE 
  ObjectType = 'entry' 
  AND Source = 'catalog'
  AND Operation = 'Deleted'
  AND Created > @lastBuild

END
GO
PRINT N'Altering [dbo].[ecf_OrderSearch]...';


GO
ALTER PROCEDURE [dbo].[ecf_OrderSearch]
(
	@SQLClause 					nvarchar(max),
	@MetaSQLClause 				nvarchar(max),
	@OrderBy 					nvarchar(max),
	@Namespace					nvarchar(1024) = N'',
	@Classes					nvarchar(max) = N'',
	@StartingRec 				int,
	@NumRecords   				int,
	@RecordCount                int OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @query_tmp nvarchar(max)
	DECLARE @FilterQuery_tmp nvarchar(max)
	DECLARE @TableName_tmp sysname
	DECLARE @SelectMetaQuery_tmp nvarchar(max)
	DECLARE @FromQuery_tmp nvarchar(max)
	DECLARE @FullQuery nvarchar(max)
	DECLARE @SelectQuery nvarchar(max)
	DECLARE @CountQuery nvarchar(max)

	-- 1. Cycle through all the available product meta classes
	--print 'Iterating through meta classes'
	DECLARE MetaClassCursor CURSOR READ_ONLY
	FOR SELECT TableName FROM MetaClass 
		WHERE Namespace like @Namespace + '%' AND ([Name] in (select Item from ecf_splitlist(@Classes)) or @Classes = '')
		and IsSystem = 0

	OPEN MetaClassCursor
	FETCH NEXT FROM MetaClassCursor INTO @TableName_tmp
	WHILE (@@fetch_status = 0)
	BEGIN 
		--print 'Metaclass Table: ' + @TableName_tmp
		set @Query_tmp = 'select META.ObjectId as ''Key'' from ' + @TableName_tmp + ' META'
		
		-- Add meta Where clause
		if(LEN(@MetaSQLClause)>0)
			set @query_tmp = @query_tmp + ' WHERE ' + @MetaSQLClause

		if(@SelectMetaQuery_tmp is null)
			set @SelectMetaQuery_tmp = @Query_tmp;
		else
			set @SelectMetaQuery_tmp = @SelectMetaQuery_tmp + N' UNION ALL ' + @Query_tmp;

	FETCH NEXT FROM MetaClassCursor INTO @TableName_tmp
	END
	CLOSE MetaClassCursor
	DEALLOCATE MetaClassCursor

	-- Create from command
	SET @FromQuery_tmp = N' INNER JOIN (select distinct U.[Key] from (' + @SelectMetaQuery_tmp + N') U) META ON OrderGroup.[OrderGroupId] = META.[Key] '

	set @FilterQuery_tmp = N' WHERE 1=1'
	-- add sql clause statement here, if specified
	if(Len(@SQLClause) != 0)
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND (' + @SqlClause + ')'
		
	if(Len(@OrderBy) = 0)
	begin
		set @OrderBy = ' OrderGroupId DESC'
	end

	set @SelectQuery = N'SELECT OrderGroupId'  + 
		' FROM dbo.OrderGroup OrderGroup ' + @FromQuery_tmp + @FilterQuery_tmp + ' ORDER BY ' + @OrderBy +
		' OFFSET '  + cast(@StartingRec as nvarchar(50)) + '  ROWS ' +
		' FETCH NEXT ' + cast(@NumRecords as nvarchar(50)) + ' ROWS ONLY ;';
	set @CountQuery= N'SET @RecordCount= (SELECT Count(1) FROM dbo.OrderGroup OrderGroup ' + @FromQuery_tmp + @FilterQuery_tmp +');';

	IF (@NumRecords = 0)
	BEGIN
		set @FullQuery =  @CountQuery
	END
	ELSE 
	BEGIN
		set @FullQuery =  @CountQuery+ @SelectQuery;
	END

	--print @FullQuery
	exec sp_executesql @FullQuery, N'@RecordCount int output', @RecordCount = @RecordCount OUTPUT

	SET NOCOUNT OFF
END
GO
PRINT N'Altering [dbo].[ecfVersion_ListFiltered]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_ListFiltered]
(
    @ObjectId INT = NULL,
    @ObjectTypeId INT = NULL,
    @ModifiedBy NVARCHAR(255) = NULL,
    @Languages [udttLanguageCode] READONLY,
    @Statuses [udttIdTable] READONLY,
    @StartIndex INT,
    @MaxRows INT
)
AS

BEGIN    
    SET NOCOUNT ON

    DECLARE @StatusCount INT
    SELECT @StatusCount = COUNT(*) FROM @Statuses

    DECLARE @LanguageCount INT
    SELECT @LanguageCount = COUNT(*) FROM @Languages

    DECLARE @query NVARCHAR(2000)

    SET @query = ''
 
    -- Build WHERE clause, only add the condition if specified
    DECLARE @Where NVARCHAR(1000) = ' FROM ecfVersion vn WHERE [dbo].ecf_IsCurrentLanguageRemoved(vn.CatalogId, vn.LanguageName) = 0 '
    IF @ObjectId IS NOT NULL
    SET @Where = @Where + ' AND ObjectId  = @ObjectId '
    IF @ObjectTypeId IS NOT NULL
    SET @Where = @Where + ' AND ObjectTypeId = @ObjectTypeId '
    IF @ModifiedBy IS NOT NULL
    SET @Where = @Where + ' AND ModifiedBy = @ModifiedBy '

    -- Optimized for case where only one Status or LanguageName is specified
    -- Otherwise SQL Server will use join even if we are querying for only one Status or Language (most common cases), which is ineffecient
    IF @StatusCount > 1
    BEGIN
    SET @Where = @Where + ' AND [Status] IN (SELECT ID FROM @Statuses) '
    END
    ELSE IF @StatusCount = 1
    BEGIN
    SET @Where = @Where + ' AND [Status] = (SELECT TOP (1) ID FROM @Statuses) '
    END
    IF @LanguageCount > 1
    BEGIN
    SET @Where = @Where + ' AND [LanguageName] IN (SELECT LanguageCode FROM @Languages) '
    END
    ELSE IF @LanguageCount = 1
    BEGIN
    SET @Where = @Where + ' AND [LanguageName] IN (SELECT TOP (1) LanguageCode FROM @Languages) '
    END

    SET @query = @Where

    DECLARE @filter NVARCHAR(2000)

    SET @filter = 'SELECT COUNT(WorkId) AS TotalRows ' + @query

    IF (@MaxRows > 0)
    BEGIN
        SET @filter = @filter + 
        ';SELECT WorkId, ObjectId, ObjectTypeId, Name, LanguageName, MasterLanguageName, IsCommonDraft, StartPublish, ModifiedBy, Modified, [Status] '
        + @query +
        ' ORDER BY  Modified DESC
        OFFSET '  + CAST(@StartIndex AS NVARCHAR(50)) + '  ROWS 
        FETCH NEXT ' + CAST(@MaxRows AS NVARCHAR(50)) + ' ROWS ONLY';
    END

    EXEC sp_executesql @filter,
    N'@ObjectId int, @ObjectTypeId int, @ModifiedBy nvarchar(255), @Statuses [udttIdTable] READONLY, @Languages [udttLanguageCode] READONLY',
    @ObjectId = @ObjectId, @ObjectTypeId = @ObjectTypeId, @ModifiedBy = @ModifiedBy, @Statuses = @Statuses, @Languages = @Languages
     
END
GO
PRINT N'Altering [dbo].[mdpsp_sys_CreateMetaClassProcedure]...';


GO
ALTER procedure [dbo].[mdpsp_sys_CreateMetaClassProcedure]
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
						'inner join Catalog cat on cat.CatalogId = C.CatalogId ' + @CRLF +
						'inner join CatalogLanguage cl on cl.CatalogId = cat.CatalogId and cl.LanguageCode = @Language ' + @CRLF +
						'where C.MetaClassId = ' + CAST(@MetaClassId AS VARCHAR(16)) + @CRLF +
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
				'DECLARE @AffectedMetaKeys udttIdTable ' + @CRLF +
					'INSERT INTO @AffectedMetaKeys ' + @CRLF +
				'SELECT MK.MetaKey ' + @CRLF +
					'FROM MetaKey MK ' + @CRLF +
				'WHERE MK.MetaObjectId = @ObjectId '  + @CRLF +
				'AND MK.MetaClassId = '+ CAST(@MetaClassId as nvarchar(10))  + @CRLF +
                'exec mdpsp_sys_DeleteMetaKeyObjects @AffectedMetaKeys ' + @CRLF +
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
PRINT N'Altering [dbo].[mdpsp_sys_DeleteMetaKeyObjects]...';


GO
ALTER PROCEDURE [dbo].[mdpsp_sys_DeleteMetaKeyObjects]
	@MetaKeys	[dbo].[udttIdTable] READONLY
	
AS
BEGIN	
	
	IF EXISTS (SELECT 1 FROM @MetaKeys)
	BEGIN
		-- Delete MetaObjectValue
		DELETE MO FROM MetaObjectValue MO INNER JOIN @MetaKeys M ON MO.MetaKey = M.ID
		
		-- Delete MetaStringDictionaryValue
		DELETE MSD FROM MetaStringDictionaryValue MSD INNER JOIN @MetaKeys M ON MSD.MetaKey = M.ID
		
		--Delete MetaMultiValueDictionary
		DELETE MV FROM MetaMultiValueDictionary MV INNER JOIN @MetaKeys M ON MV.MetaKey = M.ID
		
		--Delete MetaFileValue
		DELETE MF FROM MetaFileValue MF INNER JOIN @MetaKeys M ON MF.MetaKey = M.ID
		
		--Delete MetaKey
		DELETE MK FROM MetaKey MK INNER JOIN @MetaKeys M ON MK.MetaKey = M.ID
		
	END
END
GO
PRINT N'Altering [dbo].[CatalogEntry_Delete]...';


GO
ALTER TRIGGER [dbo].[CatalogEntry_Delete] ON CatalogEntry FOR DELETE
AS
	--Delete all draft of deleted entries
	DELETE d FROM ecfVersion d
	INNER JOIN deleted ON d.ObjectId = deleted.CatalogEntryId AND d.ObjectTypeId = 0

	--Delete all extra info of deleted entries
	DELETE c FROM CatalogContentEx c 
	INNER JOIN deleted ON c.ObjectId = deleted.CatalogEntryId AND c.ObjectTypeId = 0

	--Delete all properties of deleted entries
	DELETE p FROM CatalogContentProperty p
	INNER JOIN deleted ON p.ObjectId = deleted.CatalogEntryId AND p.ObjectTypeId = 0

	--Only need to delete metakey objects if they exist
	DECLARE @AffectedMetaKeys udttIdTable
	INSERT INTO @AffectedMetaKeys
	SELECT DISTINCT MK.MetaKey
	FROM MetaKey MK
		INNER JOIN deleted D
		ON MK.MetaObjectId = D.CatalogEntryId AND MK.MetaClassId = D.MetaClassId
	
	EXEC mdpsp_sys_DeleteMetaKeyObjects @AffectedMetaKeys
GO
PRINT N'Altering [dbo].[CatalogNode_Delete]...';


GO
ALTER TRIGGER [dbo].[CatalogNode_Delete] ON CatalogNode FOR DELETE
AS
	--Delete all draft of deleted nodes
	DELETE d FROM ecfVersion d
	INNER JOIN deleted ON d.ObjectId = deleted.CatalogNodeId AND d.ObjectTypeId = 1

	--Delete all extra info of deleted nodes
	DELETE c FROM CatalogContentEx c 
	INNER JOIN deleted ON c.ObjectId = deleted.CatalogNodeId AND c.ObjectTypeId = 1

	--Delete all properties of deleted nodes
	DELETE p FROM CatalogContentProperty p
	INNER JOIN deleted ON p.ObjectId = deleted.CatalogNodeId AND p.ObjectTypeId = 1

	DECLARE @AffectedMetaKeys udttIdTable
	INSERT INTO @AffectedMetaKeys
	SELECT MK.MetaKey
	FROM MetaKey MK
		INNER JOIN deleted D
		ON MK.MetaObjectId = D.CatalogNodeId AND MK.MetaClassId = D.MetaClassId
	
	EXEC mdpsp_sys_DeleteMetaKeyObjects  @MetaKeys = @AffectedMetaKeys
GO
PRINT N'Altering [dbo].[CatalogContentProperty_DeleteByObjectId]...';


GO
ALTER PROCEDURE [dbo].[CatalogContentProperty_DeleteByObjectId]
	@ObjectId int,
	@ObjectTypeId int
AS
BEGIN

	DECLARE @ClassId INT
	SELECT @ClassId = T.MetaClassId
	FROM
		(SELECT CatalogEntryId AS ObjectId, 0 AS ObjectTypeId, MetaClassId FROM CatalogEntry
			UNION ALL
		SELECT CatalogNodeId AS ObjectId, 1 AS ObjectTypeId, MetaClassId FROM CatalogNode) T
	 WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId

	--Delete published version
	DELETE CatalogContentProperty WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId
	
	DECLARE @AffectedMetaKeys udttIdTable
	INSERT INTO @AffectedMetaKeys
	SELECT MK.MetaKey
		FROM MetaKey MK
	WHERE MK.MetaObjectId = @ObjectId 
	AND MK.MetaClassId = @ClassId

	-- Delete data for all reference type meta fields (dictionaries etc)
	exec mdpsp_sys_DeleteMetaKeyObjects @AffectedMetaKeys 

END
GO
PRINT N'Altering [dbo].[ecfVersion_DeleteByWorkId]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_DeleteByWorkId]
	@WorkId int
AS
BEGIN
	DECLARE @MetaClassId INT
	DECLARE @ObjectId INT
	
	SELECT @MetaClassId = T.MetaClassId, @ObjectId = V.ObjectId
	FROM ecfVersion V
		INNER JOIN
		(SELECT CatalogEntryId AS ObjectId, 0 AS ObjectTypeId, MetaClassId FROM CatalogEntry
			UNION ALL
		SELECT CatalogNodeId AS ObjectId, 1 AS ObjectTypeId, MetaClassId FROM CatalogNode) T
		ON V.ObjectId = T.ObjectId AND V.ObjectTypeId = T.ObjectTypeId
	 WHERE V.WorkId = @WorkId

	DELETE FROM ecfVersion
	WHERE WorkId = @WorkId
	DECLARE @AffectedMetaKeys udttIdTable
		INSERT INTO @AffectedMetaKeys
			SELECT MK.MetaKey
			FROM MetaKey MK
			WHERE MK.MetaClassId = @MetaClassId
			AND MK.MetaObjectId = @ObjectId
			AND MK.WorkId = @WorkId

	-- Delete data for all reference type meta fields (dictionaries etc)
	EXEC mdpsp_sys_DeleteMetaKeyObjects @AffectedMetaKeys
END
GO
PRINT N'Altering [dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]...';


GO
ALTER PROCEDURE [dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]
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
		DECLARE @AffectedMetaKeys udttIdTable
		INSERT INTO @AffectedMetaKeys
			SELECT MK.MetaKey
			FROM MetaKey MK
			WHERE MK.MetaClassId = @MetaClassId
			AND MK.MetaFieldId = @MetaFieldId 
			
		EXEC mdpsp_sys_DeleteMetaKeyObjects @AffectedMetaKeys
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
PRINT N'Altering [dbo].[mdpsp_sys_DeleteMetaClass]...';


GO
ALTER PROCEDURE [dbo].[mdpsp_sys_DeleteMetaClass]
	@MetaClassId	INT
AS
BEGIN
	-- Step 0. Prepare
	SET NOCOUNT ON

	BEGIN TRAN

	DECLARE @MetaFieldOwnerTable	NVARCHAR(256)

	-- Check Childs Table
	IF EXISTS(SELECT *  FROM MetaClass MC WHERE ParentClassId = @MetaClassId)
	BEGIN
		RAISERROR ('The class have childs.', 16, 1)
		GOTO ERR
	END

	-- Step 1. Find a TableName
	IF EXISTS(SELECT *  FROM MetaClass MC WHERE MetaClassId = @MetaClassId)
	BEGIN
		IF EXISTS(SELECT *  FROM MetaClass MC WHERE MetaClassId = @MetaClassId AND IsSystem = 0 AND IsAbstract = 0)
		BEGIN
			SELECT @MetaFieldOwnerTable = TableName  FROM MetaClass MC WHERE MetaClassId = @MetaClassId AND IsSystem = 0 AND IsAbstract = 0

			IF @@ERROR <> 0 GOTO ERR

			EXEC mdpsp_sys_DeleteMetaClassProcedure @MetaClassId

			IF @@ERROR <> 0 GOTO ERR

			-- Step 2. Delete Table or View
			IF dbo.mdpfn_sys_IsCatalogMetaDataTable(@MetaFieldOwnerTable) = 1
			BEGIN
				EXEC('DROP VIEW [dbo].[' + @MetaFieldOwnerTable + ']')
				IF @@ERROR <> 0 GOTO ERR

				EXEC('DROP VIEW [dbo].[' + @MetaFieldOwnerTable + '_Localization]')
				IF @@ERROR <> 0 GOTO ERR
			END
			ELSE
			BEGIN
				EXEC('DROP TABLE [dbo].[' + @MetaFieldOwnerTable + ']')
				IF @@ERROR <> 0 GOTO ERR

				EXEC('DROP TABLE [dbo].[' + @MetaFieldOwnerTable + '_Localization]')
				IF @@ERROR <> 0 GOTO ERR
			END
			DECLARE @AffectedMetaKeys udttIdTable
			INSERT INTO @AffectedMetaKeys
				SELECT MK.MetaKey
			FROM MetaKey MK
			WHERE MK.MetaClassId = @MetaClassId
			
			EXEC mdpsp_sys_DeleteMetaKeyObjects @AffectedMetaKeys
			 IF @@ERROR <> 0 GOTO ERR

			-- Delete Meta Attribute
			EXEC mdpsp_sys_ClearMetaAttribute @MetaClassId, 1

			 IF @@ERROR <> 0 GOTO ERR

			-- Step 3. Delete MetaField Relations
			DELETE FROM MetaClassMetaFieldRelation WHERE MetaClassId = @MetaClassId

			IF @@ERROR <> 0 GOTO ERR

			-- Step 3. Delete MetaClass
			DELETE FROM MetaClass WHERE MetaClassId = @MetaClassId

			IF @@ERROR <> 0 GOTO ERR
		END
		ELSE
		BEGIN
			-- Delete Meta Attribute
			EXEC mdpsp_sys_ClearMetaAttribute @MetaClassId, 1

			 IF @@ERROR <> 0 GOTO ERR

			-- Step 3. Delete MetaField Relations
			DELETE FROM MetaClassMetaFieldRelation WHERE MetaClassId = @MetaClassId

			IF @@ERROR <> 0 GOTO ERR

			-- Step 3. Delete MetaField
			DELETE FROM MetaField WHERE SystemMetaClassId = @MetaClassId

			IF @@ERROR <> 0 GOTO ERR

			-- Step 3. Delete MetaClass
			DELETE FROM MetaClass WHERE MetaClassId = @MetaClassId

			IF @@ERROR <> 0 GOTO ERR

		END
		
		
	END
	ELSE
	BEGIN
		RAISERROR ('Wrong @MetaClassId.', 16, 1)
		GOTO ERR
	END

	COMMIT TRAN
	RETURN

ERR:
	ROLLBACK TRAN
	RETURN
END
GO

PRINT N'Recreated all MetaDataPlus auto stored procedures...';
GO

EXECUTE mdpsp_sys_CreateMetaClassProcedureAll
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
PRINT N'Refreshing [dbo].[mdpsp_sys_AddMetaFieldToMetaClass]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_AddMetaFieldToMetaClass]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_CreateMetaClass]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_CreateMetaClass]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_CreateMetaClassProcedureAll]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_CreateMetaClassProcedureAll]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_MetaFieldAllowMultiLanguage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_MetaFieldAllowMultiLanguage]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_MetaFieldIsEncrypted]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_MetaFieldIsEncrypted]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 0, 11, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
