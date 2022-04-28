--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 0, @patch int = 5    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogNode_GetAllChildEntries]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_CatalogNode_GetAllChildEntries] 
GO
create procedure ecf_CatalogNode_GetAllChildEntries
    @catalogNodeIds udttCatalogNodeList readonly
as
begin
	declare @hierarchy table (CatalogNodeId int)
	insert @hierarchy exec ecf_CatalogNode_GetAllChildNodes @catalogNodeIds

    select distinct ce.CatalogEntryId, ce.ApplicationId, ce.Code
    from CatalogEntry ce
    join NodeEntryRelation ner on ce.CatalogEntryId = ner.CatalogEntryId
    where ner.CatalogNodeId in (select CatalogNodeId from @hierarchy)
end
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogNode_GetAllChildNodes]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_CatalogNode_GetAllChildNodes] 
GO
create procedure ecf_CatalogNode_GetAllChildNodes
    @catalogNodeIds udttCatalogNodeList readonly
as
begin
    with all_node_relations as 
    (
        select ParentNodeId, CatalogNodeId as ChildNodeId from CatalogNode
        where ParentNodeId > 0
        union
        select ParentNodeId, ChildNodeId from CatalogNodeRelation
    ),
    hierarchy as
    (
        select 
            n.CatalogNodeId,
            '|' + CAST(n.CatalogNodeId as nvarchar(4000)) + '|' as CyclePrevention
        from @catalogNodeIds n
        union all
        select
            children.ChildNodeId as CatalogNodeId,
            parent.CyclePrevention + CAST(children.ChildNodeId as nvarchar(4000)) + '|' as CyclePrevention
        from hierarchy parent
        join all_node_relations children on parent.CatalogNodeId = children.ParentNodeId
        where CHARINDEX('|' + CAST(children.ChildNodeId as nvarchar(4000)) + '|', parent.CyclePrevention) = 0
    )
    select CatalogNodeId from hierarchy
end
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_UpdateCurrentLanguageRemoved]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersion_UpdateCurrentLanguageRemoved] 
GO
create procedure [dbo].[ecfVersion_UpdateCurrentLanguageRemoved]
	@ObjectId			int,
	@ObjectTypeId		int
AS
begin
	create table #RecursiveContents (ObjectId int, ObjectTypeId int)
	declare @catalogId int

	-- in case node content
	if @ObjectTypeId = 1 
	begin
		-- Get all nodes and entries under the @objectId
		declare @catalogNodeIds udttCatalogNodeList
		insert into @catalogNodeIds values (@ObjectId)

		declare @hierarchy udttCatalogNodeList
		insert @hierarchy exec ecf_CatalogNode_GetAllChildNodes @catalogNodeIds

		insert into #RecursiveContents (ObjectId, ObjectTypeId) select CatalogNodeId, 1 from @hierarchy

		insert into #RecursiveContents (ObjectId, ObjectTypeId)
		select distinct ce.CatalogEntryId, 0
		from CatalogEntry ce
		inner join NodeEntryRelation ner on ce.CatalogEntryId = ner.CatalogEntryId
		inner join @hierarchy h on h.CatalogNodeId = ner.CatalogNodeId

		-- get CatalogId from node content
		select @catalogId = CatalogId from CatalogNode where CatalogNodeId = @ObjectId
	end
	else
	begin
		-- in case entry content, just update for only entry
		insert into #RecursiveContents (ObjectId, ObjectTypeId)
		values (@ObjectId, @ObjectTypeId)

		-- get CatalogId from entry content
		select @catalogId = CatalogId from CatalogEntry where CatalogEntryId = @ObjectId
	end

	update v
	set		CurrentLanguageRemoved = case when cl.LanguageCode = v.LanguageName collate DATABASE_DEFAULT then 0 else 1 end
	from	ecfVersion v
	inner join #RecursiveContents r 
				on r.ObjectId = v.ObjectId and r.ObjectTypeId = v.ObjectTypeId
	inner join CatalogLanguage cl on cl.CatalogId = @catalogId

	drop table #RecursiveContents
end
GO

