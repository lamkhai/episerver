--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 6, @patch int = 4    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Creating [dbo].[udttCatalogContentPropertyReference]...';


GO
CREATE TYPE [dbo].[udttCatalogContentPropertyReference] AS TABLE (
    [ObjectId]     INT           NOT NULL,
    [ObjectTypeId] INT           NOT NULL,
    [MetaClassId]  INT           NOT NULL,
    [LanguageName] NVARCHAR (20) NOT NULL,
    PRIMARY KEY CLUSTERED ([ObjectId] ASC, [ObjectTypeId] ASC));


GO
PRINT N'Creating [dbo].[SerializableCart]...';


GO
CREATE TABLE [dbo].[SerializableCart] (
    [CartId]     INT              IDENTITY (1, 1) NOT NULL,
    [CustomerId] UNIQUEIDENTIFIER NOT NULL,
    [Name]       NVARCHAR (128)   NULL,
    [Created]    DATETIME         NOT NULL,
    [Modified]   DATETIME         NULL,
    [Data]       NVARCHAR (MAX)   NULL,
    CONSTRAINT [PK_SerializableCart] PRIMARY KEY CLUSTERED ([CartId] ASC)
);


GO
PRINT N'Creating [dbo].[SerializableCart].[IDX_SerializableCart_Indexed_CustomerId_Name]...';


GO
CREATE NONCLUSTERED INDEX [IDX_SerializableCart_Indexed_CustomerId_Name]
    ON [dbo].[SerializableCart]([CustomerId] ASC, [Name] ASC);


GO
PRINT N'Altering [dbo].[CatalogContentProperty_SaveBatch]...';


GO

ALTER PROCEDURE [dbo].[CatalogContentProperty_SaveBatch]
	@ContentProperty dbo.udttCatalogContentProperty readonly
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
PRINT N'Altering [dbo].[ecf_ApplicationLog]...';


GO
ALTER PROCEDURE [dbo].[ecf_ApplicationLog]
	@IsSystemLog bit = 0,
	@Source nvarchar(100) = null,
	@Created datetime = null,
	@Operation nvarchar(50) = null,
	@ObjectType nvarchar(50) = null,
    @StartingRec int,
	@NumRecords int
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @SystemLogKey nvarchar(100)
	SET @SystemLogKey = 'system'; 

	WITH OrderedLogs AS 
	(
		select *, row_number() over(order by LogId desc) as RowNumber from ApplicationLog 
			where ((@IsSystemLog = 1 AND Source = @SystemLogKey) OR (@IsSystemLog = 0 AND NOT Source = @SystemLogKey))
				AND COALESCE(@Source, Source) = Source 
				AND COALESCE(@Operation, Operation) = Operation 
				AND COALESCE(@ObjectType, ObjectType) = ObjectType 
				AND COALESCE(@Created, Created) >= Created
	),
	OrderedLogsCount(TotalCount) as
	(
		select count(LogId) from OrderedLogs
	)
	select LogId, Source, Operation, ObjectKey, ObjectType, Username, Created, Succeeded, IPAddress, Notes, ApplicationId, TotalCount from OrderedLogs, OrderedLogsCount
	where RowNumber between @StartingRec and @StartingRec + @NumRecords
	SET NOCOUNT OFF;
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
PRINT N'Altering [dbo].[ecf_CatalogLog]...';


GO
ALTER PROCEDURE ecf_CatalogLog
	@Created datetime = null,
	@Operation nvarchar(50) = null,
	@ObjectType nvarchar(50) = null,
    @StartingRec int,
	@NumRecords int
AS
BEGIN
	SET NOCOUNT ON;
	WITH OrderedLogs AS 
	(
		select *, row_number() over(order by LogId) as RowNumber from CatalogLog where COALESCE(@Operation, Operation) = Operation and COALESCE(@ObjectType, ObjectType) = ObjectType and COALESCE(@Created, Created) <= Created
	),
	OrderedLogsCount(TotalCount) as
	(
		select count(LogId) from OrderedLogs
	)
	select LogId, Operation, ObjectKey, ObjectType, Username, Created, Succeeded, Notes, ApplicationId, TotalCount from OrderedLogs, OrderedLogsCount
	where RowNumber between @StartingRec and @StartingRec+@NumRecords-1
	SET NOCOUNT OFF;
