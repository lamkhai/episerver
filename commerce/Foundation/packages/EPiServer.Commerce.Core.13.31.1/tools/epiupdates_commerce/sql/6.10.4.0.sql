--beginvalidatingquery
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion')
	BEGIN
	declare @major int = 6, @minor int = 10, @patch int = 4
	IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch)
		select 0,'Already correct database version' 
	ELSE
		select 1, 'Upgrading database'
	END
ELSE
	select -1, 'Not an EPiServer Commerce database'
GO
--endvalidatingquery

ALTER FUNCTION [dbo].[fn_UriSegmentExistsOnSiblingNodeOrEntry]
(
    @entityId int,
    @type bit, -- 0 = Node, 1 = Entry
    @UriSegment nvarchar(255),
    @ApplicationId uniqueidentifier,
    @LanguageCode nvarchar(50)
)
RETURNS bit
AS
BEGIN
    DECLARE @RetVal bit
    DECLARE @Count int
    DECLARE @parentId int
    
    -- get the parentId, based on entityId and the entity type
    IF @type = 0 
        SET @parentId = (SELECT ParentNodeId FROM CatalogNode WHERE CatalogNodeId = @entityId)
    ELSE
        SET @parentId = (SELECT CatalogNodeId FROM NodeEntryRelation WHERE CatalogEntryId = @entityId)

    SET @RetVal = 0

    -- check if the UriSegment exists on sibling node
    SET @Count = (
                    SELECT COUNT(S.CatalogNodeId)
                    FROM CatalogItemSeo S WITH (NOLOCK) 
                    INNER JOIN CatalogNode N on N.CatalogNodeId = S.CatalogNodeId AND N.ApplicationId = S.ApplicationId 
                    LEFT JOIN CatalogNodeRelation NR ON N.CatalogNodeId = NR.ChildNodeId 
                    WHERE S.ApplicationId = @ApplicationId 
                        AND LanguageCode = @LanguageCode COLLATE DATABASE_DEFAULT 
                        AND S.CatalogNodeId <> @entityId
                        AND (N.ParentNodeId = @parentId OR NR.ParentNodeId = @parentId)
                        AND UriSegment = @UriSegment COLLATE DATABASE_DEFAULT 
                        AND N.IsActive = 1
                )
                
    IF @Count = 0 -- check against sibling entry if only UriSegment does not exist on sibling node
    BEGIN
        -- check if the UriSegment exists on sibling entry
        SET @Count = (
                        SELECT COUNT(S.CatalogEntryId)
                        FROM CatalogItemSeo S WITH (NOLOCK)
                        INNER JOIN CatalogEntry N ON N.CatalogEntryId = S.CatalogEntryId AND N.ApplicationId = S.ApplicationId 
                        LEFT JOIN NodeEntryRelation R ON R.CatalogEntryId = N.CatalogEntryId
                        WHERE 
                            S.ApplicationId = @ApplicationId 
                            AND S.LanguageCode = @LanguageCode COLLATE DATABASE_DEFAULT 
                            AND S.CatalogEntryId <> @entityId 
                            AND R.CatalogNodeId = @parentId  
                            AND UriSegment = @UriSegment COLLATE DATABASE_DEFAULT 
                            AND N.IsActive = 1
                    )
    END

    IF @Count <> 0
    BEGIN
        SET @RetVal = 1
    END

    RETURN @RetVal;
END
GO
-- create increase ShippingAddressId column to match OrderAddress.Name
ALTER TABLE [Shipment] ALTER COLUMN [ShippingAddressId] NVARCHAR (64) NULL
-- end increase ShippingAddressId column to match OrderAddress.Name

--beginUpdatingDatabaseVersion
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 10, 4, GETUTCDATE())
GO
--endUpdatingDatabaseVersion