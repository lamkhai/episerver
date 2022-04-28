--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 0, @patch int = 4    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Dropping [dbo].[FK_ecfVersionAsset_ecfVersion]...';


GO
ALTER TABLE [dbo].[ecfVersionAsset] DROP CONSTRAINT [FK_ecfVersionAsset_ecfVersion];


GO
PRINT N'Dropping [dbo].[PK_ecfVersionAsset]...';


GO
ALTER TABLE [dbo].[ecfVersionAsset] DROP CONSTRAINT [PK_ecfVersionAsset];


GO
PRINT N'Starting rebuilding table [dbo].[ecfVersionAsset]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_ecfVersionAsset] (
    [pkId]      BIGINT         IDENTITY (1, 1) NOT NULL,
    [WorkId]    INT            NOT NULL,
    [AssetType] NVARCHAR (190) NOT NULL,
    [AssetKey]  NVARCHAR (254) NOT NULL,
    [GroupName] NVARCHAR (100) NULL,
    [SortOrder] INT            NOT NULL,
    CONSTRAINT [tmp_ms_xx_constraint_PK_ecfVersionAsset] PRIMARY KEY CLUSTERED ([WorkId] ASC, [AssetType] ASC, [AssetKey] ASC)
);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[ecfVersionAsset])
    BEGIN
        SET IDENTITY_INSERT [dbo].[tmp_ms_xx_ecfVersionAsset] ON;
        INSERT INTO [dbo].[tmp_ms_xx_ecfVersionAsset] ([WorkId], [AssetType], [AssetKey], [pkId], [GroupName], [SortOrder])
        SELECT   [WorkId],
                 [AssetType],
                 [AssetKey],
                 [pkId],
                 [GroupName],
                 [SortOrder]
        FROM     [dbo].[ecfVersionAsset]
        ORDER BY [WorkId] ASC, [AssetType] ASC, [AssetKey] ASC;
        SET IDENTITY_INSERT [dbo].[tmp_ms_xx_ecfVersionAsset] OFF;
    END

DROP TABLE [dbo].[ecfVersionAsset];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_ecfVersionAsset]', N'ecfVersionAsset';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_ecfVersionAsset]', N'PK_ecfVersionAsset', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Creating [dbo].[ecfVersionAsset].[IDX_ecfVersionAsset_WorkId]...';


GO
CREATE NONCLUSTERED INDEX [IDX_ecfVersionAsset_WorkId]
    ON [dbo].[ecfVersionAsset]([WorkId] ASC);


GO
PRINT N'Creating [dbo].[FK_ecfVersionAsset_ecfVersion]...';


