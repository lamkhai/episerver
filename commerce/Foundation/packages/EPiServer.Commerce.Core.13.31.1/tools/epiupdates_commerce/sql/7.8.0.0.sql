--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 8, @patch int = 0    
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
    @ApplicationId uniqueidentifier,
    @LanguageCode nvarchar(50)
)
RETURNS bit
AS
BEGIN
    DECLARE @RetVal bit
    DECLARE @Count int
    DECLARE @parentId int
	DECLARE @CatalogId int
    
    -- get the parentId and CatalogId, based on entityId and the entity type
    IF @type = 0
	BEGIN
		SELECT @parentId = ParentNodeId, @CatalogId = CatalogId FROM CatalogNode WHERE CatalogNodeId = @entityId
	END
    ELSE
	BEGIN
        SET @parentId = (SELECT CatalogNodeId FROM NodeEntryRelation WHERE CatalogEntryId = @entityId)
		SET @CatalogId = (SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @entityId)
	END

    SET @RetVal = 0

    -- check if the UriSegment exists on sibling node
    SET @Count = (
                    SELECT COUNT(S.CatalogNodeId)
                    FROM CatalogItemSeo S WITH (NOLOCK) 
                    INNER JOIN CatalogNode N on N.CatalogNodeId = S.CatalogNodeId AND N.ApplicationId = S.ApplicationId 
                    LEFT JOIN CatalogNodeRelation NR ON N.CatalogNodeId = NR.ChildNodeId 
                    WHERE S.ApplicationId = @ApplicationId 
                        AND LanguageCode = @LanguageCode COLLATE DATABASE_DEFAULT 
                        AND S.CatalogNodeId <> @entityId
                        AND ((@parentId = 0 AND N.CatalogId = @CatalogId) OR (@parentId <> 0 AND (N.ParentNodeId = @parentId OR NR.ParentNodeId = @parentId)))
                        AND UriSegment = @UriSegment COLLATE DATABASE_DEFAULT 
                        AND N.IsActive = 1
                )
                
    IF @Count = 0 -- check against sibling entry if only UriSegment does not exist on sibling node
    BEGIN
        -- check if the UriSegment exists on sibling entry
        SET @Count = (
                        SELECT COUNT(S.CatalogEntryId)
                        FROM CatalogItemSeo S WITH (NOLOCK)
                        INNER JOIN CatalogEntry N ON N.CatalogEntryId = S.CatalogEntryId AND N.ApplicationId = S.ApplicationId 
                        LEFT JOIN NodeEntryRelation R ON R.CatalogEntryId = N.CatalogEntryId
                        WHERE 
                            S.ApplicationId = @ApplicationId 
                            AND S.LanguageCode = @LanguageCode COLLATE DATABASE_DEFAULT 
                            AND S.CatalogEntryId <> @entityId 
                            AND R.CatalogNodeId = @parentId
							AND R.CatalogId = @CatalogId
                            AND UriSegment = @UriSegment COLLATE DATABASE_DEFAULT 
                            AND N.IsActive = 1
                    )
    END

    IF @Count <> 0
    BEGIN
        SET @RetVal = 1
    END

    RETURN @RetVal;
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
	SELECT @FallbackLanguage = DefaultLanguage FROM dbo.[Catalog] WHERE CatalogId = @catalogId

	-- load from fallback language only if @Language is not existing language of catalog.
	-- in other work, fallback language is used for invalid @Language value only.
	IF @Language NOT IN (SELECT LanguageCode FROM dbo.CatalogLanguage WHERE CatalogId = @catalogId)
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
				((F.MultiLanguageValue = 1 AND LanguageName = @Language COLLATE DATABASE_DEFAULT) OR ((F.MultiLanguageValue = 0 AND LanguageName = @FallbackLanguage COLLATE DATABASE_DEFAULT)))

		EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
		SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
							P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], 
							P.LongString, 
							P.[Guid]  
		FROM dbo.CatalogContentProperty P
		INNER JOIN MetaField F ON P.MetaFieldId = F.MetaFieldId
		WHERE ObjectId = @ObjectId AND
				ObjectTypeId = @ObjectTypeId AND
				MetaClassId = @MetaClassId AND
				((F.MultiLanguageValue = 1 AND LanguageName = @Language COLLATE DATABASE_DEFAULT) OR ((F.MultiLanguageValue = 0 AND LanguageName = @FallbackLanguage COLLATE DATABASE_DEFAULT)))
		END

	-- Select CatalogContentEx data
	EXEC CatalogContentEx_Load @ObjectId, @ObjectTypeId
