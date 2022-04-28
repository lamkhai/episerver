--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 0, @patch int = 6    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

-- begin create SP ecfVersion_Save
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_Save] 
GO
CREATE PROCEDURE [dbo].[ecfVersion_Save]
	@WorkId int,
	@ObjectId int,
	@ObjectTypeId int,
	@Name [nvarchar](100),
	@Code [nvarchar](100),
	@LanguageName [nvarchar](20),
	@MasterLanguageName [nvarchar](20),
    @StartPublish [datetime],
	@StopPublish DATETIME,
	@Status INT,
	@CreatedBy [nvarchar](100),
	@Created DATETIME,
	@ModifiedBy [nvarchar](100),
	@Modified DATETIME,
	@SeoUri nvarchar(255),
	@SeoTitle nvarchar(150),
	@SeoDescription nvarchar(355),
	@SeoKeywords nvarchar(355),
	@SeoUriSegment nvarchar(255),
	@MaxVersions INT = 20
AS
BEGIN
	-- We have to treat the name field as not culture specific, so we need to copy the name from the master language to all other languages.
	IF @LanguageName = @MasterLanguageName COLLATE DATABASE_DEFAULT
	BEGIN
		UPDATE ecfVersion SET Name = @Name WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId AND LanguageName <> @MasterLanguageName COLLATE DATABASE_DEFAULT
	END

	UPDATE ecfVersion
	SET ObjectId = @ObjectId,
		Code = @Code,
		Name = @Name,
		ObjectTypeId = @ObjectTypeId,
		LanguageName = @LanguageName,
		MasterLanguageName = @MasterLanguageName,
		StartPublish = @StartPublish,
		StopPublish = @StopPublish,
		[Status] = @Status,
		CreatedBy = @CreatedBy,
	    Created = @Created,
		Modified = @Modified,
		ModifiedBy = @ModifiedBy,
		SeoUri = @SeoUri,
		SeoTitle = @SeoTitle,
		SeoDescription = @SeoDescription,
		SeoKeywords = @SeoKeywords,
		SeoUriSegment = @SeoUriSegment
	WHERE WorkId = @WorkId

	IF (@Status = 4)
	BEGIN
		EXEC ecfVersion_PublishContentVersion @WorkId, @ObjectId, @ObjectTypeId, @LanguageName, @MaxVersions
	END
END
GO
-- end create SP ecfVersion_Save
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 6, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
