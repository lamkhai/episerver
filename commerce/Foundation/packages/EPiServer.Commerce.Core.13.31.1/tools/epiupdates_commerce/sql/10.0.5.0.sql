--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 5    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 


GO
PRINT N'Creating [dbo].[fn_AreSiblings]...';


GO
CREATE FUNCTION [dbo].[fn_AreSiblings]
(
    @entryId1 int,
    @entryId2 int
)
RETURNS bit
AS
BEGIN
    DECLARE @RetVal bit
	IF EXISTS(
		SELECT R.CatalogNodeId
		FROM NodeEntryRelation R WHERE R.CatalogEntryId = @entryId1

		INTERSECT

		SELECT R.CatalogNodeId
		FROM NodeEntryRelation R WHERE R.CatalogEntryId = @entryId2
		)

		BEGIN
			SET @RetVal = 1
		END
	ELSE
		BEGIN
			SET @RetVal = 0
		END

    RETURN @RetVal;
END
GO
PRINT N'Altering [dbo].[ecf_CatalogEntryItemSeo_ValidateUriSegment]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUriSegment]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly,
	@UseLessStrictUriSegmentValidation bit
AS
BEGIN
	DECLARE @query nvarchar(4000);

	-- validate Entry Uri Segment and return invalid record
	SET @query =
	'SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], t.[Uri], NULL AS [UriSegment]
	FROM @CatalogItemSeo t
	INNER JOIN CatalogItemSeo c ON
		t.LanguageCode = c.LanguageCode COLLATE DATABASE_DEFAULT
		AND t.CatalogEntryId <> c.CatalogEntryId -- check against entry only
		AND t.UriSegment = c.UriSegment COLLATE DATABASE_DEFAULT'

	IF (@UseLessStrictUriSegmentValidation = 1)
	BEGIN
		SET @query = @query + '
		WHERE dbo.fn_UriSegmentExistsOnSiblingNodeOrEntry(t.CatalogEntryId, 1, t.UriSegment, t.LanguageCode) = 1

		UNION 

		SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], t.[Uri], NULL AS [UriSegment]
		FROM @CatalogItemSeo t
		INNER JOIN @CatalogItemSeo s ON 
			t.LanguageCode = s.LanguageCode COLLATE DATABASE_DEFAULT
			AND t.CatalogEntryId <> s.CatalogEntryId -- check against entry only
			AND t.UriSegment = s.UriSegment COLLATE DATABASE_DEFAULT
			AND dbo.fn_AreSiblings(t.CatalogEntryId, s.CatalogEntryId) =  1'
	END

	exec sp_executesql @query, N'@CatalogItemSeo dbo.udttCatalogItemSeo readonly', @CatalogItemSeo = @CatalogItemSeo
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
PRINT N'Altering [dbo].[ecf_Search_PaymentPlan]...';


GO
ALTER PROCEDURE [dbo].[ecf_Search_PaymentPlan]
	@SQLClause 					nvarchar(max),
	@MetaSQLClause 				nvarchar(max),
    @OrderBy 					nvarchar(max),
	@Namespace					nvarchar(1024) = N'',
	@Classes					nvarchar(max) = N'',
    @StartingRec 				int,
	@NumRecords   				int,
	@RecordCount                int OUTPUT,
	@ReturnTotalCount	        bit = 1
AS
BEGIN
    declare @results udttOrderGroupId
    insert into @results (OrderGroupId)    
    exec dbo.ecf_OrderSearch
        @SQLClause, 
        @MetaSQLClause, 
        @OrderBy, 
        @Namespace, 
        @Classes, 
        @StartingRec, 
        @NumRecords, 
        @RecordCount output,
        @ReturnTotalCount
    
    exec dbo.ecf_Search_OrderGroup @results

    -- Return Purchase Order Details
	DECLARE @search_condition nvarchar(max)
	CREATE TABLE #OrderSearchResults (OrderGroupId int)
	insert into #OrderSearchResults select OrderGroupId from @results
	if(Len(@OrderBy) = 0)
	begin
		set @OrderBy = 'OrderGroupId DESC'
	end
	SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults) ORDER BY ' + @OrderBy
	exec mdpsp_avto_OrderGroup_PaymentPlan_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition

	DROP TABLE #OrderSearchResults
END
GO
PRINT N'Altering [dbo].[ecf_Search_PurchaseOrder]...';


GO
ALTER PROCEDURE [dbo].[ecf_Search_PurchaseOrder]
	@SQLClause 					nvarchar(max),
	@MetaSQLClause 				nvarchar(max),
    @OrderBy 					nvarchar(max),
	@Namespace					nvarchar(1024) = N'',
	@Classes					nvarchar(max) = N'',
    @StartingRec 				int,
	@NumRecords   				int,
	@RecordCount                int OUTPUT,
	@ReturnTotalCount	        bit = 1
AS
BEGIN
    declare @results udttOrderGroupId
    insert into @results (OrderGroupId)    
    exec dbo.ecf_OrderSearch
        @SQLClause, 
        @MetaSQLClause, 
        @OrderBy, 
        @Namespace, 
        @Classes, 
        @StartingRec, 
        @NumRecords, 
        @RecordCount output,
        @ReturnTotalCount
	
	exec [dbo].[ecf_Search_OrderGroup] @results

    -- Return Purchase Order Details
	DECLARE @search_condition nvarchar(max)
	CREATE TABLE #OrderSearchResults (OrderGroupId int)
	insert into #OrderSearchResults select OrderGroupId from @results
	if(Len(@OrderBy) = 0)
	begin
		set @OrderBy = 'OrderGroupId DESC'
	end
	SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults) ORDER BY ' + @OrderBy
	exec mdpsp_avto_OrderGroup_PurchaseOrder_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition

	DROP TABLE #OrderSearchResults
