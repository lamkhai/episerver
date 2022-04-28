--beginvalidatingquery
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion')
	BEGIN
	declare @major int = 6, @minor int = 10, @patch int = 3
	IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch)
		select 0,'Already correct database version' 
	ELSE
		select 1, 'Upgrading database'
	END
ELSE
	select -1, 'Not an EPiServer Commerce database'
GO
--endvalidatingquery

-- create ecf_Shipment_Get sp
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Shipment_Get]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Shipment_Get]
GO
CREATE PROCEDURE [dbo].[ecf_Shipment_Get]
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
-- end of creating ecf_Shipment_Get sp


--beginUpdatingDatabaseVersion
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 10, 3, GETUTCDATE())
GO
--endUpdatingDatabaseVersion