GO
ALTER TABLE [dbo].[ecfVersionAsset] WITH NOCHECK
    ADD CONSTRAINT [FK_ecfVersionAsset_ecfVersion] FOREIGN KEY ([WorkId]) REFERENCES [dbo].[ecfVersion] ([WorkId]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Altering [dbo].[ecf_GenerateReportingDates]...';


GO
ALTER PROCEDURE ecf_GenerateReportingDates
@EndDate DATE
AS
BEGIN
	DECLARE @StartDate DATE
	SET @StartDate = (SELECT MAX(DateFull) FROM [dbo].[ReportingDates])

	--If there is no reporting date yet, make sure to add the current date.
	IF (@StartDate IS NULL)
		SET @StartDate = GETDATE()
	ELSE
	--We will add the start date as the day after the max date in ReportingDates
		SET @StartDate = DATEADD(day, 1, @StartDate)

	IF (@EndDate > @StartDate)
	BEGIN
		CREATE TABLE #ReportingDates (ReportingDate Datetime2);
		WITH ReportingDates_CTE(Date) AS		
		( 
			SELECT @StartDate 
			UNION ALL
			SELECT DateAdd(day,1,ReportingDates_CTE.Date) FROM ReportingDates_CTE WHERE ReportingDates_CTE.Date <= @EndDate
		)
		
		INSERT INTO #ReportingDates
		SELECT * FROM ReportingDates_CTE OPTION (MAXRECURSION 32767);


		INSERT INTO [dbo].[ReportingDates] 
		(DateKey, DateFull, CharacterDate, FullYear, QuarterNumber, WeekNumber, WeekDayName, MonthDay, MonthName, YearDay, 
		DateDefinition, WeekDay, MonthNumber)

		SELECT cast (REPLACE(convert(varchar, ReportingDate, 102), '.', '') as int), 
				 ReportingDate,
				 convert(varchar, ReportingDate, 101),
				 YEAR(ReportingDate),
				 MONTH(ReportingDate) / 3,
				 DATEPART(wk, ReportingDate),
				 DATENAME(dw, ReportingDate),
				 DAY(ReportingDate),
				 DATENAME(month, ReportingDate),
				 DATEPART(dy, ReportingDate),
				 DATENAME(month, ReportingDate) + CAST(DAY(ReportingDate) AS varchar) + ',   
		           ' + CAST(YEAR(ReportingDate) AS varchar),
				 DATEPART(dw, ReportingDate),
				 MONTH(ReportingDate)
				 FROM #ReportingDates

		DROP TABLE #ReportingDates
	END
END
GO
PRINT N'Altering [dbo].[ecf_Shipment_Get]...';


GO
ALTER PROCEDURE [dbo].[ecf_Shipment_Get]
(
	@SqlWhereClause				nvarchar(max),
	@OrderByClause 				nvarchar(max),
	@StartingRec				int,
	@NumRecords					int,
	@RecordCount				int OUTPUT
)
AS
BEGIN
	Declare @FullQuery nvarchar(max)

	if (LEN(@OrderByClause) = 0)
	begin
		set @OrderByClause = ' [Shipment].ShipmentId DESC '
	end

	SET @FullQuery = N'SELECT ShipmentId, OrderGroupId, COUNT(ShipmentId) OVER() TotalRecords, ROW_NUMBER() OVER(ORDER BY ' + @OrderByClause + N') RowNumber
	FROM dbo.Shipment'

	if (LEN(@SqlWhereClause) > 0)
	begin
		set @FullQuery = @FullQuery + N' WHERE ' + @SqlWhereClause
	end

	SET @FullQuery = N'WITH SearchedResults AS (' + @FullQuery +') 
	INSERT INTO @Page_temp
	SELECT TOP(' + CAST(@NumRecords AS NVARCHAR(50)) + ')
		ShipmentId, OrderGroupId, TotalRecords 
	FROM SearchedResults
	WHERE RowNumber > ' + CAST(@StartingRec AS NVARCHAR(50)) + ' '

	SET @FullQuery = N'DECLARE @Page_temp table (ShipmentId int, OrderGroupId int, TotalRecords int);
	' + @FullQuery + ';
	SELECT @RecordCount = TotalRecords FROM @Page_temp;
	SELECT ShipmentId, OrderGroupId FROM @Page_temp'

	EXEC sp_executesql @FullQuery, N'@RecordCount int output', @RecordCount = @RecordCount OUTPUT

END
GO
PRINT N'Altering [dbo].[ecfVersionAsset_Save]...';


GO
ALTER PROCEDURE [dbo].[ecfVersionAsset_Save]
	@WorkIds dbo.[udttObjectWorkId] readonly,
	@ContentDraftAsset dbo.[udttCatalogContentAsset] readonly
AS
BEGIN
	DELETE A
	FROM ecfVersionAsset A
	INNER JOIN @WorkIds W on W.WorkId = A.WorkId

	INSERT INTO ecfVersionAsset 
	SELECT * FROM @ContentDraftAsset
END
GO
PRINT N'Refreshing [dbo].[ecfVersion_SyncEntryData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncEntryData]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_SyncNodeData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncNodeData]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_Update]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_Update]';


GO
PRINT N'Refreshing [dbo].[ecfVersionAsset_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersionAsset_ListByWorkIds]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByWorkIds]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 0, 4, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
