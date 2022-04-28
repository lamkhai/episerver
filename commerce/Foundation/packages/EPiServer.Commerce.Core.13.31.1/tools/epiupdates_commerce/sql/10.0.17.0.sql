--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 17    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[fn_UriSegmentExistsOnSiblingNodeOrEntry]...';


GO
ALTER FUNCTION [dbo].[fn_UriSegmentExistsOnSiblingNodeOrEntry]
(
    @entityId int,
    @type bit, -- 0 = Node, 1 = Entry
    @UriSegment nvarchar(255),
    @LanguageCode nvarchar(50)
)
RETURNS bit
AS
BEGIN
    DECLARE @RetVal bit
    DECLARE @parentId int
	DECLARE @CatalogId int
    
    -- get the parentId and CatalogId, based on entityId and the entity type
    IF @type = 0
	BEGIN
		SELECT @parentId = ParentNodeId, @CatalogId = CatalogId FROM CatalogNode WHERE CatalogNodeId = @entityId
		--no validation should be done until parent id is properly set
		IF(@parentId < 0)
			RETURN 0;
	END
    ELSE
	BEGIN
        SET @parentId = (SELECT TOP 1 CatalogNodeId FROM NodeEntryRelation WHERE CatalogEntryId = @entityId ORDER BY IsPrimary DESC)
		SET @CatalogId = (SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @entityId)
	END

    SET @RetVal = 0

               
    IF NOT EXISTS( SELECT S.CatalogNodeId
                    FROM CatalogItemSeo S WITH (NOLOCK) 
                    INNER JOIN CatalogNode N on N.CatalogNodeId = S.CatalogNodeId
                    LEFT JOIN CatalogNodeRelation NR ON N.CatalogNodeId = NR.ChildNodeId 
                    WHERE LanguageCode = @LanguageCode COLLATE DATABASE_DEFAULT 
                        AND S.CatalogNodeId <> @entityId
                        AND ((@parentId = 0 AND N.CatalogId = @CatalogId AND N.ParentNodeId = 0) OR (@parentId <> 0 AND (N.ParentNodeId = @parentId OR NR.ParentNodeId = @parentId)))
                        AND UriSegment = @UriSegment COLLATE DATABASE_DEFAULT 
                        AND N.IsActive = 1) 
    BEGIN
    	-- check against sibling entry if only UriSegment does not exist on sibling node	
		IF EXISTS(
					SELECT S.CatalogEntryId
					FROM CatalogItemSeo S WITH (NOLOCK)
					INNER JOIN CatalogEntry N ON N.CatalogEntryId = S.CatalogEntryId
					LEFT JOIN NodeEntryRelation R ON R.CatalogEntryId = N.CatalogEntryId
					WHERE 
						S.LanguageCode = @LanguageCode COLLATE DATABASE_DEFAULT 
						AND S.CatalogEntryId <> @entityId 
						AND R.CatalogNodeId = @parentId
						AND R.CatalogId = @CatalogId
						AND UriSegment = @UriSegment COLLATE DATABASE_DEFAULT 
						AND N.IsActive = 1
						)
		BEGIN
			SET @RetVal = 1
		END
	END
	ELSE
	BEGIN
		SET @RetVal = 1
	END

    RETURN @RetVal;
END
GO
PRINT N'Altering [dbo].[ecfVersion_SyncEntryData]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_SyncEntryData]
	@ContentDraft dbo.udttVersion READONLY,
	@SelectOutput BIT = 0
