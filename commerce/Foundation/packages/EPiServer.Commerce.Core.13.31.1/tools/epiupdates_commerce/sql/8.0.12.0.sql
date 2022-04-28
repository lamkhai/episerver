--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 0, @patch int = 12    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[fn_UriSegmentExistsOnSiblingNodeOrEntry]...';


GO
ALTER FUNCTION [dbo].[fn_UriSegmentExistsOnSiblingNodeOrEntry]
(
    @entityId int,
    @type bit, -- 0 = Node, 1 = Entry
    @UriSegment nvarchar(255),
    @LanguageCode nvarchar(50)
)
RETURNS bit
AS
BEGIN
    DECLARE @RetVal bit
    DECLARE @parentId int
	DECLARE @CatalogId int
    
    -- get the parentId and CatalogId, based on entityId and the entity type
    IF @type = 0
	BEGIN
		SELECT @parentId = ParentNodeId, @CatalogId = CatalogId FROM CatalogNode WHERE CatalogNodeId = @entityId
	END
    ELSE
	BEGIN
        SET @parentId = (SELECT CatalogNodeId FROM NodeEntryRelation WHERE CatalogEntryId = @entityId)
		SET @CatalogId = (SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @entityId)
	END

    SET @RetVal = 0

               
    IF NOT EXISTS( SELECT S.CatalogNodeId
                    FROM CatalogItemSeo S WITH (NOLOCK) 
                    INNER JOIN CatalogNode N on N.CatalogNodeId = S.CatalogNodeId
                    LEFT JOIN CatalogNodeRelation NR ON N.CatalogNodeId = NR.ChildNodeId 
                    WHERE LanguageCode = @LanguageCode COLLATE DATABASE_DEFAULT 
                        AND S.CatalogNodeId <> @entityId
                        AND ((@parentId = 0 AND N.CatalogId = @CatalogId AND N.ParentNodeId = 0) OR (@parentId <> 0 AND (N.ParentNodeId = @parentId OR NR.ParentNodeId = @parentId)))
                        AND UriSegment = @UriSegment COLLATE DATABASE_DEFAULT 
                        AND N.IsActive = 1) 
    BEGIN
    	-- check against sibling entry if only UriSegment does not exist on sibling node	
		IF EXISTS(
					SELECT S.CatalogEntryId
					FROM CatalogItemSeo S WITH (NOLOCK)
					INNER JOIN CatalogEntry N ON N.CatalogEntryId = S.CatalogEntryId
					LEFT JOIN NodeEntryRelation R ON R.CatalogEntryId = N.CatalogEntryId
					WHERE 
						S.LanguageCode = @LanguageCode COLLATE DATABASE_DEFAULT 
						AND S.CatalogEntryId <> @entityId 
						AND R.CatalogNodeId = @parentId
						AND R.CatalogId = @CatalogId
						AND UriSegment = @UriSegment COLLATE DATABASE_DEFAULT 
						AND N.IsActive = 1
						)
		BEGIN
			SET @RetVal = 1
		END
	END
	ELSE
	BEGIN
		SET @RetVal = 1
	END

    RETURN @RetVal;
END
GO
PRINT N'Refreshing [dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 0, 12, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
