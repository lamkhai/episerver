--beginvalidatingquery
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_DatabaseVersion]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
		begin
			declare @ver int
			exec @ver = sp_DatabaseVersion
			if (@ver >= 7062)
				select 0, 'Already correct database version'
			else if (@ver = 7061)
				select 1, 'Upgrading database'
			else
				select -1, 'Invalid database version detected'
		end
	else
		select -1, 'Not an EPiServer database'
--endvalidatingquery
GO


PRINT N'Altering [dbo].[tblContentType]...';
GO

ALTER TABLE [dbo].[tblContentType]
	ADD [Base] NVARCHAR (50) NULL,
		[Version] NVARCHAR (50) NULL,
		[Saved] DATETIME NULL,
		[SavedBy] NVARCHAR (255) NULL;
GO

PRINT N'Altering [dbo].[netContentTypeList]...';
GO

ALTER PROCEDURE [dbo].[netContentTypeList]
AS
BEGIN
	SET NOCOUNT ON
	
	SELECT	CT.pkID AS ID,
			CONVERT(NVARCHAR(38),CT.ContentTypeGUID) AS Guid,
			CT.Created,
			CT.Saved,
			CT.SavedBy,
			CT.Name,
			CT.Base,
			CT.Version,
			CT.DisplayName,
			CT.Description,
			CT.DefaultWebFormTemplate,
			CT.DefaultMvcController,
			CT.DefaultMvcPartialView,
			CT.Available,
			CT.SortOrder,
			CT.ModelType,
			CT.Filename,
			CT.ACL,
			CT.ContentType,
			CTD.pkID AS DefaultID,
			CTD.Name AS DefaultName,
			CTD.StartPublishOffset,
			CTD.StopPublishOffset,
			CONVERT(INT,CTD.VisibleInMenu) AS VisibleInMenu,
			CTD.PeerOrder,
			CTD.ChildOrderRule,
			CTD.fkFrameID AS FrameID,
			CTD.fkArchiveContentID AS ArchiveContentLink
	FROM tblContentType CT
	LEFT JOIN tblContentTypeDefault AS CTD ON CTD.fkContentTypeID=CT.pkID 
	ORDER BY CT.SortOrder
END
GO

PRINT N'Altering [dbo].[netContentTypeSave]...';
GO