AS
BEGIN
	DECLARE @WorkIds table (WorkId int, ObjectId int, LanguageName nvarchar(20), MasterLanguageName nvarchar(20))
	
	-- Insert/Update draft table
	MERGE INTO dbo.ecfVersion AS target
	USING (SELECT d.ObjectId, d.ObjectTypeId, c.CatalogId, d.LanguageName, d.[MasterLanguageName], 1, d.[Status],
				  c.StartDate, c.Name, c.Code, d.CreatedBy, d.Created, d.ModifiedBy, d.Modified, 
				  c.EndDate, s.Uri, s.Title, s.[Description], s.Keywords, s.UriSegment
			FROM @ContentDraft d
			INNER JOIN dbo.CatalogEntry c on d.ObjectId = c.CatalogEntryId
			INNER JOIN dbo.CatalogItemSeo s on d.ObjectId = s.CatalogEntryId AND d.LanguageName = s.LanguageCode COLLATE DATABASE_DEFAULT)
	AS SOURCE(ObjectId, ObjectTypeId, CatalogId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
			  StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified,
			  StopPublish, SeoUri, SeoTitle, SeoDescription, SeoKeywords, SeoUriSegment)
	ON (target.ObjectId = SOURCE.ObjectId AND target.ObjectTypeId = SOURCE.ObjectTypeId AND target.[Status] = SOURCE.[Status] AND target.LanguageName = SOURCE.LanguageName COLLATE DATABASE_DEFAULT)
	WHEN MATCHED THEN 
		UPDATE SET 
			target.CatalogId = SOURCE.CatalogId,
			target.IsCommonDraft = SOURCE.IsCommonDraft, 
			target.[Status] = SOURCE.[Status],
			target.StartPublish = SOURCE.StartPublish, 
			target.Name = SOURCE.Name, 
			target.Code = SOURCE.Code, 
			target.Modified = SOURCE.Modified, 
			target.ModifiedBy = SOURCE.ModifiedBy, 
			target.StopPublish = SOURCE.StopPublish,
			target.SeoUri = SOURCE.SeoUri, 
			target.SeoTitle = SOURCE.SeoTitle, 
			target.SeoDescription = SOURCE.SeoDescription, 
			target.SeoKeywords = SOURCE.SeoKeywords, 
			target.SeoUriSegment = SOURCE.SeoUriSegment
	WHEN NOT MATCHED THEN
		INSERT (ObjectId, ObjectTypeId, CatalogId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
				StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified,
				StopPublish, SeoUri, SeoTitle, SeoDescription, SeoKeywords, SeoUriSegment)
		VALUES (SOURCE.ObjectId, SOURCE.ObjectTypeId, SOURCE.CatalogId, SOURCE.LanguageName, SOURCE.MasterLanguageName, SOURCE.IsCommonDraft, SOURCE.[Status], 
				SOURCE.StartPublish, SOURCE.Name, SOURCE.Code, SOURCE.CreatedBy, SOURCE.Created, SOURCE.ModifiedBy, SOURCE.Modified,
				SOURCE.StopPublish, SOURCE.SeoUri, SOURCE.SeoTitle, SOURCE.SeoDescription, SOURCE.SeoKeywords, SOURCE.SeoUriSegment)
	OUTPUT inserted.WorkId, inserted.ObjectId, inserted.LanguageName, inserted.MasterLanguageName INTO @WorkIds;
	
	-- Adjust any previous and already existing versions and making sure they are not flagged as common draft.
	-- For any updated rows having status Published (4) existing rows with the same status will be changed to
	-- Previously Published (5).
	UPDATE existing	SET 
		   existing.IsCommonDraft = 0,	
	       existing.Status = CASE WHEN updated.Status = 4 AND existing.Status = 4 THEN 5 ELSE existing.Status END
	FROM ecfVersion AS existing INNER JOIN @ContentDraft AS updated ON 
		existing.ObjectId = updated.ObjectId 
		AND existing.ObjectTypeId = updated.ObjectTypeId 
		AND existing.LanguageName = updated.LanguageName COLLATE DATABASE_DEFAULT
	WHERE existing.WorkId NOT IN (SELECT WorkId FROM @WorkIds);

	-- Insert/Update Draft Asset
	DECLARE @draftAsset AS dbo.[udttCatalogContentAsset]
	INSERT INTO @draftAsset 
		SELECT w.WorkId, a.AssetType, a.AssetKey, a.GroupName, a.SortOrder 
		FROM @WorkIds w
		INNER JOIN CatalogItemAsset a ON w.ObjectId = a.CatalogEntryId
	
	DECLARE @workIdList dbo.[udttObjectWorkId]
	INSERT INTO @workIdList 
		SELECT NULL, NULL, w.WorkId, NULL 
		FROM @WorkIds w
	
	EXEC [ecfVersionAsset_Save] @workIdList, @draftAsset

	-- Insert/Update Draft Variation
	DECLARE @draftVariant dbo.[udttVariantDraft]
	INSERT INTO @draftVariant
		SELECT ids.WorkId, v.TaxCategoryId, v.TrackInventory, v.[Weight], v.MinQuantity, v.MaxQuantity, v.[Length], v.Height, v.Width, v.PackageId
		FROM @WorkIds ids
		INNER JOIN Variation v on ids.ObjectId = v.CatalogEntryId
		
	EXEC [ecfVersionVariation_Save] @draftVariant

	DECLARE @versionProperties dbo.udttCatalogContentProperty
	INSERT INTO @versionProperties (
			WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName,Boolean, Number,
			FloatNumber, [Money], [Decimal], [Date], [Binary], String, LongString, [Guid])
		SELECT
			w.WorkId, c.ObjectId, c.ObjectTypeId, c.MetaFieldId, c.MetaClassId, c.MetaFieldName, c.LanguageName, c.Boolean, c.Number,
			c.FloatNumber, c.[Money], c.[Decimal], c.[Date], c.[Binary], c.String, c.LongString, c.[Guid]
		FROM @workIds w
		INNER JOIN CatalogContentProperty c
		ON
			w.ObjectId = c.ObjectId AND
			w.LanguageName = c.LanguageName
		WHERE
			c.ObjectTypeId = 0

	EXEC [ecfVersionProperty_SyncBatchPublishedVersion] @versionProperties

	IF @SelectOutput = 1
		SELECT * FROM @WorkIds
END
GO
PRINT N'Altering [dbo].[ecfVersion_UpdateSeoByObjectIds]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_UpdateSeoByObjectIds]
	@ObjectIds udttObjectWorkId readonly
AS
BEGIN
	DECLARE @WorkIds TABLE (WorkId INT)
	INSERT INTO @WorkIds (WorkId)
		SELECT ver.WorkId
		FROM ecfVersion ver
		INNER JOIN @ObjectIds c ON ver.ObjectId = c.ObjectId AND ver.ObjectTypeId = c.ObjectTypeId
		WHERE (ver.Status = 4)
	UNION
		SELECT ver.WorkId
		FROM ecfVersion ver
		INNER JOIN @ObjectIds c ON ver.ObjectId = c.ObjectId AND ver.ObjectTypeId = c.ObjectTypeId
		WHERE (ver.IsCommonDraft = 1 AND 
		NOT EXISTS(SELECT 1 FROM ecfVersion ev WHERE ev.ObjectId = c.ObjectId AND ev.ObjectTypeId = c.ObjectTypeId AND ev.Status = 4 ))
	
	--update entry versions
	UPDATE ver 
	SET ver.SeoUri = s.Uri,
	    ver.SeoUriSegment = s.UriSegment
	FROM ecfVersion ver
	INNER JOIN @WorkIds ids ON ver.WorkId = ids.WorkId
	INNER JOIN CatalogItemSeo s ON (s.CatalogEntryId = ver.ObjectId AND ver.ObjectTypeId = 0)
	WHERE s.LanguageCode = ver.LanguageName COLLATE DATABASE_DEFAULT
	
	--update node versions
	UPDATE ver 
	SET ver.SeoUri = s.Uri,
	    ver.SeoUriSegment = s.UriSegment
	FROM ecfVersion ver
	INNER JOIN @WorkIds ids on ver.WorkId = ids.WorkId
	INNER JOIN CatalogItemSeo s ON (s.CatalogNodeId = ver.ObjectId AND ver.ObjectTypeId = 1)
	WHERE s.LanguageCode = ver.LanguageName COLLATE DATABASE_DEFAULT
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
	@Description 		NTEXT,
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

PRINT N'Altering [dbo].[ecf_CatalogNodeSearch]...';
GO

