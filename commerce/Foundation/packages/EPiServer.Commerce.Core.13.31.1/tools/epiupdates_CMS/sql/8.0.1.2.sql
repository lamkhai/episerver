--beginvalidatingquery
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'tblContentType') 
    SELECT -1, 'Not an EPiServer CMS database' 
ELSE
	SELECT 1, 'Verifying/creating Campaign root...'
--endvalidatingquery

GO

DECLARE @contentTypeGuid UNIQUEIDENTIFIER
DECLARE @campaignRootGuid UNIQUEIDENTIFIER
DECLARE @campaignRootName varchar(256)
SET @contentTypeGuid = '00C8157D-8117-4D0D-B449-B31960ABA2D4'
SET @campaignRootGuid = '48E4889F-926B-478C-9EAE-25AE12C4AEE2'
SET @campaignRootName = 'SysCampaignRoot'

-- Delete duplicate content types that may have been created by earlier versions of this script
DELETE t FROM tblContentType t
	WHERE t.ContentTypeGUID = @contentTypeGuid
	AND (NOT EXISTS (SELECT * FROM tblContent c WHERE c.fkContentTypeID = t.pkID))

DECLARE @LanguageBranchID INT
SELECT @LanguageBranchID = pkID FROM tblLanguageBranch WHERE LanguageID = ''

DECLARE @fkContentId INT
SELECT @fkContentId = pkID FROM tblContent WHERE ContentGUID = @campaignRootGuid

IF EXISTS (SELECT 1 FROM tblContent INNER JOIN tblLanguageBranch ON fkMasterLanguageBranchID = tblLanguageBranch.pkID WHERE tblContent.pkID = @fkContentId AND LanguageID <> '') 
BEGIN
	UPDATE tblContent SET fkMasterLanguageBranchID = @LanguageBranchID
				WHERE pkID = @fkContentId

	UPDATE tblContentLanguage 
				SET fkLanguageBranchID = @LanguageBranchID
				FROM tblContentLanguage as lang INNER JOIN tblContent as cont on lang.fkContentID = cont.pkID
				WHERE cont.pkID = @fkContentId

	UPDATE tblContentCategory 
				SET fkLanguageBranchID = @LanguageBranchID
				FROM tblContentCategory as cat INNER JOIN tblContent as cont on cat.fkContentID = cont.pkID
				WHERE cont.pkID = @fkContentId

	UPDATE tblContentProperty 
				SET fkLanguageBranchID = @LanguageBranchID
				FROM tblContentProperty as prop INNER JOIN tblContent as cont on prop.fkContentID = cont.pkID
				WHERE cont.pkID = @fkContentId

	UPDATE tblWorkContent
				SET fkLanguageBranchID = @LanguageBranchID
				FROM tblWorkContent as workCont 
							 INNER JOIN tblContent as cont on workCont.fkContentID = cont.pkID
				WHERE cont.pkID = @fkContentId

	UPDATE tblContentSoftLink
				SET OwnerLanguageID = @LanguageBranchID
				FROM tblContentSoftLink as soft INNER JOIN tblContent as cont on soft.fkOwnerContentId = cont.pkID
				WHERE cont.pkID = @fkContentId

	UPDATE tblContentSoftLink
				SET ReferencedLanguageID = @LanguageBranchID
				FROM tblContentSoftLink as soft INNER JOIN tblContent as cont on soft.fkReferencedContentGUID = cont.ContentGUID
				WHERE cont.pkID = @fkContentId
END

GO