END
GO
PRINT N'Altering [dbo].[ecf_CatalogNodeSearch]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogNodeSearch]
(
	@ApplicationId			uniqueidentifier,
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
	set @FilterQuery_tmp =  N' WHERE CatalogNode.ApplicationId = ''' + cast(@ApplicationId as nvarchar(100)) + ''' AND ((1=1'
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
PRINT N'Altering [dbo].[ecf_mktg_PromotionUsageStatistics]...';


GO
ALTER PROCEDURE [dbo].[ecf_mktg_PromotionUsageStatistics]
	@CustomerId uniqueidentifier = null
AS
BEGIN
	if(@CustomerId is null)
	begin 
		select count(*) TotalUsed, PromotionId from PromotionUsage
		where ([Status] != 0 AND [Status] != 3) and CustomerId = COALESCE(@CustomerId,CustomerId)
		group by promotionid
	end
	else
	begin 
		select count(*) TotalUsed, PromotionId from PromotionUsage
		where ([Status] != 0 AND [Status] != 3) and CustomerId = @CustomerId
		group by promotionid, customerid
	end
END
GO
PRINT N'Altering [dbo].[ecf_reporting_SaleReport]...';


GO
SET QUOTED_IDENTIFIER ON;

SET ANSI_NULLS OFF;


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
		, O.Subtotal
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
SET ANSI_NULLS, QUOTED_IDENTIFIER ON;


GO
PRINT N'Altering [dbo].[ecf_Search_CatalogEntry]...';


GO
ALTER procedure dbo.ecf_Search_CatalogEntry
	@SearchSetId uniqueidentifier,
	@ResponseGroup INT = NULL
as
begin
    declare @entries dbo.udttEntityList
    insert into @entries (EntityId, SortOrder)
    select r.CatalogEntryId, r.SortOrder
    from CatalogEntrySearchResults r
    where r.SearchSetId = @SearchSetId
    
	exec dbo.ecf_CatalogEntry_List @entries, @ResponseGroup

	delete CatalogEntrySearchResults
	where SearchSetId = @SearchSetId
end
GO
PRINT N'Altering [dbo].[ecf_ShippingOption_ShippingOptionId]...';


GO
ALTER PROCEDURE [dbo].[ecf_ShippingOption_ShippingOptionId]
	@ApplicationId uniqueidentifier,
	@ShippingOptionId uniqueidentifier
AS
BEGIN
	select * from [ShippingOption] 
		where [ShippingOptionId] = @ShippingOptionId and [ApplicationId]=@ApplicationId
	select SOP.* from [ShippingOptionParameter] SOP 
	inner join [ShippingOption] SO on SO.[ShippingOptionId]=SOP.[ShippingOptionId]
		where SO.[ShippingOptionId] = @ShippingOptionId and SO.[ApplicationId]=@ApplicationId
	select * from [Package] P
		inner join [ShippingPackage] SP on P.[PackageId]=SP.[PackageId]
			where SP.[ShippingOptionId] = @ShippingOptionId and P.[ApplicationId]=@ApplicationId
	select * from [ShippingPackage] where [ShippingOptionId] = @ShippingOptionId
END
GO
PRINT N'Altering [dbo].[ecfVersionProperty_SyncPublishedVersion]...';


GO
ALTER PROCEDURE [dbo].[ecfVersionProperty_SyncPublishedVersion]
	@ContentDraftProperty dbo.udttCatalogContentProperty READONLY,
	@LanguageName NVARCHAR(20)
AS
BEGIN
	DECLARE @propertyData udttCatalogContentProperty
	DECLARE @propertiesToSyncCount INT

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		--update encrypted field: support only LongString field
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO @propertyData (
			WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName,Boolean, Number,
			FloatNumber, [Money], [Decimal], [Date], [Binary], String,
			LongString,
			[Guid], [IsNull]) 
		SELECT
			ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, @LanguageName, cdp.Boolean, cdp.Number,
			cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
			CASE WHEN cdp.IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(cdp.LongString, 1) ELSE cdp.LongString END AS LongString, 
			cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd
		ON	ccd.ObjectId = cdp.ObjectId AND
			ccd.ObjectTypeId = cdp.ObjectTypeId AND
			ccd.LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 --Draft properties of published version will be sync
		
		SET @propertiesToSyncCount = @@ROWCOUNT

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO @propertyData (
			WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName,Boolean, Number,
			FloatNumber, [Money], [Decimal], [Date], [Binary], String, LongString,[Guid], [IsNull])
		SELECT
			ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, @LanguageName, cdp.Boolean, cdp.Number,
			cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, cdp.LongString, cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd
		ON	ccd.ObjectId = cdp.ObjectId AND
			ccd.ObjectTypeId = cdp.ObjectTypeId AND
			ccd.LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 --Draft properties of published version will be sync

		SET @propertiesToSyncCount = @@ROWCOUNT
	END

	IF @propertiesToSyncCount > 0
		BEGIN
			-- delete rows where values have been nulled out
			DELETE A 
				FROM [dbo].[ecfVersionProperty] A
				INNER JOIN @propertyData T
				ON	A.WorkId = T.WorkId AND 
					A.MetaFieldId = T.MetaFieldId AND
					T.[IsNull] = 1
		END
	ELSE
		BEGIN
			-- nothing to update
			RETURN
		END

	-- Now null rows are handled, so remove them to not insert empty rows
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
   WHEN	NOT  MATCHED BY TARGET
		-- insert new record if the record is does not exist in ecfVersionProperty table
		THEN 
			INSERT (
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.WorkId, I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

END
GO
PRINT N'Creating [dbo].[CatalogContentProperty_LoadBatch]...';


GO
CREATE PROCEDURE [dbo].[CatalogContentProperty_LoadBatch]
	@PropertyReferences [udttCatalogContentPropertyReference] READONLY
AS
BEGIN

	-- update encrypted field: support only LongString field
	-- Open and Close SymmetricKey do nothing if the system does not support encryption
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
						CASE WHEN (dbo.mdpfn_sys_IsAzureCompatible() = 0 AND F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1) 
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

	-- Select CatalogContentEx data
	SELECT *
	FROM dbo.CatalogContentEx Ex 
	INNER JOIN @PropertyReferences R ON Ex.ObjectId = R.ObjectId AND Ex.ObjectTypeId = R.ObjectTypeId
END
GO
PRINT N'Creating [dbo].[ecf_SerializableCart_Delete]...';


GO
CREATE PROCEDURE [dbo].[ecf_SerializableCart_Delete]
	@CartId INT
AS
BEGIN
	DELETE FROM SerializableCart WHERE CartId = @CartId
END
GO
PRINT N'Creating [dbo].[ecf_SerializableCart_FindCarts]...';


GO
CREATE PROCEDURE [dbo].[ecf_SerializableCart_FindCarts]
	@CartId INT = NULL,
	@CustomerId UNIQUEIDENTIFIER = NULL,
	@Name NVARCHAR (128) = NULL,
	@CreatedFrom DateTime = NULL,
	@CreatedTo DateTime = NULL,
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
			AND (@CreatedFrom IS NULL OR Created >= @CreatedFrom)
			AND (@CreatedTo IS NULL OR Created <= @CreatedTo)
	)
	SELECT CartId, Created, Modified, [Data]
	FROM 
		Paging
	WHERE
		RowNum BETWEEN @StartingRecord AND @StartingRecord + @RecordsToRetrieve	
END
GO
PRINT N'Creating [dbo].[ecf_SerializableCart_Load]...';


GO
CREATE PROCEDURE [dbo].[ecf_SerializableCart_Load]
	@CartId INT = NULL,
	@CustomerId UNIQUEIDENTIFIER = NULL,
	@Name NVARCHAR (128) = NULL,
	@MarketId NVARCHAR (16) = NULL
AS
BEGIN
	SELECT CartId, Created, Modified, [Data]
	FROM SerializableCart
	WHERE (@CartId IS NULL OR CartId = @CartId)
		AND (@CustomerId IS NULL OR CustomerId = @CustomerId)
		AND (@Name IS NULL OR Name = @Name)
END
GO
PRINT N'Creating [dbo].[ecf_SerializableCart_Save]...';


GO
CREATE PROCEDURE [dbo].[ecf_SerializableCart_Save]
	@CartId INT,
	@CustomerId UNIQUEIDENTIFIER,
	@Name NVARCHAR(128),
	@Created DATETIME,
	@Modified DATETIME,
	@Data NVARCHAR(MAX)
AS
BEGIN
	IF(@CartId <= 0)
	BEGIN
		INSERT INTO SerializableCart(CustomerId, Name, Created, Modified, [Data])
		VALUES (@CustomerId, @Name, @Created, @Modified, @Data)

		SET @CartId = SCOPE_IDENTITY();
	END
	ELSE
	BEGIN
		UPDATE SerializableCart
		SET 			
			CustomerId = @CustomerId,
			Name = @Name,
			Created = @Created,
			Modified = @Modified,
			[Data] = @Data
		WHERE CartId = @CartId
	END

	SELECT @CartId
END
GO
PRINT N'Altering [dbo].[CatalogContentProperty_Save]...';


GO
ALTER PROCEDURE [dbo].[CatalogContentProperty_Save]
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
		EXEC [ecfVersionProperty_SyncPublishedVersion] @ContentProperty, @LanguageName
	END

	-- Update CatalogContentEx table
	EXEC CatalogContentEx_Save @ContentExData
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 6, 4, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