ALTER PROCEDURE [dbo].[ecf_CatalogNodeSearch]
(
	@SearchSetId			uniqueidentifier,
	@Catalogs 				nvarchar(max),
	@CatalogNodes 			nvarchar(max),
	@SQLClause 				nvarchar(max),
	@MetaSQLClause 			nvarchar(max),
	@OrderBy 				nvarchar(max),
	@StartingRec 			int,
	@NumRecords   			int,
	@RecordCount			int OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON
	
	DECLARE @FilterQuery_tmp nvarchar(max)
	DECLARE @SelectMetaQuery_tmp nvarchar(max)
	DECLARE @FromQuery_tmp nvarchar(max)
	DECLARE @FullQuery nvarchar(max)

	set @SelectMetaQuery_tmp = 'select 100 as ''Rank'', META.ObjectId as ''Key'' from CatalogContentProperty META WHERE META.ObjectTypeId = 1 '
	
	-- Add meta Where clause
	if(LEN(@MetaSQLClause)>0)
		set @SelectMetaQuery_tmp = @SelectMetaQuery_tmp + ' AND ' + @MetaSQLClause + ' '

	-- Create from command
	SET @FromQuery_tmp = N'FROM CatalogNode' + N' INNER JOIN (select distinct U.[Key], U.Rank from (' + @SelectMetaQuery_tmp + N') U) META ON CatalogNode.CatalogNodeId = META.[Key] '

	set @FromQuery_tmp = @FromQuery_tmp + N' LEFT OUTER JOIN CatalogNodeRelation NR ON CatalogNode.CatalogNodeId = NR.ChildNodeId'
	set @FromQuery_tmp = @FromQuery_tmp + N' LEFT OUTER JOIN [Catalog] CR ON NR.CatalogId = NR.CatalogId'
	set @FromQuery_tmp = @FromQuery_tmp + N' LEFT OUTER JOIN [Catalog] C ON C.CatalogId = CatalogNode.CatalogId'
	set @FromQuery_tmp = @FromQuery_tmp + N' LEFT OUTER JOIN [CatalogNode] CN ON CatalogNode.ParentNodeId = CN.CatalogNodeId'
	set @FromQuery_tmp = @FromQuery_tmp + N' LEFT OUTER JOIN [CatalogNode] CNR ON NR.ParentNodeId = CNR.CatalogNodeId'

	if(Len(@OrderBy) = 0)
	begin
		set @OrderBy = 'CatalogNode.CatalogNodeId'
	end

	/* CATALOG AND NODE FILTERING */
	set @FilterQuery_tmp =  N' WHERE ((1=1'
	if(Len(@Catalogs) != 0)
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND (C.[Name] in (select Item from ecf_splitlist(''' + @Catalogs + ''')))'

	if(Len(@CatalogNodes) != 0)
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND (CatalogNode.[Code] in (select Item from ecf_splitlist(''' + REPLACE(@CatalogNodes,N'''',N'''''') + '''))))'
	else
		set @FilterQuery_tmp = @FilterQuery_tmp + N')'

	set @FilterQuery_tmp = @FilterQuery_tmp + N' OR (1=1'
	if(Len(@Catalogs) != 0)
		set @FilterQuery_tmp = '' + @FilterQuery_tmp + N' AND (CR.[Name] in (select Item from ecf_splitlist(''' + @Catalogs + ''')))'

	if(Len(@CatalogNodes) != 0)
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND (CNR.[Code] in (select Item from ecf_splitlist(''' + REPLACE(@CatalogNodes,N'''',N'''''') + '''))))'
	else
		set @FilterQuery_tmp = @FilterQuery_tmp + N')'

	set @FilterQuery_tmp = @FilterQuery_tmp + N')'
	
	-- add sql clause statement here, if specified
	if(Len(@SQLClause) != 0)
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND (' + @SqlClause + ')'

	set @FullQuery = N'SELECT count(CatalogNode.CatalogNodeId) OVER() TotalRecords, CatalogNode.CatalogNodeId, Rank, ROW_NUMBER() OVER(ORDER BY ' + @OrderBy + N') RowNumber ' + @FromQuery_tmp + @FilterQuery_tmp

	-- use temp table variable
	set @FullQuery = N'with OrderedResults as (' + @FullQuery +') INSERT INTO @Page_temp (TotalRecords, CatalogNodeId) SELECT top(' + cast(@NumRecords as nvarchar(50)) + ') TotalRecords, CatalogNodeId FROM OrderedResults WHERE RowNumber > ' + cast(@StartingRec as nvarchar(50)) + ';'
	set @FullQuery = 'declare @Page_temp table (TotalRecords int, CatalogNodeId int);' + @FullQuery + ';select @RecordCount = TotalRecords from @Page_temp;INSERT INTO CatalogNodeSearchResults (SearchSetId, CatalogNodeId) SELECT ''' + cast(@SearchSetId as nvarchar(100)) + N''', CatalogNodeId from @Page_temp;'
	--print @FullQuery
	exec sp_executesql @FullQuery, N'@RecordCount int output', @RecordCount = @RecordCount OUTPUT

	SET NOCOUNT OFF
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
	@RecordCount                int OUTPUT,
	@ReturnTotalCount			bit = 1
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
	ELSE IF (@ReturnTotalCount = 1)
	BEGIN
		set @FullQuery =  @CountQuery+ @SelectQuery;
	END
	ELSE
	BEGIN
		set @FullQuery =  @SelectQuery;
	END

	--print @FullQuery
	exec sp_executesql @FullQuery, N'@RecordCount int output', @RecordCount = @RecordCount OUTPUT

	SET NOCOUNT OFF
END
GO

PRINT N'Altering [dbo].[ecf_Search_Payment]...';
GO

ALTER PROCEDURE [dbo].[ecf_Search_Payment]
    @results udttOrderGroupId readonly
AS
BEGIN

DECLARE @search_condition nvarchar(max)

-- Return Order Form Payment Collection

CREATE TABLE #OrderSearchResults (PaymentId int)
insert into #OrderSearchResults (PaymentId) select PaymentId from OrderFormPayment P INNER JOIN @results R ON R.OrderGroupId = P.OrderGroupId

SET @search_condition = N'''INNER JOIN OrderFormPayment O ON O.PaymentId = T.ObjectId INNER JOIN #OrderSearchResults R ON O.PaymentId = R.PaymentId '''

DECLARE @parentmetaclassid int
DECLARE @rowNum int
DECLARE @maxrows int
DECLARE @tablename nvarchar(120)
DECLARE @procedurefull nvarchar(max)

SET @parentmetaclassid = (SELECT MetaClassId from [MetaClass] WHERE Name = N'OrderFormPayment' and TableName = N'OrderFormPayment')