END
GO
PRINT N'Altering [dbo].[CatalogContentProperty_LoadBatch]...';


GO
ALTER PROCEDURE [dbo].[CatalogContentProperty_LoadBatch]
	@PropertyReferences [udttCatalogContentPropertyReference] READONLY
AS
BEGIN
	
	IF dbo.mdpfn_sys_IsAzureCompatible() = 0  --Fields will be encrypted only when DB does not support Azure
		BEGIN
		EXEC mdpsp_sys_OpenSymmetricKey
		
		;WITH CTE1 AS (
			SELECT R.*, E.CatalogId
			FROM @PropertyReferences R
			INNER JOIN CatalogEntry E ON E.CatalogEntryId = R.ObjectId AND R.ObjectTypeId = 0
		UNION ALL
			SELECT R.*, N.CatalogId
			FROM @PropertyReferences R
			INNER JOIN CatalogNode N ON N.CatalogNodeId = R.ObjectId AND R.ObjectTypeId = 1
		),
		CTE2 AS (
			SELECT CTE1.ObjectId, CTE1.ObjectTypeId, CTE1.MetaClassId, ISNULL(L.LanguageCode, C.DefaultLanguage) AS LanguageName, C.DefaultLanguage
			FROM CTE1
			INNER JOIN [Catalog] C ON C.CatalogId = CTE1.CatalogId
			LEFT OUTER JOIN CatalogLanguage L ON L.CatalogId = CTE1.CatalogId AND L.LanguageCode = CTE1.LanguageName
		)
		-- Select CatalogContentProperty data
		SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
							P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], 
							CASE WHEN (F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1) 
								THEN dbo.mdpfn_sys_EncryptDecryptString(P.LongString, 0) 
								ELSE P.LongString END 
							AS LongString,
							P.[Guid]  
		FROM dbo.CatalogContentProperty P
		INNER JOIN MetaField F ON P.MetaFieldId = F.MetaFieldId
		INNER JOIN CTE2 ON
			P.ObjectId = CTE2.ObjectId AND
			P.ObjectTypeId = CTE2.ObjectTypeId AND
			P.MetaClassId = CTE2.MetaClassId AND
			((F.MultiLanguageValue = 1 AND P.LanguageName = CTE2.LanguageName COLLATE DATABASE_DEFAULT) OR ((F.MultiLanguageValue = 0 AND P.LanguageName = CTE2.DefaultLanguage COLLATE DATABASE_DEFAULT)))

		EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
		
		;WITH CTE1 AS (
			SELECT R.*, E.CatalogId
			FROM @PropertyReferences R
			INNER JOIN CatalogEntry E ON E.CatalogEntryId = R.ObjectId AND R.ObjectTypeId = 0
		UNION ALL
			SELECT R.*, N.CatalogId
			FROM @PropertyReferences R
			INNER JOIN CatalogNode N ON N.CatalogNodeId = R.ObjectId AND R.ObjectTypeId = 1
		),
		CTE2 AS (
			SELECT CTE1.ObjectId, CTE1.ObjectTypeId, CTE1.MetaClassId, ISNULL(L.LanguageCode, C.DefaultLanguage) AS LanguageName, C.DefaultLanguage
			FROM CTE1
			INNER JOIN [Catalog] C ON C.CatalogId = CTE1.CatalogId
			LEFT OUTER JOIN CatalogLanguage L ON L.CatalogId = CTE1.CatalogId AND L.LanguageCode = CTE1.LanguageName
		)	
		SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
							P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], P.LongString LongString,
							P.[Guid]  
		FROM dbo.CatalogContentProperty P
		INNER JOIN MetaField F ON P.MetaFieldId = F.MetaFieldId
		INNER JOIN CTE2 ON
			P.ObjectId = CTE2.ObjectId AND
			P.ObjectTypeId = CTE2.ObjectTypeId AND
			P.MetaClassId = CTE2.MetaClassId AND
			((F.MultiLanguageValue = 1 AND P.LanguageName = CTE2.LanguageName COLLATE DATABASE_DEFAULT) OR ((F.MultiLanguageValue = 0 AND P.LanguageName = CTE2.DefaultLanguage COLLATE DATABASE_DEFAULT)))
		END

	-- Select CatalogContentEx data
	SELECT *
	FROM dbo.CatalogContentEx Ex 
	INNER JOIN @PropertyReferences R ON Ex.ObjectId = R.ObjectId AND Ex.ObjectTypeId = R.ObjectTypeId
