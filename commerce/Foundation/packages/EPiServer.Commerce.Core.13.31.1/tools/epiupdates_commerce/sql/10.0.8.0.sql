--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 8    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[fn_JoinCatalogLanguages]...';


GO
ALTER FUNCTION [dbo].[fn_JoinCatalogLanguages]
(
    @catalogId int
)
RETURNS nvarchar(4000)
AS
BEGIN
    DECLARE @RetVal nvarchar(4000)
    SELECT @RetVal = COALESCE(@RetVal + ';', '') + LanguageCode FROM CatalogLanguage cl
	INNER JOIN [Catalog] c ON cl.CatalogId = c.CatalogId
	WHERE cl.CatalogId = @catalogId

    RETURN @RetVal;
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
			SELECT CTE1.ObjectId, CTE1.ObjectTypeId, CTE1.MetaClassId, CTE1.LanguageName, C.DefaultLanguage
			FROM CTE1
			INNER JOIN [Catalog] C ON C.CatalogId = CTE1.CatalogId
			INNER JOIN CatalogLanguage L ON L.CatalogId = CTE1.CatalogId AND L.LanguageCode = CTE1.LanguageName
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
			((P.CultureSpecific = 1 AND P.LanguageName = CTE2.LanguageName COLLATE DATABASE_DEFAULT) OR ((P.CultureSpecific = 0 AND P.LanguageName = CTE2.DefaultLanguage COLLATE DATABASE_DEFAULT)))

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
			SELECT CTE1.ObjectId, CTE1.ObjectTypeId, CTE1.MetaClassId, CTE1.LanguageName, C.DefaultLanguage
			FROM CTE1
			INNER JOIN [Catalog] C ON C.CatalogId = CTE1.CatalogId
			INNER JOIN CatalogLanguage L ON L.CatalogId = CTE1.CatalogId AND L.LanguageCode = CTE1.LanguageName
		)	
		SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
							P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], P.LongString LongString,
							P.[Guid]  
		FROM dbo.CatalogContentProperty P
		INNER JOIN CTE2 ON
			P.ObjectId = CTE2.ObjectId AND
			P.ObjectTypeId = CTE2.ObjectTypeId AND
			P.MetaClassId = CTE2.MetaClassId AND
			((P.CultureSpecific = 1 AND P.LanguageName = CTE2.LanguageName COLLATE DATABASE_DEFAULT) OR ((P.CultureSpecific = 0 AND P.LanguageName = CTE2.DefaultLanguage COLLATE DATABASE_DEFAULT)))
		END

	-- Select CatalogContentEx data
	SELECT *
	FROM dbo.CatalogContentEx Ex 
	INNER JOIN @PropertyReferences R ON Ex.ObjectId = R.ObjectId AND Ex.ObjectTypeId = R.ObjectTypeId
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
	@ExcludeName NVARCHAR (1024) = NULL,
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
	SET @query = @query + ' AND Name NOT IN (' + @ExcludeName + ') '
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
PRINT N'Refreshing [dbo].[ecfVersion_SyncCatalogData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncCatalogData]';


GO
PRINT N'Refreshing [dbo].[ecfVersionCatalog_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersionCatalog_ListByWorkIds]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByWorkIds]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 8, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
