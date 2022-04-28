--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 0, @patch int = 7   
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO
 
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntrySearch_Init]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_CatalogEntrySearch_Init]
GO

CREATE procedure [dbo].[ecf_CatalogEntrySearch_Init]
    @ApplicationId uniqueidentifier,
    @CatalogId int,
    @SearchSetId uniqueidentifier,
    @IncludeInactive bit,
    @EarliestModifiedDate datetime = null,
    @LatestModifiedDate datetime = null,
    @DatabaseClockOffsetMS int = null
as
begin
	declare @purgedate datetime
	begin try
		set @purgedate = datediff(day, 3, GETUTCDATE())
		delete from [CatalogEntrySearchResults_SingleSort] where Created < @purgedate
	end try
	begin catch
	end catch

    declare @ModifiedCondition nvarchar(max)
    declare @EarliestModifiedFilter nvarchar(4000) = ''
	declare @LatestModifiedFilter nvarchar(4000) = ''
	
	declare @query nvarchar(max)
	declare @AppLogQuery nvarchar(4000)

	set @ModifiedCondition = ''
    
    -- @ModifiedFilter: if there is a filter, build the where clause for it here.
    if (@EarliestModifiedDate is not null)
	 set @EarliestModifiedFilter = ' and Modified >= cast(''' + CONVERT(nvarchar(100), @EarliestModifiedDate, 127) + ''' as datetime)'

    if (@LatestModifiedDate is not null) 
	 set @LatestModifiedFilter = ' and Modified <= cast('''  + CONVERT(nvarchar(100), @LatestModifiedDate, 127) + ''' as datetime)'
	
	-- applying the catalogContentEx.
	set @ModifiedCondition = @ModifiedCondition + ' select ObjectId from CatalogContentEx where ObjectTypeId = 0' + @EarliestModifiedFilter + @LatestModifiedFilter
	
    -- find all the catalog entries that have modified relations in NodeEntryRelation, or deleted relations in ApplicationLog
    if (@EarliestModifiedDate is not null and @LatestModifiedDate is not null)
    begin
        -- adjust modified date filters to account for clock difference between database server and application server clocks    
        if (isnull(@DatabaseClockOffsetMS, 0) > 0)
        begin
            set @EarliestModifiedDate = DATEADD(MS, -@DatabaseClockOffsetMS, @EarliestModifiedDate)
            set @EarliestModifiedFilter = ' Modified >= cast(''' + CONVERT(nvarchar(100), @EarliestModifiedDate, 127) + ''' as datetime)'
			set @LatestModifiedFilter = ' and Modified <= cast('''  + CONVERT(nvarchar(100), @LatestModifiedDate, 127) + ''' as datetime)'
		end

		-- applying the NodeEntryRelation.
		set @ModifiedCondition = @ModifiedCondition + ' union all select CatalogEntryId from NodeEntryRelation where ' + @EarliestModifiedFilter + @LatestModifiedFilter
	
		set @EarliestModifiedFilter = REPLACE( @EarliestModifiedFilter, 'Modified', 'Created')
		set @LatestModifiedFilter = REPLACE( @LatestModifiedFilter, 'Modified', 'Created')
			
		set @AppLogQuery = ' union all select cast(ObjectKey as int) as CatalogEntryId from ApplicationLog where [Source] = ''catalog'' and [Operation] = ''Modified'' and [ObjectType] = ''relation'' and' + @EarliestModifiedFilter + @LatestModifiedFilter

		-- applying the ApplicationLog.
		set @ModifiedCondition = @ModifiedCondition + @AppLogQuery
    end

    set @query = 
    'insert into CatalogEntrySearchResults_SingleSort (SearchSetId, ResultIndex, CatalogEntryId, ApplicationId) ' +
    'select distinct ''' + cast(@SearchSetId as nvarchar(36)) + ''', ROW_NUMBER() over (order by e.CatalogEntryId), e.CatalogEntryId, e.ApplicationId from CatalogEntry e where ' +
	' e.ApplicationId = ''' + cast(@ApplicationId as nvarchar(36)) + ''' ' +
      'and e.CatalogId = ' + cast(@CatalogId as nvarchar) + ' ' +
	  ' and e.CatalogEntryId in (' + @ModifiedCondition + ')'
      
    if @IncludeInactive = 0 set @query = @query + ' and e.IsActive = 1'

    execute dbo.sp_executesql @query
    
    select @@ROWCOUNT
end
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntrySearch]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_CatalogEntrySearch] 
GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntrySearch]
(
    @ApplicationId              uniqueidentifier,
    @SearchSetId                uniqueidentifier,
    @Language                   nvarchar(50),
    @Catalogs                   nvarchar(max),
    @CatalogNodes               nvarchar(max),
    @SQLClause                  nvarchar(max),
    @MetaSQLClause              nvarchar(max),
    @KeywordPhrase              nvarchar(max),
    @OrderBy                    nvarchar(max),
    @Namespace                  nvarchar(1024) = N'',
    @Classes                    nvarchar(max) = N'',
    @StartingRec                int,
    @NumRecords                 int,
    @JoinType                   nvarchar(50),
    @SourceTableName            sysname,
    @TargetQuery                nvarchar(max),
    @SourceJoinKey              sysname,
    @TargetJoinKey              sysname,
    @RecordCount                int OUTPUT,
    @ReturnTotalCount           bit = 1
)
AS

BEGIN
    SET NOCOUNT ON
    
    DECLARE @FilterVariables_tmp        nvarchar(max)
    DECLARE @query_tmp      nvarchar(max)
    DECLARE @FilterQuery_tmp        nvarchar(max)
    declare @FromQuery_tmp nvarchar(max)
    declare @SelectCountQuery_tmp nvarchar(max)
    declare @FullQuery nvarchar(max)
    DECLARE @JoinQuery_tmp      nvarchar(max)

    -- Precalculate length for constant strings
    DECLARE @MetaSQLClauseLength bigint
    DECLARE @KeywordPhraseLength bigint
    SET @MetaSQLClauseLength = LEN(@MetaSQLClause)
    SET @KeywordPhraseLength = LEN(@KeywordPhrase)

    set @RecordCount = -1

    -- ######## CREATE FILTER QUERY
    -- CREATE "JOINS" NEEDED
    -- Create filter query
    set @FilterQuery_tmp = N''
    --set @FilterQuery_tmp = N' INNER JOIN Catalog [Catalog] ON [Catalog].CatalogId = CatalogEntry.CatalogId'

    -- Only add NodeEntryRelation table join if one Node filter is specified, if more than one then we can't inner join it
    if(Len(@CatalogNodes) != 0 and (select count(Item) from ecf_splitlist(@CatalogNodes)) <= 1)
    begin
        set @FilterQuery_tmp = @FilterQuery_tmp + N' INNER JOIN NodeEntryRelation NodeEntryRelation ON CatalogEntry.CatalogEntryId = NodeEntryRelation.CatalogEntryId'
    end
    
    -- If nodes specified, no need to filter by catalog since that is done in node filter
    if(Len(@CatalogNodes) = 0)
    begin
        set @FilterQuery_tmp = @FilterQuery_tmp + N' INNER JOIN @Catalogs_temp catalogs ON CatalogEntry.CatalogId = catalogs.CatalogId '
    end

    -- If language specified, then filter by language   
    if (Len(@Language) != 0)
    begin
        set @FilterQuery_tmp = @FilterQuery_tmp + N' INNER JOIN CatalogLanguage l ON l.CatalogId = CatalogEntry.CatalogId AND l.LanguageCode = N'''+@Language+'''' 
    end 

    -- CREATE "WHERE" NEEDED
    set @FilterQuery_tmp = @FilterQuery_tmp + N' WHERE CatalogEntry.ApplicationId = ''' + cast(@ApplicationId as nvarchar(100)) + ''' '

    IF(@KeywordPhraseLength>0)
        SET @FilterQuery_tmp = @FilterQuery_tmp + N' AND CatalogEntry.Name LIKE N''%' + @KeywordPhrase + '%'' ';    

    -- Different filter if more than one category is specified
    if(Len(@CatalogNodes) != 0 and (select count(Item) from ecf_splitlist(@CatalogNodes)) > 1)
    begin
        set @FilterQuery_tmp = @FilterQuery_tmp + N' AND CatalogEntry.CatalogEntryId in (select NodeEntryRelation.CatalogEntryId from NodeEntryRelation NodeEntryRelation where '
    end

    -- Add node filter, have to do this way to not produce multiple entry items
    if(Len(@CatalogNodes) != 0)
    begin
        set @FilterQuery_tmp = @FilterQuery_tmp + N' AND NodeEntryRelation.CatalogNodeId IN (select CatalogNode.CatalogNodeId from CatalogNode CatalogNode'
        set @FilterQuery_tmp = @FilterQuery_tmp + N' WHERE (CatalogNode.[Code] in (select Item from ecf_splitlist(''' + @CatalogNodes + '''))) AND NodeEntryRelation.CatalogId in (select * from @Catalogs_temp)'
        set @FilterQuery_tmp = @FilterQuery_tmp + N')'
        --set @FilterQuery_tmp = @FilterQuery_tmp; + N' WHERE (CatalogNode.[Code] in (select Item from ecf_splitlist(''' + @CatalogNodes + ''')))'
    end

    -- Different filter if more than one category is specified
    if(Len(@CatalogNodes) != 0 and (select count(Item) from ecf_splitlist(@CatalogNodes)) > 1)
    begin
        set @FilterQuery_tmp = @FilterQuery_tmp + N')'
    end

    --set @FilterQuery_tmp = @FilterQuery_tmp + N')'

    -- add sql clause statement here, if specified
    if(Len(@SQLClause) != 0)
    begin
        set @FilterQuery_tmp = @FilterQuery_tmp + N' AND (' + @SqlClause + ')'
    end

    -- Create from command  
    SET @FromQuery_tmp = N'FROM [CatalogEntry] CatalogEntry' 
    
    --add meta class name filter
    DECLARE @MetaClassNameFilter NVARCHAR(MAX)
    SET @MetaClassNameFilter = ''
    IF (LEN(@Classes) > 0)
    BEGIN
        SET @MetaClassNameFilter = ' AND MC.Name IN (select Item from ecf_splitlist(''' +@Classes + '''))'
    END

    --if @MetaSQLClause is not empty, we filter by _ExcludedCatalogEntryMarkets field and also meta class name if it is not empty.
    IF(@MetaSQLClauseLength>0)
    BEGIN
        SET @FromQuery_tmp = @FromQuery_tmp + N' 
                INNER JOIN
                (
                    select CP.ObjectId 
                    from CatalogContentProperty CP
                    inner join MetaClass MC ON MC.MetaClassId = CP.MetaClassId
                    inner join MetaKey MK ON CP.Number = MK.MetaKey
                    join MetaMultiValueDictionary mmvd on mk.MetaKey = mmvd.MetaKey 
                    join MetaDictionary md on mmvd.MetaDictionaryId = md.MetaDictionaryId and mk.MetaFieldId = md.MetaFieldId 

                    Where MetaFieldName = ''_ExcludedCatalogEntryMarkets'' 
                        AND CP.ObjectTypeId = 0 --entry only
                        AND md.Value IN (' + @MetaSQLClause + ') '
                        + @MetaClassNameFilter +' 
                ) ExcludedMarkets ON ExcludedMarkets.ObjectId = [CatalogEntry].CatalogEntryId
         '
    END
    --if not, we filter by meta class name if it is not empty.
    ELSE IF (LEN(@Classes) > 0)
    BEGIN
        SET @FromQuery_tmp = @FromQuery_tmp + N' 
                INNER JOIN
                (
                    select distinct CP.ObjectId 
                    from CatalogContentProperty CP
                    inner join MetaClass MC ON MC.MetaClassId = CP.MetaClassId
                    Where CP.ObjectTypeId = 0 --entry only
                        ' + @MetaClassNameFilter +' 
                ) FilteredEntries ON FilteredEntries.ObjectId = [CatalogEntry].CatalogEntryId
         '
    END

    -- attach inner join if needed
    if(@JoinType is not null and Len(@JoinType) > 0)
    begin
        set @Query_tmp = ''
        EXEC [ecf_CreateTableJoinQuery] @SourceTableName, @TargetQuery, @SourceJoinKey, @TargetJoinKey, @JoinType, @Query_tmp OUT
        print(@Query_tmp)
        set @FromQuery_tmp = @FromQuery_tmp + N' ' + @Query_tmp
    end
    --print(@FromQuery_tmp)
    
    -- order by statement here
    if(Len(@OrderBy) = 0 and Len(@CatalogNodes) != 0 and CHARINDEX(',', @CatalogNodes) = 0)
    begin
        set @OrderBy = 'NodeEntryRelation.SortOrder'
    end
    else if(Len(@OrderBy) = 0)
    begin
        set @OrderBy = 'CatalogEntry.CatalogEntryId'
    end

    --print(@FilterQuery_tmp)
    -- add catalogs temp variable that will be used to filter out catalogs
    set @FilterVariables_tmp = 'declare @Catalogs_temp table (CatalogId int);'
    set @FilterVariables_tmp = @FilterVariables_tmp + 'INSERT INTO @Catalogs_temp select CatalogId from Catalog'
    if(Len(RTrim(LTrim(@Catalogs)))>0)
        set @FilterVariables_tmp = @FilterVariables_tmp + ' WHERE ([Catalog].[Name] in (select Item from ecf_splitlist(''' + @Catalogs + ''')))'
    set @FilterVariables_tmp = @FilterVariables_tmp + ';'

    if(@ReturnTotalCount = 1) -- Only return count if we requested it
        begin
            set @FullQuery = N'SELECT count([CatalogEntry].CatalogEntryId) OVER() TotalRecords, [CatalogEntry].CatalogEntryId,  ROW_NUMBER() OVER(ORDER BY ' + @OrderBy + N') RowNumber ' + @FromQuery_tmp + @FilterQuery_tmp
            -- use temp table variable
            set @FullQuery = N'with OrderedResults as (' + @FullQuery +') INSERT INTO @Page_temp (TotalRecords, ObjectId, SortOrder) SELECT top(' + cast(@NumRecords as nvarchar(50)) + ') TotalRecords, CatalogEntryId, RowNumber FROM OrderedResults WHERE RowNumber > ' + cast(@StartingRec as nvarchar(50)) + ';'
            --print(@FullQuery)
            set @FullQuery = @FilterVariables_tmp + 'declare @Page_temp table (TotalRecords int,ObjectId int,SortOrder int);' + @FullQuery + ';select @RecordCount = TotalRecords from @Page_temp;INSERT INTO CatalogEntrySearchResults (SearchSetId, CatalogEntryId, SortOrder) SELECT ''' + cast(@SearchSetId as nvarchar(100)) + N''', ObjectId, SortOrder from @Page_temp;'
            exec sp_executesql @FullQuery, N'@RecordCount int output', @RecordCount = @RecordCount OUTPUT
            
            --print @FullQuery
            --exec(@FullQuery)          
        end
    else
        begin
            -- simplified query with no TotalRecords, should give some performance gain
            set @FullQuery = N'SELECT [CatalogEntry].CatalogEntryId, ROW_NUMBER() OVER(ORDER BY ' + @OrderBy + N') RowNumber ' + @FromQuery_tmp + @FilterQuery_tmp
            
            set @FullQuery = @FilterVariables_tmp + N'with OrderedResults as (' + @FullQuery +') INSERT INTO CatalogEntrySearchResults (SearchSetId, CatalogEntryId, SortOrder) SELECT top(' + cast(@NumRecords as nvarchar(50)) + ') ''' + cast(@SearchSetId as nvarchar(100)) + N''', CatalogEntryId, RowNumber FROM OrderedResults WHERE RowNumber > ' + cast(@StartingRec as nvarchar(50)) + ';'
            --print(@FullQuery)
            --select * from CatalogEntrySearchResults
            exec(@FullQuery)
        end

    -- print(@FullQuery)
    SET NOCOUNT OFF
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogNode_ChildNodeCount]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_CatalogNode_ChildNodeCount] 
GO

CREATE PROCEDURE [dbo].[ecf_CatalogNode_ChildNodeCount]
    @CatalogId int = 0
AS
SELECT temp.ParentNodeId, COUNT(*) AS ChildCount FROM
    (SELECT ParentNodeId, CatalogNodeId as ChildNodeId FROM CatalogNode WHERE CatalogId = @CatalogId
        UNION
    SELECT ParentNodeId, ChildNodeId FROM CatalogNodeRelation WHERE CatalogId = @CatalogId) AS temp
GROUP BY ParentNodeId

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogNode_ChildEntryCount]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_CatalogNode_ChildEntryCount] 
GO

CREATE PROCEDURE [dbo].[ecf_CatalogNode_ChildEntryCount]
    @CatalogId int = 0
AS
SELECT ParentNodeId, COUNT(*) AS ChildCount
FROM
    (SELECT
        R.CatalogNodeId AS ParentNodeId, R.CatalogEntryId
    FROM
        NodeEntryRelation R
        INNER JOIN CatalogNode N on N.CatalogNodeId = R.CatalogNodeId
    WHERE
        N.CatalogId = @CatalogId

    UNION ALL

    SELECT
        0 AS ParentNodeId, E.CatalogEntryId
    FROM
        CatalogEntry E
    WHERE
        NOT EXISTS (SELECT 1 FROM NodeEntryRelation R WHERE R.CatalogEntryId = E.CatalogEntryId)
        AND E.CatalogId = @CatalogId
    ) temp
GROUP BY ParentNodeId

GO

IF EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_OrderGroupNote_OrderGroupId')
DROP INDEX IX_OrderGroupNote_OrderGroupId ON [dbo].[OrderGroupNote]
CREATE NONCLUSTERED INDEX [IX_OrderGroupNote_OrderGroupId]
    ON [dbo].[OrderGroupNote]([OrderGroupId] ASC);

GO

IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name = 'udttOrderGroupNote') DROP TYPE [dbo].[udttOrderGroupNote]
GO

CREATE TYPE [dbo].[udttOrderGroupNote] AS TABLE (
    [OrderNoteId] [int] NULL,
    [OrderGroupId] [int] NOT NULL,
    [CustomerId] [uniqueidentifier] NOT NULL,
    [Title] [nvarchar](255) NULL,
    [Type] [nvarchar](50) NULL,
    [Detail] [ntext] NULL,
    [Created] [datetime] NOT NULL,
    [LineItemId] [int] NULL)

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mc_OrderGroupNotesUpdate]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mc_OrderGroupNotesUpdate] 
GO 

CREATE PROCEDURE [dbo].[mc_OrderGroupNotesUpdate]
@OrderGroupNotes udttOrderGroupNote readonly
AS
BEGIN
SET NOCOUNT ON;

MERGE dbo.OrderGroupNote AS T
USING @OrderGroupNotes AS S
ON (T.OrderNoteId = S.OrderNoteId)
WHEN NOT MATCHED BY TARGET
	THEN INSERT (
		[OrderGroupId],
		[CustomerId],
		[Title],
		[Type],
		[Detail],
		[Created],
		[LineItemId])
	VALUES(S.OrderGroupId,
		S.CustomerId,
		S.Title,
		S.Type,
		S.Detail,
		S.Created,
		S.LineItemId)
WHEN MATCHED THEN 
UPDATE SET
	[OrderGroupId] = S.OrderGroupId,
	[CustomerId] = S.CustomerId,
	[Title] = S.Title,
	[Type] = S.Type,
	[Detail] = S.Detail,
	[Created] = S.Created,
	[LineItemId] = S.LineItemId;
END

GO

--Delete orphaned notes
DELETE n FROM dbo.OrderGroupNote n 
  LEFT JOIN dbo.OrderGroup g ON n.OrderGroupId = g.OrderGroupId
      WHERE g.OrderGroupId IS NULL

GO

ALTER TABLE [dbo].[OrderGroupNote]  WITH CHECK ADD  CONSTRAINT [FK_OrderGroupNote_OrderGroup] FOREIGN KEY([OrderGroupId])
REFERENCES [dbo].[OrderGroup]([OrderGroupId])
GO

ALTER TABLE [dbo].[OrderGroupNote] CHECK CONSTRAINT [FK_OrderGroupNote_OrderGroup]
GO


IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mc_OrderGroupNoteUpdate]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mc_OrderGroupNoteUpdate] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mc_OrderGroupNoteInsert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mc_OrderGroupNoteInsert] 
GO 

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_DeleteMetaKeyObjects]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[mdpsp_sys_DeleteMetaKeyObjects] 
GO

CREATE PROCEDURE [dbo].[mdpsp_sys_DeleteMetaKeyObjects]
    @MetaClassId    INT,
    @MetaFieldId    INT =   -1,
    @MetaObjectId   INT =   -1,
    @WorkId         INT =   -1
AS
    -- Delete MetaObjectValue
    DELETE FROM MetaObjectValue  WHERE MetaKey IN
        (SELECT MK.MetaKey FROM MetaKey MK WHERE
            (@MetaObjectId = MK.MetaObjectId OR @MetaObjectId = -1) AND
            (@MetaClassId = MK.MetaClassId OR @MetaClassId = -1) AND
            (@MetaFieldId = MK.MetaFieldId  OR @MetaFieldId = -1) AND
            (@WorkId = MK.WorkId OR @WorkId = -1)
        )

     IF @@ERROR <> 0 GOTO ERR

    -- Delete MetaStringDictionaryValue
    if(@MetaFieldId = -1 and @MetaObjectId != -1 and @MetaClassId != -1)
        DELETE FROM MetaStringDictionaryValue  WHERE MetaKey IN
            (SELECT MK.MetaKey FROM MetaKey MK WHERE
                (@MetaObjectId = MK.MetaObjectId) AND
                (@MetaClassId = MK.MetaClassId) AND
                (@WorkId = MK.WorkId OR @WorkId = -1)
            )
    else
        DELETE FROM MetaStringDictionaryValue  WHERE MetaKey IN
            (SELECT MK.MetaKey FROM MetaKey MK WHERE
                (@MetaObjectId = MK.MetaObjectId OR @MetaObjectId = -1) AND
                (@MetaClassId = MK.MetaClassId OR @MetaClassId = -1) AND
                (@MetaFieldId = MK.MetaFieldId  OR @MetaFieldId = -1) AND
                (@WorkId = MK.WorkId OR @WorkId = -1)
            )

     IF @@ERROR <> 0 GOTO ERR

    -- Delete MetaMultiValueDictionary
    DELETE FROM MetaMultiValueDictionary  WHERE MetaKey IN
        (SELECT MK.MetaKey FROM MetaKey MK WHERE
            (@MetaObjectId = MK.MetaObjectId OR @MetaObjectId = -1) AND
            (@MetaClassId = MK.MetaClassId OR @MetaClassId = -1) AND
            (@MetaFieldId = MK.MetaFieldId  OR @MetaFieldId = -1) AND
            (@WorkId = MK.WorkId OR @WorkId = -1)
        )

     IF @@ERROR <> 0 GOTO ERR

    -- Delete Meta File
    DELETE FROM MetaFileValue  WHERE MetaKey IN
        (SELECT MK.MetaKey FROM MetaKey MK WHERE
            (@MetaObjectId = MK.MetaObjectId OR @MetaObjectId = -1)  AND
            (@MetaClassId = MK.MetaClassId OR @MetaClassId = -1) AND
            (@MetaFieldId = MK.MetaFieldId  OR @MetaFieldId = -1) AND
            (@WorkId = MK.WorkId OR @WorkId = -1)
        )

     IF @@ERROR <> 0 GOTO ERR

    -- Clear Meta Key
    if(@MetaFieldId = -1 and @MetaObjectId != -1 and @MetaClassId != -1)
    begin
        DELETE FROM MetaKey WHERE
            (@MetaObjectId = MetaObjectId) AND
            (@MetaClassId = MetaClassId) AND
            (@WorkId = WorkId OR @WorkId = -1)
    end
    else
    begin
        DELETE FROM MetaKey  WHERE
            (@MetaObjectId = MetaObjectId OR @MetaObjectId = -1)  AND
            (@MetaClassId = MetaClassId OR @MetaClassId = -1) AND
            (@MetaFieldId = MetaFieldId OR @MetaFieldId = -1) AND
            (@WorkId = WorkId OR @WorkId = -1)
    end

ERR:
    RETURN
GO


IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_DeleteByObjectId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[CatalogContentProperty_DeleteByObjectId] 
GO

CREATE PROCEDURE [dbo].[CatalogContentProperty_DeleteByObjectId]
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

    -- Delete data for all reference type meta fields (dictionaries etc)
    exec mdpsp_sys_DeleteMetaKeyObjects @MetaClassId = @ClassId, @MetaObjectId = @ObjectId 
END
GO


IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_DeleteByWorkId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersion_DeleteByWorkId] 
GO

CREATE PROCEDURE [dbo].[ecfVersion_DeleteByWorkId]
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

    -- Delete data for all reference type meta fields (dictionaries etc)
    EXEC mdpsp_sys_DeleteMetaKeyObjects @MetaClassId = @MetaClassId, @MetaObjectId = @ObjectId, @WorkId = @WorkId
END
GO


IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_DeleteByObjectIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersion_DeleteByObjectIds] 
GO

CREATE PROCEDURE [dbo].[ecfVersion_DeleteByObjectIds]
    @ObjectIds udttObjectWorkId readonly
AS
BEGIN

    DECLARE @AffectedMetaKeys TABLE (MetaClassId INT, MetaObjectId INT, WorkId INT)
    INSERT INTO @AffectedMetaKeys

    SELECT T.MetaClassId, V.ObjectId, V.WorkId
    FROM ecfVersion V
        INNER JOIN
        (SELECT CatalogEntryId AS ObjectId, 0 AS ObjectTypeId, MetaClassId FROM CatalogEntry
            UNION ALL
        SELECT CatalogNodeId AS ObjectId, 1 AS ObjectTypeId, MetaClassId FROM CatalogNode) T
        ON V.ObjectId = T.ObjectId AND V.ObjectTypeId = T.ObjectTypeId
        INNER JOIN @ObjectIds I
        ON I.ObjectId = V.ObjectId AND I.ObjectTypeId = V.ObjectTypeId

    --When deleting content draft, it will delete automatically Asset, SEO, Property, Variation, Catalog draft by Cascade
    DELETE v FROM ecfVersion v
    INNER JOIN @ObjectIds i
        ON i.ObjectId = v.ObjectId AND i.ObjectTypeId = v.ObjectTypeId

    -- Delete data for all reference type meta fields (dictionaries etc)
    DECLARE @ClassId INT
    DECLARE @ObjectId INT
    DECLARE @WId INT
    DECLARE cur CURSOR LOCAL FOR SELECT MetaClassId, MetaObjectId, WorkId FROM @AffectedMetaKeys

    OPEN cur
    FETCH NEXT FROM cur INTO @ClassId, @ObjectId, @WId

    WHILE @@FETCH_STATUS = 0 BEGIN
        EXEC mdpsp_sys_DeleteMetaKeyObjects @MetaClassId = @ClassId, @MetaObjectId = @ObjectId, @WorkId = @WId
        FETCH NEXT FROM cur INTO @ClassId, @ObjectId, @WId
    END

    CLOSE cur
    DEALLOCATE cur
END
GO


IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_DeleteByObjectId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersion_DeleteByObjectId] 
GO

CREATE PROCEDURE [dbo].[ecfVersion_DeleteByObjectId]
    @ObjectId [int],
    @ObjectTypeId [int]
AS
BEGIN
    DECLARE @AffectedMetaKeys TABLE (MetaClassId INT, WorkId INT)
    INSERT INTO @AffectedMetaKeys

    SELECT T.MetaClassId, V.WorkId
    FROM ecfVersion V
        INNER JOIN
        (SELECT CatalogEntryId AS ObjectId, 0 AS ObjectTypeId, MetaClassId FROM CatalogEntry
            UNION ALL
        SELECT CatalogNodeId AS ObjectId, 1 AS ObjectTypeId, MetaClassId FROM CatalogNode) T
        ON V.ObjectId = T.ObjectId AND V.ObjectTypeId = T.ObjectTypeId
     WHERE V.ObjectId = @ObjectId AND V.ObjectTypeId = @ObjectTypeId

    --When deleting content draft, it will delete automatically Asset, SEO, Property, Variation, Catalog draft by Cascade
    DELETE FROM ecfVersion
    WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId

    -- Delete data for all reference type meta fields (dictionaries etc)
    DECLARE @ClassId INT
    DECLARE @WId INT
    DECLARE cur CURSOR LOCAL FOR SELECT MetaClassId, WorkId FROM @AffectedMetaKeys

    OPEN cur
    FETCH NEXT FROM cur INTO @ClassId, @WId

    WHILE @@FETCH_STATUS = 0 BEGIN
        EXEC mdpsp_sys_DeleteMetaKeyObjects @MetaClassId = @ClassId, @MetaObjectId = @ObjectId, @WorkId = @WId
        FETCH NEXT FROM cur INTO @ClassId, @WId
    END

    CLOSE cur
    DEALLOCATE cur
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogEntry_Delete]') AND OBJECTPROPERTY(id, N'IsTrigger') = 1) DROP TRIGGER [dbo].[CatalogEntry_Delete]
GO

CREATE TRIGGER [dbo].[CatalogEntry_Delete] ON CatalogEntry FOR DELETE
AS
    --Delete all draft of deleted entry
    DELETE d FROM ecfVersion d
    INNER JOIN deleted ON d.ObjectId = deleted.CatalogEntryId AND d.ObjectTypeId = 0

    --Delete all extra info of this entry
    DELETE c FROM CatalogContentEx c 
    INNER JOIN deleted ON c.ObjectId = deleted.CatalogEntryId AND c.ObjectTypeId = 0

    DECLARE @AffectedMetaKeys TABLE (MetaClassId INT, MetaObjectId INT)
    INSERT INTO @AffectedMetaKeys
    SELECT MK.MetaClassId, MK.MetaObjectId
    FROM MetaKey MK
        INNER JOIN deleted D
        ON MK.MetaObjectId = D.CatalogEntryId AND MK.MetaClassId = D.MetaClassId
    
    -- Delete data for all reference type meta fields (dictionaries etc)
    DECLARE @ClassId INT
    DECLARE @ObjectId INT
    DECLARE cur CURSOR LOCAL FOR SELECT MetaClassId, MetaObjectId FROM @AffectedMetaKeys

    OPEN cur
    FETCH NEXT FROM cur INTO @ClassId, @ObjectId

    WHILE @@FETCH_STATUS = 0 BEGIN
        EXEC mdpsp_sys_DeleteMetaKeyObjects @MetaClassId = @ClassId, @MetaObjectId = @ObjectId
        FETCH NEXT FROM cur INTO @ClassId, @ObjectId
    END

    CLOSE cur
    DEALLOCATE cur
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogNode_Delete]') AND OBJECTPROPERTY(id, N'IsTrigger') = 1) DROP TRIGGER [dbo].[CatalogNode_Delete]
GO

CREATE TRIGGER [dbo].[CatalogNode_Delete] ON CatalogNode FOR DELETE
AS
    --Delete all draft of deleted entry
    DELETE d FROM ecfVersion d
    INNER JOIN deleted ON d.ObjectId = deleted.CatalogNodeId AND d.ObjectTypeId = 1

    --Delete all extra info of this entry
    DELETE c FROM CatalogContentEx c 
    INNER JOIN deleted ON c.ObjectId = deleted.CatalogNodeId AND c.ObjectTypeId = 1

    DECLARE @AffectedMetaKeys TABLE (MetaClassId INT, MetaObjectId INT)
    INSERT INTO @AffectedMetaKeys
    SELECT MK.MetaClassId, MK.MetaObjectId
    FROM MetaKey MK
        INNER JOIN deleted D
        ON MK.MetaObjectId = D.CatalogNodeId AND MK.MetaClassId = D.MetaClassId
    
    -- Delete data for all reference type meta fields (dictionaries etc)
    DECLARE @ClassId INT
    DECLARE @ObjectId INT
    DECLARE cur CURSOR LOCAL FOR SELECT MetaClassId, MetaObjectId FROM @AffectedMetaKeys

    OPEN cur
    FETCH NEXT FROM cur INTO @ClassId, @ObjectId

    WHILE @@FETCH_STATUS = 0 BEGIN
        EXEC mdpsp_sys_DeleteMetaKeyObjects @MetaClassId = @ClassId, @MetaObjectId = @ObjectId
        FETCH NEXT FROM cur INTO @ClassId, @ObjectId
    END

    CLOSE cur
    DEALLOCATE cur
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_GetMetaKey]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[mdpsp_sys_GetMetaKey]
GO

CREATE PROCEDURE [dbo].[mdpsp_sys_GetMetaKey]
    @MetaObjectId   INT,
    @WorkId         INT = NULL,
    @MetaClassId    INT,
    @MetaFieldId    INT,
    @Language NVARCHAR(20) = NULL,
    @Retval INT OUT
AS
SET NOCOUNT ON

DECLARE @TableName NVARCHAR(256)
SET @TableName = (SELECT TableName FROM MetaClass WHERE MetaClassId = @MetaClassId)

IF dbo.mdpfn_sys_IsCatalogMetaDataTable(@TableName) = 0
BEGIN
    DECLARE @IsMultiLanguage BIT
    SET @IsMultiLanguage = (SELECT MultiLanguageValue FROM MetaField WHERE MetaFieldId = @MetaFieldId)

    IF @IsMultiLanguage = 0 OR ISNULL(@Language, '') = ''
    BEGIN
        SELECT @Retval = MetaKey FROM MetaKey WHERE MetaObjectId = @MetaObjectId AND MetaClassId = @MetaClassId AND MetaFieldId = @MetaFieldId
        
        IF @Retval IS NULL
        BEGIN
            INSERT INTO MetaKey (MetaObjectId, MetaClassId, MetaFieldId) VALUES (@MetaObjectId, @MetaClassId, @MetaFieldId)
            SET @Retval = SCOPE_IDENTITY()
        END
    END
    ELSE
    BEGIN
        SELECT @Retval = MetaKey FROM MetaKey WHERE MetaObjectId = @MetaObjectId AND MetaClassId = @MetaClassId AND MetaFieldId = @MetaFieldId AND Language=@Language COLLATE DATABASE_DEFAULT
        
        IF @Retval IS NULL
        BEGIN
            INSERT INTO MetaKey (MetaObjectId, MetaClassId, MetaFieldId, Language) VALUES (@MetaObjectId, @MetaClassId, @MetaFieldId, @Language)
            SET @Retval = SCOPE_IDENTITY()
        END
    END
END
ELSE
BEGIN
    IF ISNULL(@Language, '') = ''
    BEGIN
        DECLARE @CatalogId INT
        SET @CatalogId = CASE WHEN @TableName LIKE 'CatalogEntryEx%' THEN
                                (SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @MetaObjectId)
                                WHEN @TableName LIKE 'CatalogNodeEx%' THEN                          
                                (SELECT CatalogId FROM CatalogNode WHERE CatalogNodeId = @MetaObjectId)
                            END
        SET @Language = (SELECT DefaultLanguage FROM dbo.Catalog WHERE CatalogId = @CatalogId)
    END

    SELECT @Retval = MetaKey FROM MetaKey WHERE MetaObjectId = @MetaObjectId AND MetaClassId = @MetaClassId AND MetaFieldId = @MetaFieldId AND ISNULL(@WorkId,0) = ISNULL(WorkId,0) AND Language = @Language COLLATE DATABASE_DEFAULT
        
    IF @Retval IS NULL
    BEGIN
        INSERT INTO MetaKey (MetaObjectId, WorkId, MetaClassId, MetaFieldId, Language) VALUES (@MetaObjectId, @WorkId, @MetaClassId, @MetaFieldId, @Language)
        SET @Retval = SCOPE_IDENTITY()
    END
END
GO

IF EXISTS(SELECT * FROM sys.indexes WHERE object_id = object_id('dbo.CatalogContentProperty') AND NAME ='IX_CatalogContentProperty_Temp_Number')
    DROP INDEX IX_CatalogContentProperty_Temp_Number ON dbo.CatalogContentProperty;
GO

CREATE NONCLUSTERED INDEX [IX_CatalogContentProperty_Temp_Number]
ON [dbo].[CatalogContentProperty] ([Number])
INCLUDE ([MetaFieldId])
WHERE Number IS NOT NULL

GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 7, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion