--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 9, @minor int = 0, @patch int = 3    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Dropping [dbo].[SerializableCart].[IDX_SerializableCart_Indexed_MarketId]...';


GO
DROP INDEX [IDX_SerializableCart_Indexed_MarketId]
    ON [dbo].[SerializableCart];


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
	@TotalRecords INT OUTPUT
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
	IF (@CartId IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND CartId = @CartId '
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
	' ORDER BY  CartId DESC
        OFFSET '  + CAST(@StartingRecord AS NVARCHAR(50)) + '  ROWS 
        FETCH NEXT ' + CAST(@RecordsToRetrieve AS NVARCHAR(50)) + ' ROWS ONLY'

	exec sp_executesql @query, 
	N'@CartId INT,
	@CustomerId UNIQUEIDENTIFIER,
	@Name nvarchar(128),
    @MarketId nvarchar(16),
	@CreatedFrom DateTime,
	@CreatedTo DateTime,
	@ModifiedFrom DateTime,
	@ModifiedTo DateTime,
	@StartingRecord INT,
	@RecordsToRetrieve INT',
	@CartId = @CartId, @CustomerId= @CustomerId, @Name=@Name, @MarketId = @MarketId,
	@CreatedFrom = @CreatedFrom, @CreatedTo=@CreatedTo, @ModifiedFrom=@ModifiedFrom, @ModifiedTo=@ModifiedTo, 
	@StartingRecord = @StartingRecord, @RecordsToRetrieve =@RecordsToRetrieve

	-- Execute for record count
	exec sp_executesql @CountQuery, 
	N'@CartId INT,
	@CustomerId UNIQUEIDENTIFIER,
	@Name nvarchar(128),
    @MarketId nvarchar(16),
	@CreatedFrom DateTime,
	@CreatedTo DateTime,
	@ModifiedFrom DateTime,
	@ModifiedTo DateTime,
	@TotalRecords INT OUTPUT',
	@CartId = @CartId, @CustomerId= @CustomerId, @Name=@Name, @MarketId = @MarketId,
	@CreatedFrom = @CreatedFrom, @CreatedTo=@CreatedTo, @ModifiedFrom=@ModifiedFrom, @ModifiedTo=@ModifiedTo,
	@TotalRecords = @TotalRecords OUTPUT
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(9, 0, 3, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