ALTER PROCEDURE [dbo].[netContentTypeSave]
(
	@ContentTypeID			INT,
	@ContentTypeGUID		UNIQUEIDENTIFIER,
	@Saved					DATETIME		= NULL,
	@SavedBy				NVARCHAR(255)	= NULL,
	@Name					NVARCHAR(50),
	@Base					NVARCHAR(50)	= NULL,
	@Version				NVARCHAR(50)	= NULL,
	@DisplayName			NVARCHAR(50)	= NULL,
	@Description			NVARCHAR(255)	= NULL,
	@DefaultWebFormTemplate	NVARCHAR(1024)	= NULL,
	@DefaultMvcController	NVARCHAR(1024)	= NULL,
	@DefaultMvcPartialView	NVARCHAR(255)	= NULL,
	@Filename				NVARCHAR(255)	= NULL,
	@Available				BIT				= NULL,
	@SortOrder				INT				= NULL,
	@ModelType				NVARCHAR(1024)	= NULL,
	
	@DefaultID				INT				= NULL,
	@DefaultName			NVARCHAR(100)	= NULL,
	@StartPublishOffset		INT				= NULL,
	@StopPublishOffset		INT				= NULL,
	@VisibleInMenu			BIT				= NULL,
	@PeerOrder				INT				= NULL,
	@ChildOrderRule			INT				= NULL,
	@ArchiveContentID		INT				= NULL,
	@FrameID				INT				= NULL,
	@ACL					NVARCHAR(MAX)	= NULL,
	@ContentType			INT				= 0,
	@Created				DATETIME
)
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	DECLARE @IdString NVARCHAR(255)
	
	IF @ContentTypeID <= 0
	BEGIN
		SET @ContentTypeID = ISNULL((SELECT pkID FROM tblContentType where Name = @Name), @ContentTypeID)
	END

	IF (@ContentTypeID <= 0)
	BEGIN
		SELECT TOP 1 @IdString = IdString FROM tblContentType
		INSERT INTO tblContentType
			(Saved,
			SavedBy,
			Name,
			DisplayName,
			Base,
			Version,
			DefaultMvcController,
			DefaultWebFormTemplate,
			DefaultMvcPartialView,
			Description,
			Available,
			SortOrder,
			ModelType,
			Filename,
			IdString,
			ContentTypeGUID,
			ACL,
			ContentType,
			Created
)
		VALUES
			(@Saved,
			@SavedBy,
			@Name,
			@DisplayName,
			@Base,
			@Version,
			@DefaultMvcController,
			@DefaultWebFormTemplate,
			@DefaultMvcPartialView,
			@Description,
			@Available,
			@SortOrder,
			@ModelType,
			@Filename,
			@IdString,
			@ContentTypeGUID,
			@ACL,
			@ContentType,
			@Created)

		SET @ContentTypeID = SCOPE_IDENTITY() 
		
	END
	ELSE
	BEGIN
		BEGIN
			UPDATE tblContentType
			SET
				Saved = @Saved,
				SavedBy = @SavedBy,
				Name=@Name,
				Base=@Base,
				Version=@Version,
				DisplayName=@DisplayName,
				Description=@Description,
				DefaultWebFormTemplate=@DefaultWebFormTemplate,
				DefaultMvcController=@DefaultMvcController,
				DefaultMvcPartialView=@DefaultMvcPartialView,
				Available=@Available,
				SortOrder=@SortOrder,
				ModelType = @ModelType,
				Filename = @Filename,
				ACL=@ACL,
				ContentType = @ContentType,
				@ContentTypeGUID = ContentTypeGUID
			WHERE
				pkID=@ContentTypeID
		END
	END

	IF (@DefaultID IS NULL)
	BEGIN
		DELETE FROM tblContentTypeDefault WHERE fkContentTypeID=@ContentTypeID
	END
	ELSE
	BEGIN
		IF (EXISTS (SELECT pkID FROM tblContentTypeDefault WHERE fkContentTypeID=@ContentTypeID))
		BEGIN
			UPDATE tblContentTypeDefault SET
				Name				= @DefaultName,
				StartPublishOffset	= @StartPublishOffset,
				StopPublishOffset	= @StopPublishOffset,
				VisibleInMenu		= @VisibleInMenu,
				PeerOrder			= @PeerOrder,
				ChildOrderRule		= @ChildOrderRule,
				fkArchiveContentID	= @ArchiveContentID,
				fkFrameID			= @FrameID
			WHERE fkContentTypeID = @ContentTypeID
		END
		ELSE
		BEGIN
			INSERT INTO tblContentTypeDefault 
				(fkContentTypeID,
				Name,
				StartPublishOffset,
				StopPublishOffset,
				VisibleInMenu,
				PeerOrder,
				ChildOrderRule,
				fkArchiveContentID,
				fkFrameID)
			VALUES
				(@ContentTypeID,
				@DefaultName,
				@StartPublishOffset,
				@StopPublishOffset,
				@VisibleInMenu,
				@PeerOrder,
				@ChildOrderRule,
				@ArchiveContentID,
				@FrameID)
		END
	END
		
	SELECT @ContentTypeID AS "ID", @ContentTypeGUID AS "GUID"
END
GO


IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[tblContentType]'))
BEGIN
    PRINT 'Adding Base to tblContentType'

 --Update Root Content type
  UPDATE tblContentType SET Base = 'Page' Where ContentTypeGUID = '3FA7D9E7-877B-11D3-827C-00A024CACFCB'
 --Update Recycle Bin Content type
  UPDATE tblContentType SET Base = 'Page' Where ContentTypeGUID = '4EEA90CD-4210-4115-A399-6D6915554E10'
 --Update ContentFolder Content type
  UPDATE tblContentType SET Base = 'Folder' Where ContentTypeGUID = '52F8D1E9-6D87-4DB6-A465-41890289FB78'
 --Update ContentAssetFolder Content type
  UPDATE tblContentType SET Base = 'Folder' Where ContentTypeGUID = 'E9AB78A3-1BBF-48ef-A8D4-1C1F98E80D91'
END
GO



PRINT N'Altering [dbo].[sp_DatabaseVersion]...';
GO

ALTER PROCEDURE [dbo].[sp_DatabaseVersion]
AS
	RETURN 7062
GO

PRINT N'Update complete.';
GO