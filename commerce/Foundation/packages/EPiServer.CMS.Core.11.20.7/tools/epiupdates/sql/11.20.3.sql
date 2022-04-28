--beginvalidatingquery
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_DatabaseVersion]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
		begin
			declare @ver int
			exec @ver = sp_DatabaseVersion
			if (@ver >= 7067)
				select 0, 'Already correct database version'
			else if (@ver = 7066)
				select 1, 'Upgrading database'
			else
				select -1, 'Invalid database version detected'
		end
	else
		select -1, 'Not an EPiServer database'
--endvalidatingquery
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

	DELETE 
		result 
	FROM 
		@Result result
	WHERE 
		result.OwnerID IN (SELECT pkID FROM @pages)
	
	DELETE 
		result 
	FROM 
		@Result result
	INNER JOIN 
		tblContent ON result.OwnerID = tblContent.pkID	
	WHERE 
		tblContent.Deleted != 0

	INSERT INTO @Result
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
	ORDER BY
	   ReferenceType

	RETURN 0
END
GO

PRINT N'Altering [dbo].[sp_DatabaseVersion]...';
GO

ALTER PROCEDURE [dbo].[sp_DatabaseVersion]
AS
	RETURN 7067
GO

PRINT N'Update complete.';
GO