DECLARE @PaymentClasses TABLE
(
  query nvarchar(max),
  RowIndex int
)

INSERT INTO @PaymentClasses 
SELECT query = N'mdpsp_avto_' + TableName + N'_Search NULL, ' + N'''''''' + TableName + N''''''+  ' TableName, [O].*'' ,'  + @search_condition,
ROW_NUMBER() OVER (ORDER BY MetaClassId)
FROM [MetaClass] 
WHERE ParentClassId = @parentmetaclassid

SET @rowNum = 1
SET @maxrows = (SELECT COUNT(RowIndex) FROM @PaymentClasses)

WHILE @rowNum <= @maxrows
BEGIN 
	SELECT @procedurefull = query FROM @PaymentClasses WHERE RowIndex = @rowNum
	EXEC (@procedurefull)
	SET @rowNum = @rowNum + 1
END


DROP TABLE #OrderSearchResults

END
GO

PRINT N'Altering [dbo].[ecf_CatalogNodesList]...';
GO

ALTER PROCEDURE [dbo].[ecf_CatalogNodesList]
(
	@CatalogId int,
	@CatalogNodeId int,
	@EntryMetaSQLClause nvarchar(max),
	@OrderClause nvarchar(100),
	@StartingRec int,
	@NumRecords int,
	@ReturnInactive bit = 0,
	@ReturnTotalCount bit = 1
)
AS

