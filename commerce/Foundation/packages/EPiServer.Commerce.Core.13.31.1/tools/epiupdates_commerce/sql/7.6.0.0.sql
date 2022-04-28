--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 6, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

-- create stored procedure ecfVersion_ListFiltered
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_ListFiltered]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_ListFiltered] 
GO

CREATE PROCEDURE [dbo].[ecfVersion_ListFiltered]
(
    @ObjectId INT = NULL,
	@ObjectTypeId INT = NULL,
	@ModifiedBy NVARCHAR(255) = NULL,
	@Languages [udttLanguageCode] READONLY,
	@Statuses [udttIdTable] READONLY,
	@StartIndex INT,
    @MaxRows INT
)
AS

BEGIN	
	SET NOCOUNT ON

	DECLARE @StatusCount INT
	SELECT @StatusCount = COUNT(*) FROM @Statuses

	DECLARE @LanguageCount INT
	SELECT @LanguageCount = COUNT(*) FROM @Languages
	
	;WITH TempResult as
	(
		SELECT ROW_NUMBER() OVER(ORDER BY vn.Modified DESC) as RowNumber, vn.*
		FROM
			dbo.ecfVersion vn
		WHERE
			vn.CurrentLanguageRemoved = 0 AND
			((@ObjectId IS NULL) OR vn.ObjectId = @ObjectId) AND
			((@ObjectTypeId IS NULL) OR vn.ObjectTypeId = @ObjectTypeId) AND
			((@ModifiedBy IS NULL) OR vn.ModifiedBy = @ModifiedBy) AND
			((@StatusCount = 0) OR (vn.[Status] IN (SELECT ID FROM @Statuses))) AND
            ((@LanguageCount = 0) OR (vn.LanguageName IN (SELECT LanguageCode FROM @Languages)))
	)
	SELECT  WorkId, ObjectId, ObjectTypeId, Name, LanguageName, MasterLanguageName, IsCommonDraft, StartPublish, ModifiedBy, Modified, [Status], (SELECT COUNT(*) FROM TempResult) AS TotalRows
	FROM    TempResult
	WHERE	RowNumber BETWEEN (@StartIndex + 1) AND (@MaxRows + @StartIndex)
   		
END
GO
-- end create stored procedure ecfVersion_ListFiltered

-- update stored procedure ecfVersion_List
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_List]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_List] 
GO

CREATE PROCEDURE [dbo].[ecfVersion_List]
	@ObjectIds [dbo].[udttContentList] READONLY,
	@ObjectTypeId int
AS
BEGIN
	SELECT vn.*
	FROM dbo.ecfVersion vn
	INNER JOIN @ObjectIds i ON vn.ObjectId = i.ContentId
	WHERE vn.ObjectTypeId = @ObjectTypeId AND CurrentLanguageRemoved = 0
END
GO
-- end update stored procedure ecfVersion_List
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 6, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
