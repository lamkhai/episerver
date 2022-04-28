--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 0, @patch int = 5    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
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

	-- 1. Cycle through all the available product meta classes
	print 'Iterating through meta classes'
	DECLARE MetaClassCursor CURSOR READ_ONLY
	FOR SELECT TableName FROM MetaClass 
		WHERE Namespace like @Namespace + '%' AND ([Name] in (select Item from ecf_splitlist(@Classes)) or @Classes = '')
		and IsSystem = 0

	OPEN MetaClassCursor
	FETCH NEXT FROM MetaClassCursor INTO @TableName_tmp
	WHILE (@@fetch_status = 0)
	BEGIN 
		print 'Metaclass Table: ' + @TableName_tmp
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

	DECLARE @additionalColumns nvarchar(max)
	SET @additionalColumns = ' OrderGroupId '

	if(Len(@OrderBy) = 0)
	begin
		set @OrderBy = ' OrderGroupId DESC'
	end
	else
	begin
		-- We need to include the additional columns to the query, so we can sort by it 
		-- Remove the descending/ascending keywords
		SET @additionalColumns = REPLACE ( @OrderBy, 'DESC', '')
		SET @additionalColumns = REPLACE ( @additionalColumns, 'ASC', '')
		-- This is for backward compatiblility, as customers might include [OrderGroup]. or OrderGroup. in @OrderBy
		SET @additionalColumns = REPLACE ( @additionalColumns, '[OrderGroup].', '')
		SET @additionalColumns = REPLACE ( @additionalColumns, 'OrderGroup.', '')
		-- If @OrderBy does not contain OrderGroupId, we are going to include it
		if(CHARINDEX('OrderGroupId', @additionalColumns) = 0)
		begin
			SET @additionalColumns = ' OrderGroupId ,' + @additionalColumns
		end
	end
	print @additionalColumns
	set @FullQuery = N'SELECT ' + @additionalColumns + 
		' FROM dbo.OrderGroup OrderGroup ' + @FromQuery_tmp + @FilterQuery_tmp 

	-- use temp table variable
	set @FullQuery = N'with OrderedResults as (' + @FullQuery +')
	INSERT INTO @Page_temp (TotalRecords, OrderGroupId)
	SELECT TotalRows, OrderGroupId FROM
	(SELECT ' +  @additionalColumns + ', 
		tCountOrders.CountOrders AS TotalRows'
		 +  + '

	FROM OrderedResults
		CROSS JOIN (SELECT Count(*) AS CountOrders FROM OrderedResults) AS tCountOrders 
		ORDER BY ' + @OrderBy +
		' OFFSET '  + cast(@StartingRec as nvarchar(50)) + '  ROWS 
		FETCH NEXT ' + cast(@NumRecords as nvarchar(50)) + ' ROWS ONLY) temp';

	set @FullQuery = 'declare @Page_temp table (TotalRecords int, OrderGroupId int);' + @FullQuery + ';select @RecordCount = TotalRecords from @Page_temp;SELECT OrderGroupId from @Page_temp;'
	print @FullQuery
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

    SET @query = 'SELECT WorkId, ObjectId, ObjectTypeId, Name, LanguageName, MasterLanguageName, IsCommonDraft, StartPublish, ModifiedBy, Modified, [Status]
        FROM dbo.ecfVersion vn  '
 
    -- Build WHERE clause, only add the condition if specified
    DECLARE @Where NVARCHAR(1000) = ' [dbo].ecf_IsCurrentLanguageRemoved(vn.CatalogId, vn.LanguageName) = 0 '
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

    SET @query = @query + ' WHERE ' + @Where

    DECLARE @filter NVARCHAR(2000)
    IF (@StartIndex = 0 AND @MaxRows = 2147483646)
    BEGIN
        -- We don't need to order and filter rows if we are loading all.
        SET @filter = @query
    END
    ELSE
    BEGIN
        -- Use CTE for paging and count the total rows
        SET @filter = ';WITH FilteredVersions as ( ' + @query + ' ) ' +
        ' SELECT WorkId, ObjectId, ObjectTypeId, Name, LanguageName, MasterLanguageName, IsCommonDraft, StartPublish, ModifiedBy, Modified, [Status], TotalRows
        FROM  FilteredVersions CROSS JOIN (SELECT Count(WorkId) AS TotalRows FROM FilteredVersions) AS t
        ORDER BY  Modified DESC
        OFFSET '  + CAST(@StartIndex AS NVARCHAR(50)) + '  ROWS 
        FETCH NEXT ' + CAST(@MaxRows AS NVARCHAR(50)) + ' ROWS ONLY';
    END

    EXEC sp_executesql @filter,
    N'@ObjectId int, @ObjectTypeId int, @ModifiedBy nvarchar(255), @Statuses [udttIdTable] READONLY, @Languages [udttLanguageCode] READONLY',
    @ObjectId = @ObjectId, @ObjectTypeId = @ObjectTypeId, @ModifiedBy = @ModifiedBy, @Statuses = @Statuses, @Languages = @Languages
     
END
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
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 0, 5, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