BEGIN
	SET NOCOUNT ON

	declare @execStmtString nvarchar(max)
	declare @selectStmtString nvarchar(max)
	declare @EntryMetaSQLClauseLength bigint
	declare @SelectEntryMetaQuery_tmp nvarchar(max)
	set @EntryMetaSQLClauseLength = LEN(@EntryMetaSQLClause)

	set @execStmtString=N''

	-- assign ORDER BY statement if it is empty
	if(Len(RTrim(LTrim(@OrderClause))) = 0)
		set @OrderClause = N'ID ASC'

    -- Construct meta class joins for CatalogEntry table if a WHERE clause has been specified for Entry Meta data
    IF(@EntryMetaSQLClauseLength>0)
    BEGIN
    	-- If there is a meta SQL clause provided, join to CatalogContentProperty table
    	-- Similar to [ecf_CatalogEntrySearch], but simpler due to fewer variations, i.e.:
    	--   No @Classes parameter
    	--   No @Namespace
		set @SelectEntryMetaQuery_tmp = '
			INNER JOIN
			(
				select CP.ObjectId, CP.ObjectTypeId, md.Value 
				from CatalogContentProperty CP 
				inner join MetaKey MK ON CP.Number = MK.MetaKey
				join MetaMultiValueDictionary mmvd on mk.MetaKey = mmvd.MetaKey 
				join MetaDictionary md on mmvd.MetaDictionaryId = md.MetaDictionaryId and mk.MetaFieldId = md.MetaFieldId 

				Where MetaFieldName = ''_ExcludedCatalogEntryMarkets'' 
					AND md.Value IN (' + @EntryMetaSQLClause + ')
					AND CP.ObjectTypeId = 0 -- entry
			) ExcludedMarkets ON ExcludedMarkets.ObjectId = CE.CatalogEntryId
		'
    END
    ELSE
    BEGIN
        set @SelectEntryMetaQuery_tmp = N''
    END

	if (COALESCE(@CatalogNodeId, 0)=0)
	begin
		-- if @CatalogNodeId=0
		set @selectStmtString=N'select SEL.*, row_number() over(order by '+ @OrderClause +N') as RowNumber
				from
				(
					-- select Catalog Nodes
					SELECT CN.[CatalogNodeId] as ID, CN.[Name], ''Node'' as Type, CN.[Code], CN.[StartDate], CN.[EndDate], CN.[IsActive], CN.[SortOrder], OG.[Name] as Owner
						FROM [CatalogNode] CN 
							JOIN Catalog C ON (CN.CatalogId = C.CatalogId)
                            LEFT JOIN cls_Organization OG ON (OG.OrganizationId = C.Owner)
						WHERE CatalogNodeId IN
						(SELECT DISTINCT N.CatalogNodeId from [CatalogNode] N
							LEFT OUTER JOIN CatalogNodeRelation NR ON N.CatalogNodeId = NR.ChildNodeId
							WHERE
							(
								(N.CatalogId = @CatalogId AND N.ParentNodeId = @CatalogNodeId)
								OR
								(NR.CatalogId = @CatalogId AND NR.ParentNodeId = @CatalogNodeId)
							)
							AND
							((N.IsActive = 1) or @ReturnInactive = 1)
						)

					UNION

					-- select Catalog Entries
					SELECT CE.[CatalogEntryId] as ID, CE.[Name], CE.ClassTypeId as Type, CE.[Code], CE.[StartDate], CE.[EndDate], CE.[IsActive], 0, OG.[Name] as Owner
						FROM [CatalogEntry] CE
							JOIN Catalog C ON (CE.CatalogId = C.CatalogId)'
							+ @SelectEntryMetaQuery_tmp 
							+ N'
                            LEFT JOIN cls_Organization OG ON (OG.OrganizationId = C.Owner)
					WHERE
						CE.CatalogId = @CatalogId AND
						NOT EXISTS(SELECT 1 FROM NodeEntryRelation R WHERE R.CatalogId = @CatalogId and CE.CatalogEntryId = R.CatalogEntryId) AND
						((CE.IsActive = 1) or @ReturnInactive = 1)
				) SEL'
	end
	else
	begin
		-- if @CatalogNodeId!=0

		-- Get the original catalog id for the given catalog node
		SELECT @CatalogId = [CatalogId] FROM [CatalogNode] WHERE [CatalogNodeId] = @CatalogNodeId

		set @selectStmtString=N'select SEL.*, row_number() over(order by '+ @OrderClause +N') as RowNumber
			from
			(
				-- select Catalog Nodes
				SELECT CN.[CatalogNodeId] as ID, CN.[Name], ''Node'' as Type, CN.[Code], CN.[StartDate], CN.[EndDate], CN.[IsActive], CN.[SortOrder], OG.[Name] as Owner
					FROM [CatalogNode] CN 
						JOIN Catalog C ON (CN.CatalogId = C.CatalogId)
						--We actually dont need to join NodeEntryRelation to get the SortOrder because it is always 0
                        --JOIN CatalogEntry CE ON CE.CatalogId = C.CatalogId
						--LEFT JOIN NodeEntryRelation NER ON (NER.CatalogId = CN.CatalogId And NER.CatalogNodeId = CN.CatalogNodeId  AND CE.CatalogEntryId = NER.CatalogEntryId ) 
                        LEFT JOIN cls_Organization OG ON (OG.OrganizationId = C.Owner)
					WHERE CN.CatalogNodeId IN
				(SELECT DISTINCT N.CatalogNodeId from [CatalogNode] N
				LEFT OUTER JOIN CatalogNodeRelation NR ON N.CatalogNodeId = NR.ChildNodeId
				WHERE
					((N.CatalogId = @CatalogId AND N.ParentNodeId = @CatalogNodeId) OR (NR.CatalogId = @CatalogId AND NR.ParentNodeId = @CatalogNodeId)) AND
					((N.IsActive = 1) or @ReturnInactive = 1))

				UNION
				
				-- select Catalog Entries
				SELECT CE.[CatalogEntryId] as ID, CE.[Name], CE.ClassTypeId as Type, CE.[Code], CE.[StartDate], CE.[EndDate], CE.[IsActive], R.[SortOrder], OG.[Name] as Owner
					FROM [CatalogEntry] CE
						JOIN Catalog C ON (CE.CatalogId = C.CatalogId)
						JOIN NodeEntryRelation R ON R.CatalogEntryId = CE.CatalogEntryId'
							+ @SelectEntryMetaQuery_tmp 
							+ N' 
                        LEFT JOIN cls_Organization OG ON (OG.OrganizationId = C.Owner)
				WHERE
					R.CatalogNodeId = @CatalogNodeId AND
					R.CatalogId = @CatalogId AND
						((CE.IsActive = 1) or @ReturnInactive = 1)
			) SEL'
	end

	if(@ReturnTotalCount = 1) -- Only return count if we requested it
		set @execStmtString=N'with SelNodes(ID, Name, Type, Code, StartDate, EndDate, IsActive, SortOrder, Owner, RowNumber)
			as
			(' + @selectStmtString +
			N'),
			SelNodesCount(TotalCount)
			as
			(
				select count(ID) from SelNodes
			)
			select  TOP ' + cast(@NumRecords as nvarchar(50)) + ' ID, Name, Type, Code, StartDate, EndDate, IsActive, SortOrder, Owner, RowNumber, C.TotalCount as RecordCount
			from SelNodes, SelNodesCount C
			where RowNumber >= ' + cast(@StartingRec as nvarchar(50)) + 
			' order by '+ @OrderClause
	else
		set @execStmtString=N'with SelNodes(ID, Name, Type, Code, StartDate, EndDate, IsActive, SortOrder, Owner, RowNumber)
			as
			(' + @selectStmtString +
			N')
			select  TOP ' + cast(@NumRecords as nvarchar(50)) + ' ID, Name, Type, Code, StartDate, EndDate, IsActive, SortOrder, Owner, RowNumber
			from SelNodes
			where RowNumber >= ' + cast(@StartingRec as nvarchar(50)) +
			' order by '+ @OrderClause
	
	declare @ParamDefinition nvarchar(500)
	set @ParamDefinition = N'@CatalogId int,
						@CatalogNodeId int,
						@StartingRec int,
						@NumRecords int,
						@ReturnInactive bit';
	exec sp_executesql @execStmtString, @ParamDefinition,
			@CatalogId = @CatalogId,
			@CatalogNodeId = @CatalogNodeId,
			@StartingRec = @StartingRec,
			@NumRecords = @NumRecords,
			@ReturnInactive = @ReturnInactive

	SET NOCOUNT OFF
END
GO

PRINT N'Altering [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]...';
GO

ALTER PROCEDURE [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]
	@ContentDraftProperty dbo.udttCatalogContentProperty READONLY
AS
BEGIN	
	
	DECLARE @propertyData udttCatalogContentProperty

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		--update encrypted field: support only LongString field
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO @propertyData (
			WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number,
			FloatNumber, [Money], [Decimal], [Date], [Binary], String,
			LongString,
			[Guid], [IsNull])
		SELECT
			ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, cdp.LanguageName, cdp.Boolean, cdp.Number,
			cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
			CASE WHEN cdp.IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(cdp.LongString, 1) ELSE cdp.LongString END AS LongString, 
			cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd
		ON	ccd.ObjectId = cdp.ObjectId AND
			ccd.ObjectTypeId = cdp.ObjectTypeId AND
			ccd.LanguageName = cdp.LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 OR ccd.IsCommonDraft = 1 --Draft properties of published version/common draft will be sync

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO @propertyData (
			WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number,
			FloatNumber, [Money], [Decimal], [Date], [Binary], String, LongString, [Guid], [IsNull])
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, cdp.LanguageName, cdp.Boolean, cdp.Number,
			cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, cdp.LongString, cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd
		ON	ccd.ObjectId = cdp.ObjectId AND
			ccd.ObjectTypeId = cdp.ObjectTypeId AND
			ccd.LanguageName = cdp.LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 OR ccd.IsCommonDraft = 1 --Draft properties of published version/common draft will be sync
	END

	-- delete rows where values have been nulled out
	DELETE A 
	FROM [dbo].[ecfVersionProperty] A
	INNER JOIN @propertyData T
	ON	A.WorkId = T.WorkId AND 
		A.MetaFieldId = T.MetaFieldId AND
		T.[IsNull] = 1

	-- now null rows are handled, so remove them to not insert empty rows
	DELETE FROM @propertyData
	WHERE [IsNull] = 1

	-- update/insert items which are not in input
	MERGE	[dbo].[ecfVersionProperty] as A
	USING	@propertyData as I
	ON		A.WorkId = I.WorkId AND
			A.MetaFieldId = I.MetaFieldId 
	WHEN	MATCHED 
		-- update the ecfVersionProperty for existing row
		THEN UPDATE SET 		
			A.LanguageName = I.LanguageName,	
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
		-- insert new record if the record is does not exist in ecfVersionProperty table
		THEN 
			INSERT (
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.WorkId, I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	--Sync version properties with version
	UPDATE [dbo].[ecfVersion]
     SET [StartPublish] = I.[Date]
	FROM @PropertyData as I
	INNER JOIN [dbo].[ecfVersion] E 
		ON E.[WorkId] = I.[WorkId] 
	WHERE I.[MetaFieldName] = 'Epi_StartPublish'
	 
	  
	UPDATE [dbo].[ecfVersion]
     SET [StopPublish] = I.[Date]
	FROM @PropertyData as I
	INNER JOIN [dbo].[ecfVersion] E
		ON E.[WorkId] = I.[WorkId]
	WHERE I.[MetaFieldName] = 'Epi_StopPublish'

	UPDATE [dbo].[ecfVersion]
     SET [Status] = CASE when I.[Boolean] = 0 THEN 2
					ELSE 4 END
	FROM @PropertyData as I
	INNER JOIN [dbo].[ecfVersion] E
		ON E.[WorkId] = I.[WorkId]
	WHERE I.[MetaFieldName] = 'Epi_IsPublished'

END
GO

PRINT N'Altering [dbo].[ecf_reporting_SaleReport]...';
GO

ALTER PROCEDURE [dbo].[ecf_reporting_SaleReport] 
	@MarketId nvarchar(8),
	@CurrencyCode NVARCHAR(8),
	@interval VARCHAR(20),
	@startdate DATETIME, -- parameter expected in UTC
	@enddate DATETIME, -- parameter expected in UTC
	@offset_st INT,
	@offset_dt INT
AS

BEGIN

	with periodQuery as
	(
		SELECT DISTINCT	
			(CASE WHEN @interval = 'Day'
				THEN CONVERT(VARCHAR(10), D.DateFull, 101)
			WHEN @interval = 'Month'
			THEN (DATENAME(MM, D.DateFull) + ',' + CAST(YEAR(D.DateFull) AS VARCHAR(20))) 
			ElSE CAST(YEAR(D.DateFull) AS VARCHAR(20))  
			End) AS Period 
		FROM ReportingDates D
		WHERE
			-- convert back from UTC using offset to generate a list of WEBSERVER datetimes
			D.DateFull BETWEEN 
				cast(floor(cast(dbo.fn_GetDaylightSavingsTime(@startdate, @offset_st, @offset_dt) as float)) as datetime) AND
				cast(floor(cast(dbo.fn_GetDaylightSavingsTime(@enddate, @offset_st, @offset_dt) as float)) as datetime)
	)
	, lineItemsQuery as
	(
		select sum(Quantity) ItemsOrdered, L.OrderGroupId
		from LineItem L 
				inner join OrderForm as OF1 on L.OrderFormId = OF1.OrderFormId
				where OF1.Name <> 'Return'
				group by L.OrderGroupId
	)
	, orderFormQuery as
	(
		select sum(DiscountAmount) Discounts, OrderGroupId
		from OrderForm 
				group by OrderGroupId
	)
	, paymentQuery as
	(
		select sum(Amount) TotalPayment, OFP.OrderGroupId
		from OrderFormPayment as OFP
				where OFP.TransactionType = 'Capture' OR OFP.TransactionType = 'Sale'
				group by OFP.OrderGroupId
	)
	, orderQuery as 
	(
		SELECT
			(CASE WHEN @interval = 'Day'
				THEN CONVERT(VARCHAR(10), dbo.fn_GetDaylightSavingsTime(PO.Created, @offset_st, @offset_dt), 101)
				WHEN @interval = 'Month'
				THEN (DATENAME(MM, dbo.fn_GetDaylightSavingsTime(PO.Created, @offset_st, @offset_dt)) + ','
					+ CAST(YEAR(dbo.fn_GetDaylightSavingsTime(PO.Created, @offset_st, @offset_dt)) AS VARCHAR(20))) 
				ElSE CAST(YEAR(dbo.fn_GetDaylightSavingsTime(PO.Created, @offset_st, @offset_dt)) AS VARCHAR(20))  
				End) AS Period, 
			COALESCE(COUNT(OG.OrderGroupId), 0) AS NumberofOrders
			, SUM(L1.ItemsOrdered) AS ItemsOrdered
			, SUM(OG.SubTotal) AS SubTotal
			, SUM(OG.TaxTotal) AS Tax
			, SUM(OG.ShippingTotal) AS Shipping 
			, SUM(OF1.Discounts) AS Discounts
			, SUM(OG.Total) AS Total
			, SUM(P.TotalPayment) AS Invoiced
		FROM OrderGroup AS OG 
			INNER JOIN OrderGroup_PurchaseOrder AS PO 
				ON PO.ObjectId = OG.OrderGroupId
			INNER JOIN orderFormQuery OF1 
				on OF1.OrderGroupId = OG.OrderGroupId
			LEFT JOIN paymentQuery AS P 
				ON P.OrderGroupId = OG.OrderGroupId 
			LEFT JOIN lineItemsQuery L1 
				on L1.OrderGroupId = OG.OrderGroupId
        WHERE 
			-- PO.Created is stored in UTC
            PO.Created
			BETWEEN
				-- pad range by one day to include outlying records on narrow date ranges
				DATEADD(DD, -1, @startdate) AND 
				DATEADD(DD, 1, @enddate)
			AND OG.Name <> 'Exchange' AND
				OG.[Status] <> 'Cancelled' AND
				OG.BillingCurrency = @CurrencyCode AND
				(LEN(@MarketId) = 0 OR OG.MarketId = @MarketId)
		GROUP BY
			(CASE WHEN @interval = 'Day'
				THEN CONVERT(VARCHAR(10), dbo.fn_GetDaylightSavingsTime(PO.Created, @offset_st, @offset_dt), 101)
				WHEN @interval = 'Month'
				THEN (DATENAME(MM, dbo.fn_GetDaylightSavingsTime(PO.Created, @offset_st, @offset_dt)) + ','
					+ CAST(YEAR(dbo.fn_GetDaylightSavingsTime(PO.Created, @offset_st, @offset_dt)) AS VARCHAR(20))) 
				ElSE CAST(YEAR(dbo.fn_GetDaylightSavingsTime(PO.Created, @offset_st, @offset_dt)) AS VARCHAR(20))  
							End)
	)
	
	SELECT	
		P.Period
		, O.NumberofOrders as NumberofOrders
		, O.ItemsOrdered
		, O.SubTotal
		, O.Tax
		, O.Shipping
		, O.Discounts
		, O.Total
		, O.Invoiced
	FROM periodQuery P LEFT JOIN orderQuery O 
		on P.Period = O.Period
	ORDER BY CONVERT(datetime, P.Period, 101) 

END
GO

PRINT N'Altering [dbo].[ecf_reporting_ProductBestSellers]...';
GO

ALTER PROCEDURE [dbo].[ecf_reporting_ProductBestSellers] 
	@MarketId nvarchar(8),
	@CurrencyCode NVARCHAR(8),
	@interval VARCHAR(20),
	@startdate DATETIME, -- parameter expected in UTC
	@enddate DATETIME, -- parameter expected in UTC
	@offset_st INT,
	@offset_dt INT
AS

BEGIN

	SELECT	z.Period, 
			z.ProductName, 
			z.Price, 
			z.Ordered,
			z.Code
	FROM
	(
		SELECT	x.Period as Period,  
				ISNULL(y.ProductName, 'NONE') AS ProductName,
				ISNULL(y.Price,0) AS Price,
				ISNULL(y.ItemsOrdered, 0) AS Ordered,
				RANK() OVER (PARTITION BY x.Period
						ORDER BY y.Price DESC) AS PriceRank,
				y.Code
		FROM 
		(
			SELECT	DISTINCT (CASE WHEN @interval = 'Day'
								THEN CONVERT(VARCHAR(10), D.DateFull, 101)
								WHEN @interval = 'Month'
								THEN (DATENAME(MM, D.DateFull) + ', ' + CAST(YEAR(D.DateFull) AS VARCHAR(20))) 
								ElSE CAST(YEAR(D.DateFull) AS VARCHAR(20))  
								End) AS Period 
			FROM ReportingDates D LEFT OUTER JOIN OrderFormEx FEX ON D.DateFull = FEX.Created
		WHERE 
			-- convert back from UTC using offset to generate a list of WEBSERVER datetimes
			D.DateFull BETWEEN 
				cast(floor(cast(dbo.fn_GetDaylightSavingsTime(@startdate, @offset_st, @offset_dt) as float)) as datetime) AND
				cast(floor(cast(dbo.fn_GetDaylightSavingsTime(@enddate, @offset_st, @offset_dt) as float)) as datetime)
		) AS x

		LEFT JOIN

		(
			SELECT  DISTINCT (CASE WHEN @interval = 'Day'
								THEN CONVERT(VARCHAR(20), dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt), 101)
								WHEN @interval = 'Month'
								THEN (DATENAME(MM, dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) + ', ' + CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20)) )
								ElSE CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20))   End) as Period, 
					
				 E.Name AS ProductName,
					L.ListPrice AS Price,
					SUM(L.Quantity) AS ItemsOrdered,
					RANK() OVER (PARTITION BY (CASE WHEN @interval = 'Day'
													THEN CONVERT(VARCHAR(20), dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt), 101)
													WHEN @interval = 'Month'
													THEN (DATENAME(MM, dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) + ', ' + CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20)) )
													ElSE CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20))   
												END) 
								ORDER BY SUM(L.Quantity) DESC) AS PeriodRank,
					E.Code
			FROM 
				LineItem AS L INNER JOIN OrderFormEx AS FEX ON L.OrderFormId = FEX.ObjectId 
				INNER JOIN OrderForm AS F ON L.OrderFormId = F.OrderFormId
				INNER JOIN CatalogEntry E ON L.CatalogEntryId = E.Code
				INNER JOIN OrderGroup AS OG ON F.OrderGroupId = OG.OrderGroupId AND isnull (OG.Status, '') = 'Completed'
			WHERE CONVERT(VARCHAR(20), dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt), 101) >=  @startdate AND CONVERT(VARCHAR(20), dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt), 101) < @enddate +1 
				AND (FEX.RMANumber = '' OR FEX.RMANumber IS NULL)
				AND OG.Name <> 'Exchange'
				AND OG.BillingCurrency = @CurrencyCode 
				AND (LEN(@MarketId) = 0 OR OG.MarketId = @MarketId)
			GROUP BY (Case WHEN @interval = 'Day'
						THEN CONVERT(VARCHAR(20), dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt), 101)
						WHEN @interval = 'Month'
						THEN (DATENAME(MM, dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) + ', ' + CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20))  )
						ElSE CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20))   
					END) ,E.Name, L.ListPrice, E.Code
				
		
					
		) AS y

