--beginvalidatingquery
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_DatabaseVersion]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
		begin
			declare @ver int
			exec @ver = sp_DatabaseVersion
			if (@ver >= 7063)
				select 0, 'Already correct database version'
			else if (@ver = 7062)
				select 1, 'Upgrading database'
			else
				select -1, 'Invalid database version detected'
		end
	else
		select -1, 'Not an EPiServer database'
--endvalidatingquery
GO


PRINT N'Altering [dbo].[editPublishContentVersion]...';


GO

ALTER PROCEDURE dbo.editPublishContentVersion
(
	@WorkContentID	INT,
	@UserName NVARCHAR(255),
	@TrimVersions BIT = 0,
	@ResetCommonDraft BIT = 1,
	@PublishedDate DATETIME = NULL
)
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON
	DECLARE @ContentID INT
	DECLARE @retval INT
	DECLARE @FirstPublish BIT
	DECLARE @ParentID INT
	DECLARE @LangBranchID INT
	DECLARE @IsMasterLang BIT
	
	/* Verify that we have a Content to publish */
	SELECT	@ContentID=fkContentID,
			@LangBranchID=fkLanguageBranchID,
			@IsMasterLang = CASE WHEN tblWorkContent.fkLanguageBranchID=tblContent.fkMasterLanguageBranchID THEN 1 ELSE 0 END
	FROM tblWorkContent WITH (ROWLOCK,XLOCK)
	INNER JOIN tblContent WITH (ROWLOCK,XLOCK) ON tblContent.pkID=tblWorkContent.fkContentID
	WHERE tblWorkContent.pkID=@WorkContentID
	
	IF (@@ROWCOUNT <> 1)
		RETURN 0

	IF @PublishedDate IS NULL
		SET @PublishedDate = GetDate()
					
	/* Move Content information from worktable to published table */
	IF @IsMasterLang=1
	BEGIN
		UPDATE 
			tblContent
		SET
			ArchiveContentGUID	= W.ArchiveContentGUID,
			VisibleInMenu	= W.VisibleInMenu,
			ChildOrderRule	= W.ChildOrderRule,
			PeerOrder		= W.PeerOrder
		FROM 
			tblWorkContent AS W
		WHERE 
			tblContent.pkID=W.fkContentID AND 
			W.pkID=@WorkContentID
	END
	
	UPDATE 
			tblContentLanguage WITH (ROWLOCK,XLOCK)
		SET
			ChangedByName	= W.ChangedByName,
			ContentLinkGUID	= W.ContentLinkGUID,
			fkFrameID		= W.fkFrameID,
			Name			= W.Name,
			URLSegment		= W.URLSegment,
			LinkURL			= W.LinkURL,
			BlobUri			= W.BlobUri,
			ThumbnailUri	= W.ThumbnailUri,
			ExternalURL		= Lower(W.ExternalURL),
			AutomaticLink	= CASE WHEN W.LinkType = 2 OR W.LinkType = 3 THEN 0 ELSE 1 END,
			FetchData		= CASE WHEN W.LinkType = 4 THEN 1 ELSE 0 END,
			Created			= W.Created,
			Changed			= CASE WHEN W.ChangedOnPublish=0 AND tblContentLanguage.Status = 4 THEN Changed ELSE @PublishedDate END,
			Saved			= @PublishedDate,
			StartPublish	= COALESCE(W.StartPublish, @PublishedDate),
			StopPublish		= W.StopPublish,
			Status			= 4,
			Version			= @WorkContentID,
			DelayPublishUntil = NULL
		FROM 
			tblWorkContent AS W
		WHERE 
			tblContentLanguage.fkContentID=W.fkContentID AND
			W.fkLanguageBranchID=tblContentLanguage.fkLanguageBranchID AND
			W.pkID=@WorkContentID

	IF @@ROWCOUNT!=1
		RAISERROR (N'editPublishContentVersion: Cannot find correct version in tblContentLanguage for version %d', 16, 1, @WorkContentID)

	/*Set current published version on this language to HasBeenPublished*/
	UPDATE
		tblWorkContent
	SET
		Status = 5
	WHERE
		fkContentID = @ContentID AND
		fkLanguageBranchID = @LangBranchID AND 
		Status = 4 AND
		pkID<>@WorkContentID

	/* Remember that this version has been published, and clear the delay publish date if used */
	UPDATE
		tblWorkContent
	SET
		Status = 4,
		ChangedOnPublish = 0,
		Saved=@PublishedDate,
        ChangedByName=@UserName,
		NewStatusByName=@UserName,
		fkMasterVersionID = NULL,
		DelayPublishUntil = NULL,
		StartPublish = COALESCE(StartPublish, @PublishedDate)
	WHERE
		pkID=@WorkContentID
		
	/* Remove all properties defined for this Content except dynamic properties */
	DELETE FROM 
		tblContentProperty
	FROM 
		tblContentProperty
	INNER JOIN
		tblPropertyDefinition ON fkPropertyDefinitionID=tblPropertyDefinition.pkID
	WHERE 
		fkContentID=@ContentID AND
		fkContentTypeID IS NOT NULL AND
		fkLanguageBranchID=@LangBranchID
		
	/* Move properties from worktable to published table */
	INSERT INTO tblContentProperty 
		(fkPropertyDefinitionID,
		fkContentID,
		fkLanguageBranchID,
		ScopeName,
		[guid],
		Boolean,
		Number,
		FloatNumber,
		ContentType,
		ContentLink,
		Date,
		String,
		LongString,
		LongStringLength,
        LinkGuid)
	SELECT
		fkPropertyDefinitionID,
		@ContentID,
		@LangBranchID,
		ScopeName,
		[guid],
		Boolean,
		Number,
		FloatNumber,
		ContentType,
		ContentLink,
		Date,
		String,
		LongString,
		/* LongString is utf-16 - Datalength gives bytes, i e div by 2 gives characters */
		/* Include length to handle delayed loading of LongString with threshold */
		COALESCE(DATALENGTH(LongString), 0) / 2,
        LinkGuid
	FROM
		tblWorkContentProperty
	WHERE
		fkWorkContentID=@WorkContentID
	
	/* Move categories to published tables */
	DELETE 	tblContentCategory
	FROM tblContentCategory
	LEFT JOIN tblPropertyDefinition ON tblPropertyDefinition.pkID=tblContentCategory.CategoryType 
	WHERE 	tblContentCategory.fkContentID=@ContentID
			AND (NOT fkContentTypeID IS NULL OR CategoryType=0)
			AND (tblPropertyDefinition.LanguageSpecific>2 OR @IsMasterLang=1)--Only lang specific on non-master
			AND tblContentCategory.fkLanguageBranchID=@LangBranchID
			
	INSERT INTO tblContentCategory
		(fkContentID,
		fkCategoryID,
		CategoryType,
		fkLanguageBranchID,
		ScopeName)
	SELECT
		@ContentID,
		fkCategoryID,
		CategoryType,
		@LangBranchID,
		ScopeName
	FROM
		tblWorkContentCategory
	WHERE
		fkWorkContentID=@WorkContentID
	
	IF @ResetCommonDraft = 1
		EXEC editSetCommonDraftVersion @WorkContentID = @WorkContentID, @Force = 1				

	IF (@TrimVersions = 1)
        DELETE FROM tblWorkContent WHERE fkContentID = @ContentID AND fkLanguageBranchID = @LangBranchID AND Status = 5