END
GO
PRINT N'Altering [dbo].[ecf_Search_ShoppingCart]...';


GO
ALTER PROCEDURE [dbo].[ecf_Search_ShoppingCart]
	@SQLClause 					nvarchar(max),
	@MetaSQLClause 				nvarchar(max),
    @OrderBy 					nvarchar(max),
	@Namespace					nvarchar(1024) = N'',
	@Classes					nvarchar(max) = N'',
    @StartingRec 				int,
	@NumRecords   				int,
	@RecordCount                int OUTPUT,
	@ReturnTotalCount	        bit = 1
AS
BEGIN
    declare @results udttOrderGroupId
    insert into @results (OrderGroupId)    
    exec dbo.ecf_OrderSearch
        @SQLClause, 
        @MetaSQLClause, 
        @OrderBy, 
        @Namespace, 
        @Classes, 
        @StartingRec, 
        @NumRecords, 
        @RecordCount output,
        @ReturnTotalCount
    
    exec dbo.ecf_Search_OrderGroup @results
    
	IF(EXISTS(SELECT OrderGroupId from OrderGroup where OrderGroupId IN (SELECT [OrderGroupId] FROM @results)))
	begin
	    -- Return Purchase Order Details
		DECLARE @search_condition nvarchar(max)
		CREATE TABLE #OrderSearchResults (OrderGroupId int)
		insert into #OrderSearchResults (OrderGroupId) select OrderGroupId from @results
		if(Len(@OrderBy) = 0)
		begin
			set @OrderBy = 'OrderGroupId DESC'
		end
		SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults) ORDER BY ' + @OrderBy
		exec mdpsp_avto_OrderGroup_ShoppingCart_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition

		DROP TABLE #OrderSearchResults
	end
END

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
	@RecordsToRetrieve INT = NULL,
	@TotalRecords INT OUTPUT,
	@ExcludeName NVARCHAR (128) = NULL,
	@ReturnTotalCount BIT
AS
BEGIN
	DECLARE @CountQuery nvarchar(4000);
	DECLARE @query nvarchar(4000);
	SET @query = 'SELECT CartId, Created, Modified, [Data] FROM SerializableCart WHERE 1 = 1 '

	IF (@CartId IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND CartId = @CartId '
	END
	IF (@CustomerId IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND CustomerId = @CustomerId '
	END
	IF (@Name IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND Name = @Name '
	END
	IF (@ExcludeName IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND Name <> @ExcludeName '
	END
	IF (@MarketId IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND MarketId = @MarketId '
	END
	IF (@CreatedFrom IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND Created >= @CreatedFrom '
	END
	IF (@CreatedTo IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND Created <= @CreatedTo '
	END
	IF (@ModifiedFrom IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND Modified >= @ModifiedFrom '
	END
	IF (@ModifiedTo IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND Modified <= @ModifiedTo '
	END

	SET @CountQuery = N'SET @TotalRecords = (Select COUNT(1) FROM (' + @query + ') AS CountTable)'

	SET @query = @query +
	' ORDER BY Modified DESC
        OFFSET '  + CAST(@StartingRecord AS NVARCHAR(50)) + '  ROWS 
        FETCH NEXT ' + CAST(@RecordsToRetrieve AS NVARCHAR(50)) + ' ROWS ONLY'

	exec sp_executesql @query, 
	N'@CartId INT,
	@CustomerId UNIQUEIDENTIFIER,
	@Name nvarchar(128),
	@ExcludeName nvarchar(128),
    @MarketId nvarchar(16),
	@CreatedFrom DateTime,
	@CreatedTo DateTime,
	@ModifiedFrom DateTime,
	@ModifiedTo DateTime,
	@StartingRecord INT,
	@RecordsToRetrieve INT',
	@CartId = @CartId, @CustomerId= @CustomerId, @Name=@Name, @ExcludeName = @ExcludeName, @MarketId = @MarketId,
	@CreatedFrom = @CreatedFrom, @CreatedTo=@CreatedTo, @ModifiedFrom=@ModifiedFrom, @ModifiedTo=@ModifiedTo, 
	@StartingRecord = @StartingRecord, @RecordsToRetrieve =@RecordsToRetrieve

	-- Execute for record count
	IF (@ReturnTotalCount = 1)
	BEGIN
		exec sp_executesql @CountQuery,
		N'@CartId INT,
		@CustomerId UNIQUEIDENTIFIER,
		@Name nvarchar(128),
		@ExcludeName nvarchar(128),
	    @MarketId nvarchar(16),
		@CreatedFrom DateTime,
		@CreatedTo DateTime,
		@ModifiedFrom DateTime,
		@ModifiedTo DateTime,
		@TotalRecords INT OUTPUT',
		@CartId = @CartId, @CustomerId= @CustomerId, @Name=@Name, @ExcludeName = @ExcludeName, @MarketId = @MarketId,
		@CreatedFrom = @CreatedFrom, @CreatedTo=@CreatedTo, @ModifiedFrom=@ModifiedFrom, @ModifiedTo=@ModifiedTo,
		@TotalRecords = @TotalRecords OUTPUT
	END
	ELSE 
	BEGIN
		SET @TotalRecords = 0
	END
END
GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment]';

 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 5, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