ON x.Period = y.Period
WHERE y.PeriodRank IS NULL 
OR y.PeriodRank = 1



	)AS z

WHERE z.PriceRank = 1
ORDER BY CONVERT(datetime, z.Period, 101)
END
GO

PRINT N'Altering [dbo].[ecf_Inventory_QueryInventory]...';
GO

ALTER PROCEDURE [dbo].[ecf_Inventory_QueryInventory]
    @entryKeys [dbo].[udttInventoryCode] READONLY,
	@warehouseKeys [dbo].[udttInventoryCode] READONLY,
	@partialKeys [dbo].[udttInventory] READONLY
AS
BEGIN
    select
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from [dbo].[InventoryService] mi
    where exists (
        select 1 
        from @entryKeys keys1 
        where LOWER(mi.[CatalogEntryCode]) = LOWER(keys1.[Code]))
    union
	select
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from [dbo].[InventoryService] mi
    where exists (
        select 1 
        from @warehouseKeys keys2 
        where LOWER(mi.[WarehouseCode]) = LOWER(keys2.[Code]))
    union
	select
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from [dbo].[InventoryService] mi
    where exists (
        select 1 
        from @partialKeys keys3 
        where LOWER(mi.[CatalogEntryCode]) = LOWER(keys3.[CatalogEntryCode])
          and LOWER(mi.[WarehouseCode]) = LOWER(keys3.[WarehouseCode]))
    order by [CatalogEntryCode], [WarehouseCode]


