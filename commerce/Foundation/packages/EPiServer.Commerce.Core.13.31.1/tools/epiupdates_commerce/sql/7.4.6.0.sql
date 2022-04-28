--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 4, @patch int = 6    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
GO

WITH CTE AS (
  SELECT [ObjectId], [ObjectTypeId], [MetaFieldId], [LanguageName],
     row_number() OVER(PARTITION BY [ObjectId], [ObjectTypeId], [MetaFieldId], [LanguageName] ORDER BY [pkId] DESC) AS [rn]
  FROM CatalogContentProperty
)
DELETE CTE WHERE [rn] > 1

CREATE UNIQUE CLUSTERED INDEX [IDX_CatalogContentProperty_ContentID] ON [dbo].[CatalogContentProperty]
(
	[ObjectId] ASC,
	[ObjectTypeId] ASC,
	[LanguageName] ASC,
	[MetaFieldId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = ON, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[CatalogContentProperty_Save] 
GO

CREATE PROCEDURE [dbo].[CatalogContentProperty_Save]
	@ContentProperty dbo.udttCatalogContentProperty readonly,
	@ObjectId int,
	@ObjectTypeId int,
	@LanguageName NVARCHAR(20),
	@ContentExData dbo.udttCatalogContentEx readonly,
	@SyncVersion bit = 1
AS
BEGIN
	DECLARE @catalogId INT
	SET @catalogId =
		CASE
			WHEN @ObjectTypeId = 0 THEN
				(SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @ObjectId)
			WHEN @ObjectTypeId = 1 THEN
				(SELECT CatalogId FROM CatalogNode WHERE CatalogNodeId = @ObjectId)
		END
	IF @LanguageName NOT IN (SELECT LanguageCode FROM dbo.CatalogLanguage WHERE CatalogId = @catalogId)
	BEGIN
		SET @LanguageName = (SELECT DefaultLanguage FROM dbo.Catalog WHERE CatalogId = @catalogId)
	END

	IF ((SELECT COUNT(*) FROM @ContentProperty) = 0)
	BEGIN 
		DELETE [CatalogContentProperty] WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId

		IF (@SyncVersion = 1)
		BEGIN
			EXEC [ecfVersionProperty_SyncPublishedVersion] @ContentProperty, @ObjectId, @ObjectTypeId, @LanguageName
		END

		RETURN
	END
	--delete properties where is null in input table
	DELETE A
	FROM [dbo].[CatalogContentProperty] A
	INNER JOIN @ContentProperty I
	ON	A.ObjectId = I.ObjectId AND 
		A.ObjectTypeId = I.ObjectTypeId AND
		A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT AND
		A.MetaFieldId = I.MetaFieldId
	WHERE I.[IsNull] = 1
	
	--update encrypted field: support only LongString field
	DECLARE @propertyData dbo.udttCatalogContentProperty
	
	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO @propertyData (
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String],
			LongString,
			[Guid])
		SELECT
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, @LanguageName, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], 
			CASE WHEN IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(LongString, 1) ELSE LongString END AS LongString, 
			[Guid]
		FROM @ContentProperty
		WHERE [IsNull] = 0

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO @propertyData (
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
		SELECT
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, @LanguageName, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid]
		FROM @ContentProperty
		WHERE [IsNull] = 0

	END

	-- update/insert items which are not in input
	MERGE	[dbo].[CatalogContentProperty] as A
	USING	@propertyData as I
	ON		A.ObjectId = I.ObjectId AND 
			A.ObjectTypeId = I.ObjectTypeId AND 
			A.MetaFieldId = I.MetaFieldId AND
			A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT
	WHEN	MATCHED 
		-- update the CatalogContentProperty for existing row
		THEN UPDATE SET
			A.MetaClassId = I.MetaClassId,
			A.MetaFieldName = I.MetaFieldName,
			A.Boolean = I.Boolean, 
			A.Number = I.Number, 
			A.FloatNumber = I.FloatNumber, 
			A.[Money] = I.[Money], 
			A.[Decimal] = I.[Decimal],
			A.[Date] = I.[Date], 
			A.[Binary] = I.[Binary], 
			A.[String] = I.[String], 
			A.LongString = I.LongString, 
			A.[Guid] = I.[Guid]

	WHEN	NOT MATCHED BY TARGET 
		-- insert new record if the record does not exist in CatalogContentProperty table
		THEN 
			INSERT (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	--Update ecfVersionProperty
	IF (@SyncVersion = 1)
	BEGIN
		EXEC [ecfVersionProperty_SyncPublishedVersion] @ContentProperty, @ObjectId, @ObjectTypeId, @LanguageName
	END

	-- Update CatalogContentEx table
	EXEC CatalogContentEx_Save @ContentExData
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_SaveBatch]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[CatalogContentProperty_SaveBatch] 
GO

CREATE PROCEDURE [dbo].[CatalogContentProperty_SaveBatch]
	@ContentProperty dbo.udttCatalogContentProperty readonly,
	@ContentExData dbo.udttCatalogContentEx readonly,
	@SyncVersion bit = 1
AS
BEGIN
	--delete items which are not in input
	DELETE A
	FROM [dbo].[CatalogContentProperty] A
	INNER JOIN @ContentProperty I
	ON	A.ObjectId = I.ObjectId AND
		A.ObjectTypeId = I.ObjectTypeId AND
		A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT AND
		A.MetaFieldId = I.MetaFieldId
	WHERE I.[IsNull] = 1

	--update encrypted field: support only LongString field
	DECLARE @propertyData dbo.udttCatalogContentProperty

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
		BEGIN
			EXEC mdpsp_sys_OpenSymmetricKey

			INSERT INTO @propertyData (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String],
				LongString,
				[Guid])
			SELECT
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String],
				CASE WHEN IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(LongString, 1) ELSE LongString END AS LongString,
				[Guid]
			FROM @ContentProperty
			WHERE [IsNull] = 0

			EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
			INSERT INTO @propertyData (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			SELECT
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid]
			FROM @ContentProperty
			WHERE [IsNull] = 0
		END

	-- update/insert items which are not in input
	MERGE	[dbo].[CatalogContentProperty] as A
	USING	@propertyData as I
	ON		A.ObjectId = I.ObjectId AND
			A.ObjectTypeId = I.ObjectTypeId AND
			A.MetaFieldId = I.MetaFieldId AND
			A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT
	WHEN	MATCHED
		-- update the CatalogContentProperty for existing row
		THEN UPDATE SET
			A.MetaClassId = I.MetaClassId,
			A.MetaFieldName = I.MetaFieldName,
			A.Boolean = I.Boolean,
			A.Number = I.Number,
			A.FloatNumber = I.FloatNumber,
			A.[Money] = I.[Money],
			A.[Decimal] = I.[Decimal],
			A.[Date] = I.[Date],
			A.[Binary] = I.[Binary],
			A.[String] = I.[String],
			A.LongString = I.LongString,
			A.[Guid] = I.[Guid]

	WHEN NOT MATCHED BY TARGET
		-- insert new record if the record does not exist in CatalogContentProperty table
		THEN
			INSERT (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number,
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

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

EXEC mdpsp_sys_CreateMetaClassProcedureAll
GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 4, 6, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 