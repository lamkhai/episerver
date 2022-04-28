--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 10, @patch int = 2    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

-- create SP ecf_OrderSearch
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_OrderSearch]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_OrderSearch] 
GO
CREATE PROCEDURE [dbo].[ecf_OrderSearch]
(
	@ApplicationId				uniqueidentifier,
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
		set @Query_tmp = 'select 100 as ''Rank'', META.ObjectId as ''Key'', * from ' + @TableName_tmp + ' META'
		
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
	SET @FromQuery_tmp = N'FROM [OrderGroup] OrderGroup' + N' INNER JOIN (select distinct U.[Key], U.Rank from (' + @SelectMetaQuery_tmp + N') U) META ON OrderGroup.[OrderGroupId] = META.[Key] '

	set @FilterQuery_tmp = N' WHERE ApplicationId = ''' + CAST(@ApplicationId as nvarchar(36)) + ''''
	-- add sql clause statement here, if specified
	if(Len(@SQLClause) != 0)
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND (' + @SqlClause + ')'

    if(Len(@OrderBy) = 0)
    begin
		set @OrderBy = '[OrderGroup].OrderGroupId DESC'
    end
	set @FullQuery = N'SELECT count([OrderGroup].OrderGroupId) OVER() TotalRecords, [OrderGroup].OrderGroupId, Rank, ROW_NUMBER() OVER(ORDER BY ' + @OrderBy + N') RowNumber ' + @FromQuery_tmp + @FilterQuery_tmp

	-- use temp table variable
	set @FullQuery = N'with OrderedResults as (' + @FullQuery +') INSERT INTO @Page_temp (TotalRecords, OrderGroupId) SELECT top(' + cast(@NumRecords as nvarchar(50)) + ') TotalRecords, OrderGroupId FROM OrderedResults WHERE RowNumber > ' + cast(@StartingRec as nvarchar(50)) + ';'
	set @FullQuery = 'declare @Page_temp table (TotalRecords int, OrderGroupId int);' + @FullQuery + ';select @RecordCount = TotalRecords from @Page_temp;SELECT OrderGroupId from @Page_temp;'
	--print @FullQuery
	exec sp_executesql @FullQuery, N'@RecordCount int output', @RecordCount = @RecordCount OUTPUT

	SET NOCOUNT OFF
END
GO
-- end of creating SP ecf_OrderSearch
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 10, 2, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
