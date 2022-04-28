--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 22    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[ecf_CatalogEntryItemSeo_ValidateUri]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUri]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Entry Uri and return invalid record
	SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], '' AS [Uri], t.[UriSegment] 
	FROM @CatalogItemSeo t
	INNER JOIN CatalogItemSeo c ON
		LOWER(t.LanguageCode) = LOWER(c.LanguageCode) COLLATE DATABASE_DEFAULT
		AND t.Uri = c.Uri COLLATE DATABASE_DEFAULT
	-- check against both entry and node
	WHERE c.CatalogNodeId > 0 OR t.CatalogEntryId <> c.CatalogEntryId
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
		LOWER(t.LanguageCode) = LOWER(c.LanguageCode) COLLATE DATABASE_DEFAULT
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
			LOWER(t.LanguageCode) = LOWER(s.LanguageCode) COLLATE DATABASE_DEFAULT
			AND t.CatalogEntryId <> s.CatalogEntryId -- check against entry only
			AND t.UriSegment = s.UriSegment COLLATE DATABASE_DEFAULT
			AND dbo.fn_AreSiblings(t.CatalogEntryId, s.CatalogEntryId) =  1'
	END

	exec sp_executesql @query, N'@CatalogItemSeo dbo.udttCatalogItemSeo readonly', @CatalogItemSeo = @CatalogItemSeo
END
GO
PRINT N'Altering [dbo].[ecf_CatalogNodeItemSeo_ValidateUri]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUri]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Node Uri and return invalid record
	SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], '' AS [Uri], t.[UriSegment] 
	FROM @CatalogItemSeo t
	INNER JOIN CatalogItemSeo c ON
		LOWER(t.LanguageCode) = LOWER(c.LanguageCode) COLLATE DATABASE_DEFAULT
		AND t.Uri = c.Uri COLLATE DATABASE_DEFAULT
	-- check against both entry and node
	WHERE c.CatalogEntryId > 0 OR t.CatalogNodeId <> c.CatalogNodeId
END
GO
PRINT N'Altering [dbo].[ecf_SerializableCart_FindCartsByCustomerEmail]...';


GO
ALTER PROCEDURE [dbo].[ecf_SerializableCart_FindCartsByCustomerEmail]
	@CustomerEmail NVARCHAR (254),
    @StartingRecord INT,
	@RecordsToRetrieve INT,
	@ReturnTotalCount BIT,
	@ExcludeNames NVARCHAR (1024) = NULL,
	@TotalRecords INT OUTPUT
AS
BEGIN
	-- Execute for record count.
	IF (@ReturnTotalCount = 1)
	BEGIN
		SET @TotalRecords = (SELECT COUNT(1) FROM SerializableCart SC
							INNER JOIN cls_Contact CC ON SC.CustomerId = CC.ContactId
							WHERE CC.Email = @CustomerEmail
								  AND (@ExcludeNames IS NULL OR SC.[Name] NOT IN(SELECT Item FROM ecf_splitlist(@ExcludeNames))))
	END
	ELSE 
	BEGIN
		SET @TotalRecords = 0
	END

	-- Execute for get carts.
	SELECT SC.CartId, SC.Created, SC.Modified, SC.[Data]
	FROM SerializableCart SC
	INNER JOIN cls_Contact CC ON SC.CustomerId = CC.ContactId
	WHERE CC.Email = @CustomerEmail
		  AND (@ExcludeNames IS NULL OR SC.[Name] NOT IN(SELECT Item FROM ecf_splitlist(@ExcludeNames)))
	ORDER BY SC.Modified DESC
	OFFSET @StartingRecord ROWS
	FETCH NEXT @RecordsToRetrieve ROWS ONLY
END
GO
PRINT N'Altering [dbo].[ecf_SerializableCart_FindCartsByCustomerName]...';


GO
ALTER PROCEDURE [dbo].[ecf_SerializableCart_FindCartsByCustomerName]
	@CustomerName NVARCHAR (200),
    @StartingRecord INT,
	@RecordsToRetrieve INT,
	@ReturnTotalCount BIT,
	@ExcludeNames NVARCHAR (1024) = NULL,
	@TotalRecords INT OUTPUT
AS
BEGIN
	-- Execute for record count.
	IF (@ReturnTotalCount = 1)
	BEGIN
		SET @TotalRecords = (SELECT COUNT(1) FROM SerializableCart SC
							INNER JOIN cls_Contact CC ON SC.CustomerId = CC.ContactId
							WHERE CC.FullName LIKE @CustomerName + '%'
								  AND (@ExcludeNames IS NULL OR SC.[Name] NOT IN(SELECT Item FROM ecf_splitlist(@ExcludeNames))))
	END
	ELSE 
	BEGIN
		SET @TotalRecords = 0
	END

	-- Execute for get carts.
	SELECT SC.CartId, SC.Created, SC.Modified, SC.[Data]
	FROM SerializableCart SC
	INNER JOIN cls_Contact CC ON SC.CustomerId = CC.ContactId
	WHERE CC.FullName LIKE @CustomerName + '%'
		  AND (@ExcludeNames IS NULL OR SC.[Name] NOT IN(SELECT Item FROM ecf_splitlist(@ExcludeNames)))
	ORDER BY SC.Modified DESC
	OFFSET @StartingRecord ROWS
	FETCH NEXT @RecordsToRetrieve ROWS ONLY
END
GO
PRINT N'Refreshing [dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 22, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