END
GO
PRINT N'Altering [dbo].[ecf_CatalogEntrySearch]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntrySearch]
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
		set @FilterQuery_tmp = @FilterQuery_tmp + N' INNER JOIN NodeEntryRelation NodeEntryRelation ON CatalogEntry.CatalogEntryId = NodeEntryRelation.CatalogEntryId '
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

	if(Len(@CatalogNodes) != 0)
	begin
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND'
		-- Different filter if more than one category is specified
		if ((select count(Item) from ecf_splitlist(@CatalogNodes)) > 1)
		begin 
			set @FilterQuery_tmp = @FilterQuery_tmp + N' CatalogEntry.CatalogEntryId in (select NodeEntryRelation.CatalogEntryId from NodeEntryRelation NodeEntryRelation where '
		end
		set @FilterQuery_tmp = @FilterQuery_tmp + N' NodeEntryRelation.CatalogNodeId IN (select CatalogNode.CatalogNodeId from CatalogNode CatalogNode'
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
PRINT N'Altering [dbo].[ecf_CatalogEntrySearch_Init]...';


GO
ALTER procedure [dbo].[ecf_CatalogEntrySearch_Init]
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

	set @ModifiedCondition = 'select ObjectId from CatalogContentEx where ObjectTypeId = 0'
    
    -- @ModifiedFilter: if there is a filter, build the where clause for it here.
    if (@EarliestModifiedDate is not null)
    begin
	  	set @EarliestModifiedFilter = ' Modified >= cast(''' + CONVERT(nvarchar(100), @EarliestModifiedDate, 127) + ''' as datetime)'
	  	set @ModifiedCondition = @ModifiedCondition + ' and ' + @EarliestModifiedFilter
	end
    if (@LatestModifiedDate is not null)
    begin
    	set @LatestModifiedFilter = ' Modified <= cast('''  + CONVERT(nvarchar(100), @LatestModifiedDate, 127) + ''' as datetime)'
	 	set @ModifiedCondition = @ModifiedCondition + ' and ' + @LatestModifiedFilter
	end

    -- find all the catalog entries that have modified relations in NodeEntryRelation, or deleted relations in ApplicationLog
    if (@EarliestModifiedDate is not null and @LatestModifiedDate is not null)
    begin

		set @EarliestModifiedFilter = ' Modified >= cast(''' + CONVERT(nvarchar(100), @EarliestModifiedDate, 127) + ''' as datetime)'
		set @LatestModifiedFilter = ' Modified <= cast('''  + CONVERT(nvarchar(100), @LatestModifiedDate, 127) + ''' as datetime)'
		
		declare @EarliestModifiedFilterPadded nvarchar(4000) =  @EarliestModifiedFilter
		declare @LatestModifiedFilterPadded nvarchar(4000) = @LatestModifiedFilter

        -- adjust modified date filters to account for clock difference between database server and application server clocks    
        if (isnull(@DatabaseClockOffsetMS, 0) > 0)
        begin
            set @EarliestModifiedFilterPadded = ' Modified >= cast(''' + CONVERT(nvarchar(100), DATEADD(MS, -@DatabaseClockOffsetMS, @EarliestModifiedDate), 127) + ''' as datetime)'
			set @LatestModifiedFilterPadded = ' Modified <= cast('''  + CONVERT(nvarchar(100), DATEADD(MS, -@DatabaseClockOffsetMS, @LatestModifiedDate), 127) + ''' as datetime)'
		end

		-- applying the NodeEntryRelation.
		set @ModifiedCondition = @ModifiedCondition + ' union select CatalogEntryId from NodeEntryRelation where ' + @EarliestModifiedFilterPadded + ' and ' + @LatestModifiedFilterPadded
	
		set @EarliestModifiedFilter = REPLACE( @EarliestModifiedFilter, 'Modified', 'Created')
		set @LatestModifiedFilter = REPLACE( @LatestModifiedFilter, 'Modified', 'Created')
			
		set @AppLogQuery = ' union select cast(ObjectKey as int) as CatalogEntryId from ApplicationLog where [Source] = ''catalog'' and [Operation] = ''Modified'' and [ObjectType] = ''relation'' and ' + @EarliestModifiedFilter + ' and ' + @LatestModifiedFilter

		-- applying the ApplicationLog.
		set @ModifiedCondition = @ModifiedCondition + @AppLogQuery
    end

    set @query = 'insert into CatalogEntrySearchResults_SingleSort (SearchSetId, ResultIndex, CatalogEntryId, ApplicationId) ' +
    'select distinct ''' + cast(@SearchSetId as nvarchar(36)) + ''', ROW_NUMBER() over (order by e.CatalogEntryId), e.CatalogEntryId, e.ApplicationId from CatalogEntry e ' +
    ' inner join (' + @ModifiedCondition + ') o on e.CatalogEntryId = o.ObjectId' + 
	' where e.ApplicationId = ''' + cast(@ApplicationId as nvarchar(36)) + ''' ' +
    ' and e.CatalogId = ' + cast(@CatalogId as nvarchar) + ' ' 	 
      
    if @IncludeInactive = 0 set @query = @query + ' and e.IsActive = 1'

    execute dbo.sp_executesql @query
    
    select @@ROWCOUNT
end
GO
PRINT N'Altering [dbo].[ecf_SerializableCart_FindCarts]...';


GO
ALTER PROCEDURE [dbo].[ecf_SerializableCart_FindCarts]
	@CartId INT = NULL,
	@CustomerId UNIQUEIDENTIFIER = NULL,
	@Name NVARCHAR (128) = NULL,
    @MarketId NVARCHAR (16) = NULL,
	@CreatedFrom DateTime = NULL,
	@CreatedTo DateTime = NULL,
	@ModifiedFrom DateTime = NULL,
	@ModifiedTo DateTime = NULL,
	@StartingRecord INT = NULL,
	@RecordsToRetrieve INT = NULL
AS
BEGIN
	WITH Paging AS 
	(
		SELECT CartId, Created, Modified, [Data], 
			   ROW_NUMBER() OVER (ORDER BY CartId DESC) AS RowNum
		FROM SerializableCart
		WHERE (@CartId IS NULL OR CartId = @CartId)
			AND (@CustomerId IS NULL OR CustomerId = @CustomerId)
			AND (@Name IS NULL OR Name = @Name)
            AND (@MarketId IS NULL OR MarketId = @MarketId)
			AND (@CreatedFrom IS NULL OR Created >= @CreatedFrom)
			AND (@CreatedTo IS NULL OR Created <= @CreatedTo)
			AND (@ModifiedFrom IS NULL OR Modified >= @ModifiedFrom)
			AND (@ModifiedTo IS NULL OR Modified <= @ModifiedTo)
	)
	SELECT CartId, Created, Modified, [Data]
	FROM 
		Paging
	WHERE
		RowNum BETWEEN @StartingRecord AND @StartingRecord + @RecordsToRetrieve	
END
GO
PRINT N'Creating [dbo].[ecf_Index_Automatic_Rebuild]...';


GO
CREATE PROCEDURE [dbo].[ecf_Index_Automatic_Rebuild]
	@DatabaseName NVARCHAR(255),
	@LowFragmentationThreshold INT,
	@HighFragmentationThreshold INT
AS
BEGIN
	DECLARE @sql NVARCHAR(1000)
	DECLARE @indexName NVARCHAR(255)
	DECLARE @tableName NVARCHAR(255)
	DECLARE @fragmentation FLOAT
	DECLARE @msg NVARCHAR(512)
	DECLARE @dbId INT
	DECLARE @indexCount INT

	SET NOCOUNT ON

	SET @dbId = db_id(@DatabaseName)
	IF @dbId IS NULL
	BEGIN
		SET @msg = N'The database ' + @DatabaseName + ' does not exist!'
		RAISERROR (@msg, 0, 1) WITH NOWAIT
		RETURN;
	END

	SET @indexCount = 0

	DECLARE c CURSOR FOR 
	SELECT 'ALTER INDEX [' + i.name + '] ON ' + object_name(d.object_id) + CASE WHEN avg_fragmentation_in_percent > @HighFragmentationThreshold THEN ' REBUILD' ELSE ' REORGANIZE' END AS [sql],
			convert(decimal(5, 2), avg_fragmentation_in_percent) fragmentation, object_name(d.object_id), i.name
	FROM sys.dm_db_index_physical_stats(@dbId, NULL, -1, NULL, 'SAMPLED') d  -- or 'DETAILED'
	INNER JOIN sys.indexes i ON i.object_id = d.object_id AND i.index_id = d.index_id
	WHERE d.avg_fragmentation_in_percent > @LowFragmentationThreshold
	ORDER BY avg_fragmentation_in_percent DESC

	SELECT N'See "Messages" tab for progress!' AS Info
	RAISERROR (N'Reading index fragmentation..', 0, 1) WITH NOWAIT
	RAISERROR (N'   ', 0, 1) WITH NOWAIT

	OPEN c

	FETCH NEXT FROM c INTO @sql, @fragmentation, @tableName, @indexName

	WHILE @@FETCH_STATUS = 0 
	BEGIN
		SET @msg = N'Found fragmented index..'
		RAISERROR (@msg, 0, 1) WITH NOWAIT
		SET @msg = N'    Name:          ' + @indexName
		RAISERROR (@msg, 0, 1) WITH NOWAIT
		SET @msg = N'    Table:         ' + @tableName
		RAISERROR (@msg, 0, 1) WITH NOWAIT
		SET @msg = N'    Fragmentation: ' + cast(@fragmentation AS NVARCHAR) + '%s'
		RAISERROR (@msg, 0, 1, '%') WITH NOWAIT

		EXEC sp_executesql @sql
		SET @indexCount = @indexCount + 1

		SET @msg = N'    Defrag done!'
		RAISERROR (@msg, 0, 1) WITH NOWAIT
		SET @msg = N'    '
		RAISERROR (@msg, 0, 1) WITH NOWAIT

		FETCH NEXT FROM c INTO @sql, @fragmentation, @tableName, @indexName
	END

	CLOSE c
	DEALLOCATE c

	SET @msg = N'--------------------------------'
	RAISERROR (@msg, 0, 1) WITH NOWAIT
	SET @msg = N'Found and defragged ' + cast(@indexCount AS NVARCHAR) + N' index(es)'
	RAISERROR (@msg, 0, 1) WITH NOWAIT
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
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 8, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