END
GO
PRINT N'Altering [dbo].[editSetVersionStatus]...';


GO
ALTER PROCEDURE [dbo].[editSetVersionStatus]
(
	@WorkContentID INT,
	@Status INT,
	@UserName NVARCHAR(255),
	@Saved DATETIME = NULL,
	@RejectComment NVARCHAR(2000) = NULL,
	@DelayPublishUntil DateTime = NULL
)
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON
	
	UPDATE 
		tblWorkContent
	SET
		Status = @Status,
        ChangedByName=@UserName,
		NewStatusByName=@UserName,
		RejectComment= COALESCE(@RejectComment, RejectComment),
        Saved = COALESCE(@Saved, Saved),
		DelayPublishUntil = @DelayPublishUntil
	WHERE
		pkID=@WorkContentID 

	IF (@@ROWCOUNT = 0)
		RETURN 1

	-- If there is no published version for this language update published table as well
	DECLARE @ContentID INT;
	DECLARE @LanguageBranchID INT;

	SELECT @LanguageBranchID = lang.fkLanguageBranchID, @ContentID = lang.fkContentID FROM tblContentLanguage AS lang INNER JOIN tblWorkContent AS work 
		ON lang.fkContentID = work.fkContentID WHERE 
		work.pkID = @WorkContentID AND work.fkLanguageBranchID = lang.fkLanguageBranchID AND lang.Status <> 4

	IF @ContentID IS NOT NULL
		BEGIN

			UPDATE
				tblContentLanguage
			SET
				Status = @Status,
				DelayPublishUntil = @DelayPublishUntil
			WHERE
				fkContentID=@ContentID AND fkLanguageBranchID=@LanguageBranchID

		END

	RETURN 0
