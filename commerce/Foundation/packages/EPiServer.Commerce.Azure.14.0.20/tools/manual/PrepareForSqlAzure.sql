-- Remove full text index search
DECLARE @table_index sysname,
		@exec_index_string nvarchar (4000);
DECLARE indexes_cursor CURSOR FOR
    SELECT OBJECT_SCHEMA_NAME(object_id) + N'.' + OBJECT_NAME(object_id) FROM sys.fulltext_indexes

OPEN indexes_cursor
FETCH NEXT FROM indexes_cursor INTO @table_index
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @exec_index_string = N'DROP FULLTEXT INDEX ON ' + @table_index
    EXECUTE sp_executesql @exec_index_string
    FETCH NEXT FROM indexes_cursor INTO @table_index
END
CLOSE indexes_cursor
DEALLOCATE indexes_cursor
GO

-- Remove full text queries catalog
DECLARE @catalog_fulltext nvarchar(400),
		@exec_catalog_string nvarchar (4000);
DECLARE catalog_cursor CURSOR FOR SELECT name FROM sys.fulltext_catalogs
OPEN catalog_cursor
FETCH NEXT FROM catalog_cursor INTO @catalog_fulltext
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @exec_catalog_string = N'DROP FULLTEXT CATALOG [' + @catalog_fulltext + N']'
    EXECUTE sp_executesql @exec_catalog_string
	FETCH NEXT FROM catalog_cursor INTO @catalog_fulltext
END
CLOSE catalog_cursor
DEALLOCATE catalog_cursor
GO

-- Remove FillFactor option in all tables
DECLARE
	@constraint_name NVARCHAR(400),
	@is_unique bit,
	@type_desc NVARCHAR(100),
	@allow_page_locks bit,
	@table_name NVARCHAR(400);
DECLARE list SCROLL CURSOR FOR
	SELECT i.name, i.is_unique, i.type_desc, i.allow_page_locks, OBJECT_NAME(i.object_id)
	FROM sys.indexes i 
	WHERE i.fill_factor != 0
	ORDER BY i.name

OPEN list
FETCH list INTO @constraint_name, @is_unique, @type_desc, @allow_page_locks, @table_name
WHILE @@FETCH_STATUS = 0
BEGIN
	DECLARE @query NVARCHAR(4000),
			@parameter_string NVARCHAR(400),
			@column_name NVARCHAR(400),
			@columns_name_string NVARCHAR(400);

	-- Get columns name
	DECLARE columnsName CURSOR FORWARD_ONLY FOR
		SELECT c.name FROM sys.columns c
			INNER JOIN sys.index_columns ic on ic.column_id = c.column_id and ic.object_id = c.object_id
			INNER JOIN sys.indexes i on i.object_id = ic.object_id and i.index_id = ic.index_id
		WHERE i.name = @constraint_name and OBJECT_NAME(i.object_id) = @table_name
	SET @columns_name_string = N''
	OPEN columnsName
	FETCH columnsName into @column_name
	while (@@FETCH_STATUS = 0)
	BEGIN
		SET @columns_name_string = @columns_name_string + N'[' + @column_name + N'] ,'
		FETCH columnsName into @column_name
	END
	CLOSE columnsName
	DEALLOCATE columnsName
	
	-- Remove last comma in columns name string
	IF (RIGHT(@columns_name_string, 1) = N',')
		SET @columns_name_string = LEFT(@columns_name_string, LEN(@columns_name_string) - 1)
	IF (LEN(@columns_name_string) > 0)
		SET @columns_name_string = N'(' + @columns_name_string + N')'
		
	SET @parameter_string = N' WITH (DROP_EXISTING = ON, '
	-- If not check allow page locks, the index will be default by ON
	IF (@allow_page_locks = 1)
		SET @parameter_string = @parameter_string + N'ALLOW_PAGE_LOCKS = ON'
	ELSE
		SET @parameter_string = @parameter_string + N'ALLOW_PAGE_LOCKS = OFF'
		
	SET @parameter_string = @parameter_string + N') ON [PRIMARY]'
	
	IF (@is_unique = 1)
		SET @type_desc = N'UNIQUE ' + @type_desc
		
	SET @query = N'CREATE ' + @type_desc + N' INDEX [' + @constraint_name + N'] ON [dbo].[' + @table_name + N']' 
		+ @columns_name_string + @parameter_string
	
	EXECUTE sp_executesql @query
	FETCH list INTO @constraint_name, @is_unique, @type_desc, @allow_page_locks, @table_name
END
CLOSE list
DEALLOCATE list
GO

-- Add clustered to tables which have no indexes
-- Need to check existed clustered index here to avoid others upgrade sql files can drop and recreate tables without clustered index
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Affiliate') AND NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('[Affiliate]') AND type_desc = 'CLUSTERED')
	CREATE CLUSTERED INDEX IX_Affiliate_AffiliateId ON [dbo].[Affiliate] ([AffiliateId]);
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'AzureCompatible') AND NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('[AzureCompatible]') AND type_desc = 'CLUSTERED')
	CREATE CLUSTERED INDEX IX_AzureCompatible_AzureCompatible ON [dbo].[AzureCompatible] ([AzureCompatible]);
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'CatalogEntrySearchResults') AND NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('[CatalogEntrySearchResults]') AND type_desc = 'CLUSTERED')
	CREATE CLUSTERED INDEX IX_CatalogEntrySearchResults_SearchSetId ON [dbo].[CatalogEntrySearchResults] ([SearchSetId]);
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'CatalogLanguageMap') AND NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('[CatalogLanguageMap]') AND type_desc = 'CLUSTERED')
	CREATE CLUSTERED INDEX IX_CatalogLanguageMap_Language ON [dbo].[CatalogLanguageMap] ([Language]);
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'CatalogNodeSearchResults') AND NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('[CatalogNodeSearchResults]') AND type_desc = 'CLUSTERED')
	CREATE CLUSTERED INDEX IX_CatalogNodeSearchResults_SearchSetId ON [dbo].[CatalogNodeSearchResults] ([SearchSetId]);
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'CatalogSecurity') AND NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('[CatalogSecurity]') AND type_desc = 'CLUSTERED')
	CREATE CLUSTERED INDEX IX_CatalogSecurity_CatalogId ON [dbo].[CatalogSecurity] ([CatalogId]);
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'McBlobStorage') AND NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('[McBlobStorage]') AND type_desc = 'CLUSTERED')
	CREATE CLUSTERED INDEX IX_McBlobStorage_McBlobStorage ON [dbo].[McBlobStorage] ([uid]);
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') AND NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('[SchemaVersion]') AND type_desc = 'CLUSTERED')
	CREATE CLUSTERED INDEX IX_SchemaVersion_Major ON [dbo].[SchemaVersion] ([Major]);
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SiteCatalog') AND NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('[SiteCatalog]') AND type_desc = 'CLUSTERED')
	CREATE CLUSTERED INDEX IX_SiteCatalog_CatalogId ON [dbo].[SiteCatalog] ([CatalogId]);
GO