END
GO

PRINT N'Altering [dbo].[ecf_Inventory_QueryInventoryPaged]...';
GO

ALTER PROCEDURE [dbo].[ecf_Inventory_QueryInventoryPaged]
    @offset int,
    @count int,
    @partialKeys [dbo].[udttInventory] READONLY
AS
BEGIN
    declare @results table (
        [CatalogEntryCode] nvarchar(100),
        [WarehouseCode] nvarchar(50),
        [IsTracked] bit,
        [PurchaseAvailableQuantity] decimal(38, 9),
        [PreorderAvailableQuantity] decimal(38, 9),
        [BackorderAvailableQuantity] decimal(38, 9),
        [PurchaseRequestedQuantity] decimal(38, 9),
        [PreorderRequestedQuantity] decimal(38, 9),
        [BackorderRequestedQuantity] decimal(38, 9),
        [PurchaseAvailableUtc] datetime2,
        [PreorderAvailableUtc] datetime2,
        [BackorderAvailableUtc] datetime2,
        [AdditionalQuantity] decimal(38, 9),
        [ReorderMinQuantity] decimal(38, 9),
        [RowNumber] int,
        [TotalCount] int
    )

    insert into @results (
        [CatalogEntryCode],
        [WarehouseCode],
        [IsTracked],
        [PurchaseAvailableQuantity],
        [PreorderAvailableQuantity],
        [BackorderAvailableQuantity],
        [PurchaseRequestedQuantity],
        [PreorderRequestedQuantity],
        [BackorderRequestedQuantity],
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity],
        [RowNumber],
        [TotalCount]
    )
    select
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity],
        [RowNumber],
        [RowNumber] + [ReverseRowNumber] - 1 as [TotalCount]
    from (
        select 
            ROW_NUMBER() over (order by [CatalogEntryCode], [WarehouseCode]) as [RowNumber],
            ROW_NUMBER() over (order by [CatalogEntryCode] desc, [WarehouseCode] desc) as [ReverseRowNumber],
            [CatalogEntryCode], 
            [WarehouseCode], 
            [IsTracked], 
            [PurchaseAvailableQuantity], 
            [PreorderAvailableQuantity], 
            [BackorderAvailableQuantity], 
            [PurchaseRequestedQuantity], 
            [PreorderRequestedQuantity], 
            [BackorderRequestedQuantity], 
            [PurchaseAvailableUtc],
            [PreorderAvailableUtc],
            [BackorderAvailableUtc],
            [AdditionalQuantity],
            [ReorderMinQuantity]
        from [dbo].[InventoryService] mi
        where exists (
            select 1 
            from @partialKeys keys 
            where LOWER(mi.[CatalogEntryCode]) = LOWER(isnull(keys.[CatalogEntryCode], mi.[CatalogEntryCode]))
              and LOWER(mi.[WarehouseCode]) = LOWER(isnull(keys.[WarehouseCode], mi.[WarehouseCode])))
    ) paged
    where @offset < [RowNumber] and [RowNumber] <= (@offset + @count)

    if not exists (select 1 from @results)
    begin
        select COUNT(*) as TotalCount
        from [dbo].[InventoryService] mi
        where exists (
            select 1 
            from @partialKeys keys 
            where LOWER(mi.[CatalogEntryCode]) = LOWER(isnull(keys.[CatalogEntryCode], mi.[CatalogEntryCode]))
              and LOWER(mi.[WarehouseCode]) = LOWER(isnull(keys.[WarehouseCode], mi.[WarehouseCode])))
    end
    else
    begin
        select top 1 [TotalCount] from @results
    end
       
    select 
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from @results
    order by [RowNumber]
