--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 4, @patch int = 1    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogNode_GetAllChildEntries]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogNode_GetAllChildEntries] 

GO 

create procedure ecf_CatalogNode_GetAllChildEntries
    @catalogNodeIds udttCatalogNodeList readonly
as
begin
    with all_node_relations as 
    (
        select ParentNodeId, CatalogNodeId as ChildNodeId from CatalogNode
        where ParentNodeId > 0
        union
        select ParentNodeId, ChildNodeId from CatalogNodeRelation
    ),
    hierarchy as
    (
        select 
            n.CatalogNodeId,
            '|' + CAST(n.CatalogNodeId as nvarchar(4000)) + '|' as CyclePrevention
        from @catalogNodeIds n
        union all
        select
            children.ChildNodeId as CatalogNodeId,
            parent.CyclePrevention + CAST(children.ChildNodeId as nvarchar(4000)) + '|' as CyclePrevention
        from hierarchy parent
        join all_node_relations children on parent.CatalogNodeId = children.ParentNodeId
        where CHARINDEX('|' + CAST(children.ChildNodeId as nvarchar(4000)) + '|', parent.CyclePrevention) = 0
    )
    select distinct ce.CatalogEntryId, ce.ApplicationId, ce.Code
    from CatalogEntry ce
    join NodeEntryRelation ner on ce.CatalogEntryId = ner.CatalogEntryId
    where ner.CatalogNodeId in (select CatalogNodeId from hierarchy)
end

GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 4, 1, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