-- modify ecf_CatalogRelationByChildEntryId
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogRelationByChildEntryId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogRelationByChildEntryId]
GO
CREATE PROCEDURE [dbo].[ecf_CatalogRelationByChildEntryId]
	@ApplicationId uniqueidentifier,
	@ChildEntryId int
AS
BEGIN
    select top 0 * from CatalogNodeRelation

	SELECT CER.* FROM CatalogEntryRelation CER
	INNER JOIN CatalogEntry CE ON CE.CatalogEntryId = CER.ChildEntryId
	WHERE
		CE.ApplicationId = @ApplicationId AND
		CER.ChildEntryId = @ChildEntryId
	ORDER BY CER.SortOrder
	
	SELECT CatalogId, CatalogEntryId, CatalogNodeId, SortOrder FROM NodeEntryRelation
	WHERE CatalogEntryId=@ChildEntryId
END
GO

-- create ecf_CatalogEntrySearch sp
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogEntrySearch]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntrySearch]
GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntrySearch]
(
	@ApplicationId				uniqueidentifier,
	@SearchSetId				uniqueidentifier,
	@Language 					nvarchar(50),
	@Catalogs 					nvarchar(max),
	@CatalogNodes 				nvarchar(max),
	@SQLClause 					nvarchar(max),
	@MetaSQLClause 				nvarchar(max),
	@KeywordPhrase				nvarchar(max),
	@OrderBy 					nvarchar(max),
	@Namespace					nvarchar(1024) = N'',
	@Classes					nvarchar(max) = N'',
	@StartingRec				int,
	@NumRecords					int,
	@JoinType					nvarchar(50),
	@SourceTableName			sysname,
	@TargetQuery				nvarchar(max),
	@SourceJoinKey				sysname,
	@TargetJoinKey				sysname,
	@RecordCount				int OUTPUT,
	@ReturnTotalCount			bit = 1
)
AS

BEGIN
	SET NOCOUNT ON
	
	DECLARE @FilterVariables_tmp 		nvarchar(max)
	DECLARE @query_tmp 		nvarchar(max)
	DECLARE @FilterQuery_tmp 		nvarchar(max)
	declare @FromQuery_tmp nvarchar(max)
	declare @SelectCountQuery_tmp nvarchar(max)
	declare @FullQuery nvarchar(max)
	DECLARE @JoinQuery_tmp 		nvarchar(max)

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
	
	IF(@MetaSQLClauseLength>0)
	BEGIN
		SET @FromQuery_tmp = @FromQuery_tmp + N' 
				INNER JOIN
				(
					select CP.ObjectId, CP.ObjectTypeId, md.Value 
					from CatalogContentProperty CP 
					inner join MetaKey MK ON CP.Number = MK.MetaKey
					join MetaMultiValueDictionary mmvd on mk.MetaKey = mmvd.MetaKey 
					join MetaDictionary md on mmvd.MetaDictionaryId = md.MetaDictionaryId and mk.MetaFieldId = md.MetaFieldId 

					Where MetaFieldName = ''_ExcludedCatalogEntryMarkets'' 
						AND CP.ObjectTypeId = 0 -- entry
						AND md.Value IN (' + @MetaSQLClause + ') 
				) ExcludedMarkets ON ExcludedMarkets.ObjectId = [CatalogEntry].CatalogEntryId
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
-- end of creating ecf_CatalogEntrySearch sp

-- create ecf_CatalogNodesList sp
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogNodesList]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogNodesList]
GO
CREATE PROCEDURE [dbo].[ecf_CatalogNodesList]
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
					SELECT CN.[CatalogNodeId] as ID, CN.[Name], ''Node'' as Type, CN.[Code], CN.[StartDate], CN.[EndDate], CN.[IsActive], CN.[SortOrder], OG.[NAME] as Owner
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
					SELECT CE.[CatalogEntryId] as ID, CE.[Name], CE.ClassTypeId as Type, CE.[Code], CE.[StartDate], CE.[EndDate], CE.[IsActive], 0, OG.[NAME] as Owner
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
				SELECT CN.[CatalogNodeId] as ID, CN.[Name], ''Node'' as Type, CN.[Code], CN.[StartDate], CN.[EndDate], CN.[IsActive], CN.[SortOrder], OG.[NAME] as Owner
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
				SELECT CE.[CatalogEntryId] as ID, CE.[Name], CE.ClassTypeId as Type, CE.[Code], CE.[StartDate], CE.[EndDate], CE.[IsActive], R.[SortOrder], OG.[NAME] as Owner
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
-- end of creating ecf_CatalogNodesList sp


IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_GetChildBySegment]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[mdpsp_GetChildBySegment] 
GO

CREATE PROCEDURE [dbo].[mdpsp_GetChildBySegment]
	@parentNodeId int,
	@catalogId int = 0,
	@UriSegment nvarchar(255)
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

	SELECT
		S.CatalogNodeId as ChildId,
		S.LanguageCode,
		1 as ContentType
	FROM CatalogItemSeo S WITH (NOLOCK)
		INNER JOIN CatalogNode N WITH (NOLOCK) ON N.CatalogNodeId = S.CatalogNodeId
		LEFT OUTER JOIN CatalogNodeRelation NR ON NR.ChildNodeId = S.CatalogNodeId
	WHERE
		UriSegment = @UriSegment AND N.IsActive = 1 AND
		((N.ParentNodeId = @parentNodeId AND (N.CatalogId = @catalogId OR @catalogId = 0))
		OR
		(NR.ParentNodeId = @parentNodeId AND (NR.CatalogId = @catalogId OR @catalogId = 0)))

	UNION ALL

	SELECT
		S.CatalogEntryId as ChildId,
		S.LanguageCode,
		0 as ContentType
	FROM CatalogItemSeo S  WITH (NOLOCK)
		INNER JOIN CatalogEntry E ON E.CatalogEntryId = S.CatalogEntryId
		LEFT OUTER JOIN NodeEntryRelation ER ON ER.CatalogEntryId = S.CatalogEntryId
	WHERE
		UriSegment = @UriSegment AND E.IsActive = 1 AND
		((ER.CatalogNodeId = @parentNodeId AND (ER.CatalogId = @catalogId OR @catalogId = 0))
		OR
		(@parentNodeId = 0 AND ER.CatalogNodeId IS NULL AND (E.CatalogId = @catalogId OR @catalogId = 0)))
END

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_ListMatchingSegments]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersion_ListMatchingSegments] 
GO

CREATE PROCEDURE [dbo].[ecfVersion_ListMatchingSegments]
	@ParentId INT,
	@CatalogId INT,
	@SeoUriSegment NVARCHAR(255)
AS
BEGIN

	SELECT v.ObjectId, v.ObjectTypeId, v.WorkId, v.LanguageName
	FROM ecfVersion v
		INNER JOIN CatalogEntry e on e.CatalogEntryId = v.ObjectId
		LEFT OUTER JOIN NodeEntryRelation r ON v.ObjectId = r.CatalogEntryId
	WHERE
		v.SeoUriSegment = @SeoUriSegment AND v.ObjectTypeId = 0 AND v.CurrentLanguageRemoved = 0 AND
		((r.CatalogNodeId = @ParentId AND (r.CatalogId = @CatalogId OR @CatalogId = 0))
		OR
		(@ParentId = 0 AND r.CatalogNodeId IS NULL AND (e.CatalogId = @CatalogId OR @CatalogId = 0)))

	UNION ALL

	SELECT v.ObjectId, v.ObjectTypeId, v.WorkId, v.LanguageName
	FROM ecfVersion v
		INNER JOIN CatalogNode n ON v.ObjectId = n.CatalogNodeId
		LEFT OUTER JOIN CatalogNodeRelation nr on v.ObjectId = nr.ChildNodeId
	WHERE
		v.SeoUriSegment = @SeoUriSegment AND v.ObjectTypeId = 1 AND v.CurrentLanguageRemoved = 0 AND
		((n.ParentNodeId = @ParentId AND (n.CatalogId = @CatalogId OR @CatalogId = 0))
		OR
		(nr.ParentNodeId = @ParentId AND (nr.CatalogId = @CatalogId OR @CatalogId = 0)))

END

GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 5, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
