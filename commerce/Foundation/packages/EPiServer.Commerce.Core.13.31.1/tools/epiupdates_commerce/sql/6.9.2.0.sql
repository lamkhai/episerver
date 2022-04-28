--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 9, @patch int = 2    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

ALTER PROCEDURE [dbo].[ecf_ShippingMethod_GetCases]
	@ShippingMethodId uniqueidentifier,
	@CountryCode nvarchar(50) = null,
	@Total money = null,
	@StateProvinceCode nvarchar(50) = null,
	@ZipPostalCode nvarchar(50) = null,
	@District nvarchar(50) = null,
	@County nvarchar(50) = null,
	@City nvarchar(50) = null
AS
BEGIN
/* First set all empty string variables except ShippingMethodId to NULL */
IF (LTRIM(RTRIM(@CountryCode)) = '')
  SET @CountryCode = NULL

IF (LTRIM(RTRIM(@StateProvinceCode)) = '')
  SET @StateProvinceCode = NULL

IF (LTRIM(RTRIM(@ZipPostalCode)) = '')
  SET @ZipPostalCode = NULL

IF (LTRIM(RTRIM(@District)) = '')
  SET @District = NULL

IF (LTRIM(RTRIM(@County)) = '')
  SET @County = NULL

IF (LTRIM(RTRIM(@City )) = '')
  SET @City = NULL

/* If Jurisdiction values in database are null or an empty string, they will return the same results */
	SELECT C.Charge, C.Total, C.StartDate, C.EndDate, C.JurisdictionGroupId from ShippingMethodCase C 
		inner join JurisdictionGroup JG ON JG.JurisdictionGroupId = C.JurisdictionGroupId
		inner join JurisdictionRelation JR ON JG.JurisdictionGroupId = JR.JurisdictionGroupId
		inner join Jurisdiction J ON JR.JurisdictionId = J.JurisdictionId
	WHERE 
		(C.StartDate < getutcdate() OR C.StartDate is null) AND 
		(C.EndDate > getutcdate() OR C.EndDate is null) AND 
		C.ShippingMethodId = @ShippingMethodId AND
		(@Total >= C.Total OR @Total is null) AND
		(J.CountryCode = @CountryCode OR (@CountryCode is null and J.CountryCode = 'WORLD')) AND 
		JG.JurisdictionType = 2 /*shipping*/ AND
		(COALESCE(@StateProvinceCode, J.StateProvinceCode) = J.StateProvinceCode OR J.StateProvinceCode is null OR RTRIM(LTRIM(J.StateProvinceCode)) = '') AND
		((REPLACE(@ZipPostalCode,' ','') between REPLACE(J.ZipPostalCodeStart,' ','') and REPLACE(J.ZipPostalCodeEnd,' ','') or @ZipPostalCode is null) OR J.ZipPostalCodeStart is null OR RTRIM(LTRIM(J.ZipPostalCodeStart)) = '') AND
		(COALESCE(@District, J.District) = J.District OR J.District is null OR RTRIM(LTRIM(J.District)) = '') AND
		(COALESCE(@County, J.County) = J.County OR J.County is null OR RTRIM(LTRIM(J.County)) = '') AND
		(COALESCE(@City, J.City) = J.City OR J.City is null OR RTRIM(LTRIM(J.City)) = '')
END
GO
 
ALTER PROCEDURE [dbo].[ecf_OrderSearch]
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

	set @FullQuery = N'SELECT count([OrderGroup].OrderGroupId) OVER() TotalRecords, [OrderGroup].OrderGroupId, Rank, ROW_NUMBER() OVER(ORDER BY [OrderGroup].OrderGroupId) RowNumber ' + @FromQuery_tmp + @FilterQuery_tmp

	-- use temp table variable
	set @FullQuery = N'with OrderedResults as (' + @FullQuery +') INSERT INTO @Page_temp (TotalRecords, OrderGroupId) SELECT top(' + cast(@NumRecords as nvarchar(50)) + ') TotalRecords, OrderGroupId FROM OrderedResults WHERE RowNumber > ' + cast(@StartingRec as nvarchar(50)) + ';'
	set @FullQuery = 'declare @Page_temp table (TotalRecords int, OrderGroupId int);' + @FullQuery + ';select @RecordCount = TotalRecords from @Page_temp;SELECT OrderGroupId from @Page_temp;'
	--print @FullQuery
	exec sp_executesql @FullQuery, N'@RecordCount int output', @RecordCount = @RecordCount OUTPUT

	SET NOCOUNT OFF
END
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 9, 2, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
