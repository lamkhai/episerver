--beginvalidatingquery
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_DatabaseVersion]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
		begin
			declare @ver int
			exec @ver = sp_DatabaseVersion
			if (@ver >= 7066)
				select 0, 'Already correct database version'
			else if (@ver = 7065)
				select 1, 'Upgrading database'
			else
				select -1, 'Invalid database version detected'
		end
	else
		select -1, 'Not an EPiServer database'
--endvalidatingquery
GO

PRINT N'Creating [dbo].[netFindContentCoreDataByContentGuidBatch]...';
GO

CREATE PROCEDURE [dbo].[netFindContentCoreDataByContentGuidBatch]
	@ContentGuids AS GuidParameterTable READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON

        --- *** use NOLOCK since this may be called during page save if debugging. The code should not be written so this happens, it's to make it work in the debugger ***
	SELECT P.pkID as ID, P.fkContentTypeID as ContentTypeID, P.fkParentID as ParentID, P.ContentGUID, PL.LinkURL, P.Deleted, CASE WHEN Status = 4 THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END AS PendingPublish, PL.Created, PL.Changed, PL.Saved, PL.StartPublish, PL.StopPublish, P.ContentAssetsID, P.fkMasterLanguageBranchID as MasterLanguageBranchID, PL.ContentLinkGUID as ContentLinkID, PL.AutomaticLink, PL.FetchData, P.ContentType
	FROM tblContent AS P WITH (NOLOCK)
    INNER JOIN @ContentGuids as ParamGuids on P.ContentGUID = ParamGuids.Id	
	LEFT JOIN tblContentLanguage AS PL ON PL.fkContentID=P.pkID
	WHERE P.fkMasterLanguageBranchID=PL.fkLanguageBranchID OR P.fkMasterLanguageBranchID IS NULL
END
GO

PRINT N'Creating [dbo].[netFindContentCoreDataByIDBatch]...';
GO

CREATE PROCEDURE [dbo].[netFindContentCoreDataByIDBatch]
	@ContentIDs AS IDTable READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON

        --- *** use NOLOCK since this may be called during content save if debugging. The code should not be written so this happens, it's to make it work in the debugger ***
	SELECT P.pkID as ID, P.fkContentTypeID as ContentTypeID, P.fkParentID as ParentID, P.ContentGUID, PL.LinkURL, P.Deleted, CASE WHEN Status = 4 THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END AS PendingPublish, PL.Created, PL.Changed, PL.Saved, PL.StartPublish, PL.StopPublish, P.ContentAssetsID, P.fkMasterLanguageBranchID as MasterLanguageBranchID, PL.ContentLinkGUID as ContentLinkID, PL.AutomaticLink, PL.FetchData, P.ContentType
	FROM tblContent AS P WITH (NOLOCK)
    INNER JOIN @ContentIDs as ParamIds on P.pkID = ParamIds.Id	
	LEFT JOIN tblContentLanguage AS PL ON PL.fkContentID = P.pkID
	WHERE P.fkMasterLanguageBranchID = PL.fkLanguageBranchID OR P.fkMasterLanguageBranchID IS NULL
END
GO

PRINT N'Altering [dbo].[sp_DatabaseVersion]...';
GO

ALTER PROCEDURE [dbo].[sp_DatabaseVersion]
AS
	RETURN 7066
GO

PRINT N'Update complete.';
GO