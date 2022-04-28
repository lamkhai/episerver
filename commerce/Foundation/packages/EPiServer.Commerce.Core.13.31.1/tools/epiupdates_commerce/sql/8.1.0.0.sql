--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 1, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

GO
 
;WITH CTE
AS (SELECT ROW_NUMBER() OVER (PARTITION BY CustomerId, Name, MarketId
ORDER BY Modified DESC ) RN
FROM SerializableCart)
DELETE FROM CTE WHERE RN > 1;
GO

PRINT N'Creating [dbo].[udttCatalogContentAccess]...';


GO
CREATE TYPE [dbo].[udttCatalogContentAccess] AS TABLE (
    [Name]       NVARCHAR (255) NOT NULL,
    [IsRole]     INT            DEFAULT 1 NOT NULL,
    [AccessMask] INT            NOT NULL);


GO
PRINT N'Creating [dbo].[CatalogContentAccess]...';


GO
CREATE TABLE [dbo].[CatalogContentAccess] (
    [ObjectId]     INT            NOT NULL,
    [ObjectTypeId] INT            NOT NULL,
    [Name]         NVARCHAR (255) NOT NULL,
    [IsRole]       INT            DEFAULT 1 NOT NULL,
    [AccessMask]   INT            NOT NULL,
    CONSTRAINT [PK_CatalogContentAccess] PRIMARY KEY CLUSTERED ([ObjectId] ASC, [ObjectTypeId] ASC, [Name] ASC) ON [PRIMARY]
);
GO
PRINT N'Creating [dbo].[CatalogContentAccess_DeleteByUserOrRole]...';


GO
CREATE PROCEDURE dbo.CatalogContentAccess_DeleteByUserOrRole
(
	@Name NVARCHAR(255),
	@IsRole INT
)
AS
BEGIN
	SET NOCOUNT ON
	
	DELETE FROM CatalogContentAccess WHERE Name = @Name AND IsRole = @IsRole
END
GO
PRINT N'Creating [dbo].[CatalogContentAccess_Load]...';


GO
CREATE PROCEDURE dbo.CatalogContentAccess_Load
(
	@Contents [dbo].[udttObjectWorkId] READONLY
)
AS
BEGIN
	SET NOCOUNT ON

	SELECT DISTINCT cca.*
	FROM CatalogContentAccess cca
	INNER JOIN @Contents content ON cca.ObjectId = content.ObjectId AND cca.ObjectTypeId = content.ObjectTypeId
	ORDER BY
		cca.ObjectTypeId,
		cca.IsRole DESC,
		cca.Name
END
GO
PRINT N'Creating [dbo].[CatalogContentAccess_Delete]...';


GO
CREATE PROCEDURE dbo.CatalogContentAccess_Delete
(
	@ObjectId INT,
	@ObjectTypeId INT,
	@Recursive BIT
)
AS
BEGIN
	SET NOCOUNT ON
	
	IF (@Recursive = 1)
    BEGIN
        /* Remove all old ACEs for catalog content and below */
		IF @ObjectTypeId = 2
		BEGIN
			DELETE FROM CatalogContentAccess
			WHERE ObjectId = @ObjectId AND ObjectTypeId = 2

			DELETE cca
			FROM CatalogContentAccess cca
			INNER JOIN CatalogNode node ON node.CatalogNodeId = cca.ObjectId AND node.CatalogId = @ObjectId
			WHERE cca.ObjectTypeId = 1
		END
		ELSE IF @ObjectTypeId = 1
		BEGIN
			DELETE FROM CatalogContentAccess
			WHERE ObjectId = @ObjectId AND ObjectTypeId = 1

			DELETE cca
			FROM CatalogContentAccess cca
			INNER JOIN CatalogNode node ON node.CatalogNodeId = cca.ObjectId AND node.ParentNodeId = @ObjectId
			WHERE cca.ObjectTypeId = 1
		END
    END
	ELSE
	BEGIN
		DELETE FROM CatalogContentAccess
		WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId
	END
END
GO
PRINT N'Creating [dbo].[CatalogContentAccess_Update]...';


GO
CREATE PROCEDURE dbo.CatalogContentAccess_Update
(
	@ObjectId INT,
	@ObjectTypeId INT,
	@AccessEntities dbo.[udttCatalogContentAccess] readonly
)
AS
BEGIN
	MERGE dbo.CatalogContentAccess AS TARGET
	USING @AccessEntities AS SOURCE
	ON (TARGET.ObjectId = @ObjectId AND TARGET.ObjectTypeId = @ObjectTypeId AND TARGET.Name = SOURCE.Name)
	WHEN MATCHED THEN 
		UPDATE SET IsRole = SOURCE.IsRole,
				   AccessMask = SOURCE.AccessMask
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (ObjectId, ObjectTypeId, Name, IsRole, AccessMask)
		VALUES (@ObjectId, @ObjectTypeId, SOURCE.Name, SOURCE.IsRole, SOURCE.AccessMask)
	WHEN NOT MATCHED BY SOURCE 
		AND TARGET.ObjectId = @ObjectId 
		AND TARGET.ObjectTypeId = @ObjectTypeId 
	THEN DELETE;
