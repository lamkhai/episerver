--beginvalidatingquery
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_DatabaseVersion]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
		begin
			declare @ver int
			exec @ver = sp_DatabaseVersion
			if (@ver >= 7068)
				select 0, 'Already correct database version'
			else if (@ver = 7067)
				select 1, 'Upgrading database'
			else
				select -1, 'Invalid database version detected'
		end
	else
		select -1, 'Not an EPiServer database'
--endvalidatingquery
GO

PRINT N'Altering [dbo].[tblContent]...';
GO

DROP INDEX [IDX_tblContent_fkParentID]
    ON [dbo].[tblContent];
GO

CREATE NONCLUSTERED INDEX [IDX_tblContent_fkParentID]
    ON [dbo].[tblContent]([fkParentID] ASC)
    INCLUDE([fkContentTypeID], [IsLeafNode], [ContentType]);
GO

PRINT N'Altering [dbo].[tblContentLanguage]...';
GO

CREATE NONCLUSTERED INDEX [IDX_tblContentLanguage_fkLanguageBranchID]
    ON [dbo].[tblContentLanguage]([fkLanguageBranchID] ASC, [fkContentID] ASC)
    INCLUDE([Name]);
GO

PRINT N'Altering [dbo].[sp_DatabaseVersion]...';
GO

ALTER PROCEDURE [dbo].[sp_DatabaseVersion]
AS
	RETURN 7068
GO

PRINT N'Update complete.';
GO