END
GO

PRINT N'Altering [dbo].[CatalogContentProperty_Load]...';
GO

ALTER PROCEDURE [dbo].[CatalogContentProperty_Load]
	@ObjectId int,
	@ObjectTypeId int,
	@MetaClassId int,
	@Language nvarchar(50)
AS
BEGIN
	DECLARE @catalogId INT
	DECLARE @FallbackLanguage nvarchar(50)

	SET @catalogId = CASE WHEN @ObjectTypeId = 0 THEN
							(SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @ObjectId)
							WHEN @ObjectTypeId = 1 THEN							
							(SELECT CatalogId FROM CatalogNode WHERE CatalogNodeId = @ObjectId)
						END
	SELECT @FallbackLanguage = LOWER(DefaultLanguage) FROM dbo.[Catalog] WHERE CatalogId = @catalogId

	-- load from fallback language only if @Language is not existing language of catalog.
	-- in other work, fallback language is used for invalid @Language value only.
	IF LOWER(@Language) NOT IN (SELECT LOWER(LanguageCode) FROM dbo.CatalogLanguage WHERE CatalogId = @catalogId)
		SET @Language = @FallbackLanguage
    
	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 --Fields will be encrypted only when DB does not support Azure
		BEGIN
		EXEC mdpsp_sys_OpenSymmetricKey

		SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
							P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], 
							CASE WHEN (F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1 )
							THEN dbo.mdpfn_sys_EncryptDecryptString(P.LongString, 0) 
							ELSE P.LongString END AS LongString, 
							P.[Guid]  
		FROM dbo.CatalogContentProperty P
		INNER JOIN MetaField F ON P.MetaFieldId = F.MetaFieldId
		WHERE ObjectId = @ObjectId AND
				ObjectTypeId = @ObjectTypeId AND
				MetaClassId = @MetaClassId AND
				((F.MultiLanguageValue = 1 AND LOWER(LanguageName) = LOWER(@Language) COLLATE DATABASE_DEFAULT) OR ((F.MultiLanguageValue = 0 AND LOWER(LanguageName) = LOWER(@FallbackLanguage) COLLATE DATABASE_DEFAULT)))

		EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
		SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
							P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], 
							P.LongString, 
							P.[Guid]
		FROM dbo.CatalogContentProperty P
		WHERE ObjectId = @ObjectId AND
				ObjectTypeId = @ObjectTypeId AND
				MetaClassId = @MetaClassId AND
				((P.CultureSpecific = 1 AND LOWER(LanguageName) = LOWER(@Language) COLLATE DATABASE_DEFAULT) OR ((P.CultureSpecific = 0 AND LOWER(LanguageName) = LOWER(@FallbackLanguage) COLLATE DATABASE_DEFAULT)))
		END

	-- Select CatalogContentEx data
	EXEC CatalogContentEx_Load @ObjectId, @ObjectTypeId
END
GO

PRINT N'Refreshing [dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 17, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
