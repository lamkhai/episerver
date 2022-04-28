--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 2, @patch int = 2    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntrySearch]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntrySearch] 
GO

-- create ecf_CatalogEntrySearch sp
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
		SET @FromQuery_tmp = @FromQuery_tmp + @MetaSQLClause
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
-- end of creating ecf_CatalogEntrySearch sp

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_List]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_List] 
GO

-- create ecfVersion_List sp
CREATE PROCEDURE [dbo].[ecfVersion_List]
	@ObjectIds [dbo].[udttContentList] READONLY,
	@ObjectTypeId int
AS
BEGIN
	IF @ObjectTypeId = 1 -- Node, join to CatalogNode table to get additional columns
		SELECT vn.*, n.CatalogId, n.ApplicationId, n.ContentGuid, NULL as ClassTypeId, n.MetaClassId, n.ParentNodeId as ParentId
		FROM dbo.ecfVersion vn
		INNER JOIN CatalogNode n ON vn.ObjectId = n.CatalogNodeId
		INNER JOIN @ObjectIds i ON vn.ObjectId = i.ContentId
		WHERE vn.ObjectTypeId = 1 AND CurrentLanguageRemoved = 0

	ELSE IF @ObjectTypeId = 2 -- Catalog, join to Catalog table to additional columns
		SELECT vc.*, c.CatalogId, c.ApplicationId, c.ContentGuid, NULL as ClassTypeId, NULL as MetaClassId, NULL AS ParentId
		FROM dbo.ecfVersion vc
		INNER JOIN Catalog c ON vc.ObjectId = c.CatalogId
		INNER JOIN @ObjectIds i ON vc.ObjectId = i.ContentId
		WHERE vc.ObjectTypeId = 2 AND CurrentLanguageRemoved = 0

	ELSE -- Entry, join to CatalogEntry table to get additional columns
		SELECT ve.*, e.CatalogId, e.ApplicationId, e.ContentGuid, e.ClassTypeId, e.MetaClassId, NULL AS ParentId
		FROM dbo.ecfVersion ve
		INNER JOIN CatalogEntry e ON ve.ObjectId = e.CatalogEntryId
		INNER JOIN @ObjectIds i ON ve.ObjectId = i.ContentId
		WHERE ve.ObjectTypeId = 0 AND CurrentLanguageRemoved = 0
END
GO
-- end of creating ecfVersion_List sp

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 2, 2, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