END
GO

PRINT N'Altering [dbo].[editDeletePageCheckInternal]...';


GO

ALTER PROCEDURE [dbo].[editDeletePageCheckInternal]
(@pages editDeletePageInternalTable READONLY) 
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @Result AS TABLE	(
		OwnerLanguageID INT NULL,
		ReferencedLanguageID INT,
		OwnerID INT NOT NULL, 
		OwnerName NVARCHAR(255),
		ReferencedID INT,
		ReferencedName NVARCHAR(255),
		ReferenceType INT NOT NULL
	)

	INSERT INTO @Result
	SELECT
		tblContentLanguage.fkLanguageBranchID AS OwnerLanguageID,
		NULL AS ReferencedLanguageID,
		tblContentLanguage.fkContentID AS OwnerID,
		tblContentLanguage.Name As OwnerName,
		ContentLink As ReferencedID,
		tpl.Name AS ReferencedName,
		0 AS ReferenceType
	FROM 
		tblContentProperty 
	INNER JOIN 
		tblContent ON tblContentProperty.fkContentID=tblContent.pkID
	INNER JOIN 
		tblContentLanguage ON tblContentLanguage.fkContentID=tblContent.pkID
	INNER JOIN
		tblContent AS tp ON ContentLink=tp.pkID
	INNER JOIN
		tblContentLanguage AS tpl ON tpl.fkContentID=tp.pkID
	WHERE 
		(ContentLink IN (SELECT pkID FROM @pages)) AND
		tblContentLanguage.fkLanguageBranchID=tblContentProperty.fkLanguageBranchID AND
		tpl.fkLanguageBranchID=tp.fkMasterLanguageBranchID

	INSERT INTO @Result
	SELECT
		tblContentLanguage.fkLanguageBranchID AS OwnerLanguageID,
		NULL AS ReferencedLanguageID,    
		tblContentLanguage.fkContentID AS OwnerID,
		tblContentLanguage.Name As OwnerName,
		tp.pkID AS ReferencedID,
		tpl.Name AS ReferencedName,
		1 AS ReferenceType
	FROM
		tblContentLanguage
	INNER JOIN
		tblContent ON tblContent.pkID=tblContentLanguage.fkContentID
	INNER JOIN
		tblContent AS tp ON tblContentLanguage.ContentLinkGUID = tp.ContentGUID
	INNER JOIN
		tblContentLanguage AS tpl ON tpl.fkContentID=tp.pkID
	WHERE
		(tblContentLanguage.ContentLinkGUID IN (SELECT PageGUID FROM @pages)) AND
		tpl.fkLanguageBranchID=tp.fkMasterLanguageBranchID
	
	INSERT INTO @Result
	SELECT
		tblContentSoftlink.OwnerLanguageID AS OwnerLanguageID,
		tblContentSoftlink.ReferencedLanguageID AS ReferencedLanguageID,
		PLinkFrom.pkID AS OwnerID,
		PLinkFromLang.Name  As OwnerName,
		PLinkTo.pkID AS ReferencedID,
		PLinkToLang.Name AS ReferencedName,
		1 AS ReferenceType
	FROM
		tblContentSoftlink
	INNER JOIN
		tblContent AS PLinkFrom ON PLinkFrom.pkID=tblContentSoftlink.fkOwnerContentID
	INNER JOIN
		tblContentLanguage AS PLinkFromLang ON PLinkFromLang.fkContentID=PLinkFrom.pkID
	INNER JOIN
		tblContent AS PLinkTo ON PLinkTo.ContentGUID=tblContentSoftlink.fkReferencedContentGUID
	INNER JOIN
		tblContentLanguage AS PLinkToLang ON PLinkToLang.fkContentID=PLinkTo.pkID
	WHERE
		(PLinkTo.pkID IN (SELECT pkID FROM @pages)) AND
		PLinkFromLang.fkLanguageBranchID=PLinkFrom.fkMasterLanguageBranchID AND
		PLinkToLang.fkLanguageBranchID=PLinkTo.fkMasterLanguageBranchID

	INSERT INTO @Result
	SELECT
		tblContentLanguage.fkLanguageBranchID AS OwnerLanguageID,
		NULL AS ReferencedLanguageID,
		tblContent.pkID AS OwnerID,
		tblContentLanguage.Name  As OwnerName,
		tp.pkID AS ReferencedID,
		tpl.Name AS ReferencedName,
		2 AS ReferenceType
	FROM
		tblContent
	INNER JOIN 
		tblContentLanguage ON tblContentLanguage.fkContentID=tblContent.pkID
	INNER JOIN
		tblContent AS tp ON tblContent.ArchiveContentGUID=tp.ContentGUID
	INNER JOIN
		tblContentLanguage AS tpl ON tpl.fkContentID=tp.pkID
	WHERE
		(tblContent.ArchiveContentGUID IN (SELECT PageGUID FROM @pages)) AND
		tpl.fkLanguageBranchID=tp.fkMasterLanguageBranchID AND
		tblContentLanguage.fkLanguageBranchID=tblContent.fkMasterLanguageBranchID

	SELECT 
		OwnerLanguageID,
		ReferencedLanguageID ,
		OwnerID, 
		OwnerName,
		ReferencedID,
		ReferencedName,
		ReferenceType
	FROM 
		@Result result
	JOIN
		tblContent ON result.OwnerID=tblContent.pkID	
	WHERE 
		Deleted = 0 AND OwnerID NOT IN (SELECT pkID FROM @pages)

	UNION

	SELECT 
		tblContentLanguage.fkLanguageBranchID AS OwnerLanguageID,
		NULL AS ReferencedLanguageID,
		tblContent.pkID AS OwnerID, 
		tblContentLanguage.Name  As OwnerName,
		tblContentTypeDefault.fkArchiveContentID AS ReferencedID,
		tblContentType.Name AS ReferencedName,
		3 AS ReferenceType
	FROM 
		tblContentTypeDefault
	INNER JOIN
	   tblContentType ON tblContentTypeDefault.fkContentTypeID=tblContentType.pkID
	INNER JOIN
		tblContent ON tblContentTypeDefault.fkArchiveContentID=tblContent.pkID
	INNER JOIN 
		tblContentLanguage ON tblContentLanguage.fkContentID=tblContent.pkID
	WHERE 
		tblContentTypeDefault.fkArchiveContentID IN (SELECT pkID FROM @pages) AND
		tblContentLanguage.fkLanguageBranchID=tblContent.fkMasterLanguageBranchID

	ORDER BY
	   ReferenceType

	RETURN 0
END
GO

PRINT N'Altering [dbo].[sp_DatabaseVersion]...';


GO
ALTER PROCEDURE [dbo].[sp_DatabaseVersion]
AS
	RETURN 7063
GO
PRINT N'Update complete.';


GO