END
GO
PRINT N'Creating [dbo].[CatalogContentAccess_MergeChildPermissions]...';


GO
CREATE PROCEDURE dbo.CatalogContentAccess_MergeChildPermissions
(
	@ObjectId INT,
	@ObjectTypeId INT,
	@AccessEntities dbo.[udttCatalogContentAccess] READONLY
)
AS
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #ignorecontents(ObjectId INT PRIMARY KEY)
	
	IF @ObjectTypeId = 2 --in case the parent is a catalog
	BEGIN
		-- in case of MergeChildPermissions, we update ACEs only for child nodes which are set permissions (present in CatalogContentAccess table)
		INSERT INTO #ignorecontents(ObjectId)
		SELECT CatalogNodeId
		FROM CatalogNode
		WHERE CatalogId = @ObjectId AND NOT EXISTS(SELECT * FROM CatalogContentAccess WHERE ObjectId = CatalogNode.CatalogNodeId AND ObjectTypeId = 1)
		
		--delete all ACEs of all child nodes
		DELETE FROM CatalogContentAccess
		WHERE EXISTS(SELECT * FROM CatalogNode WHERE CatalogNodeId = CatalogContentAccess.ObjectId AND CatalogId = @ObjectId)
		AND ObjectTypeId = 1

		-- create new ACEs for all child nodes of @ObjectId
		INSERT INTO CatalogContentAccess(ObjectId, ObjectTypeId, Name, IsRole, AccessMask)
		SELECT node.CatalogNodeId, 1, ace.Name, ace.IsRole, ace.AccessMask
		FROM @AccessEntities ace
		INNER JOIN CatalogNode node ON node.CatalogId = @ObjectId
		WHERE NOT EXISTS(SELECT * FROM #ignorecontents WHERE ObjectId = node.CatalogNodeId)
	END
	ELSE IF @ObjectTypeId = 1 --in case the parent is a node
	BEGIN
		INSERT INTO #ignorecontents(ObjectId)
		SELECT CatalogNodeId
		FROM CatalogNode
		WHERE ParentNodeId = @ObjectId AND NOT EXISTS(SELECT * FROM CatalogContentAccess WHERE ObjectId = CatalogNode.CatalogNodeId AND ObjectTypeId = 1)

		--delete all ACEs of all child nodes
		DELETE FROM CatalogContentAccess
		WHERE EXISTS(SELECT * FROM CatalogNode WHERE CatalogNodeId = CatalogContentAccess.ObjectId AND ParentNodeId = @ObjectId)
		AND ObjectTypeId = 1

		-- create new ACEs for all child nodes of @ObjectId
		INSERT INTO CatalogContentAccess(ObjectId, ObjectTypeId, Name, IsRole, AccessMask)
		SELECT node.CatalogNodeId, 1, ace.Name, ace.IsRole, ace.AccessMask
		FROM @AccessEntities ace
		INNER JOIN CatalogNode node ON node.ParentNodeId = @ObjectId
		WHERE NOT EXISTS(SELECT * FROM #ignorecontents WHERE ObjectId = node.CatalogNodeId)
	END
END
GO
PRINT N'Creating [dbo].[CatalogContentAccess_ReplaceChildPermissions]...';


GO
CREATE PROCEDURE dbo.CatalogContentAccess_ReplaceChildPermissions
(
	@ObjectId INT,
	@ObjectTypeId INT,
	@AccessEntities dbo.[udttCatalogContentAccess] READONLY
)
AS
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #ignorecontents(ObjectId INT PRIMARY KEY)
	
	IF @ObjectTypeId = 2 --in case the parent is a catalog
	BEGIN
		--delete all ACEs of all child nodes
		DELETE FROM CatalogContentAccess
		WHERE EXISTS(SELECT * FROM CatalogNode WHERE CatalogNodeId = CatalogContentAccess.ObjectId AND CatalogId = @ObjectId)
		AND ObjectTypeId = 1

		-- create new ACEs for all child nodes of @ObjectId
		INSERT INTO CatalogContentAccess(ObjectId, ObjectTypeId, Name, IsRole, AccessMask)
		SELECT node.CatalogNodeId, 1, ace.Name, ace.IsRole, ace.AccessMask
		FROM @AccessEntities ace
		INNER JOIN CatalogNode node ON node.CatalogId = @ObjectId
	END
	ELSE IF @ObjectTypeId = 1 --in case the parent is a node
	BEGIN
		--delete all ACEs of all child nodes
		DELETE FROM CatalogContentAccess
		WHERE EXISTS(SELECT * FROM CatalogNode WHERE CatalogNodeId = CatalogContentAccess.ObjectId AND ParentNodeId = @ObjectId)
		AND ObjectTypeId = 1

		-- create new ACEs for all child nodes of @ObjectId
		INSERT INTO CatalogContentAccess(ObjectId, ObjectTypeId, Name, IsRole, AccessMask)
		SELECT node.CatalogNodeId, 1, ace.Name, ace.IsRole, ace.AccessMask
		FROM @AccessEntities ace
		INNER JOIN CatalogNode node ON node.ParentNodeId = @ObjectId
	END
END
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 1, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
