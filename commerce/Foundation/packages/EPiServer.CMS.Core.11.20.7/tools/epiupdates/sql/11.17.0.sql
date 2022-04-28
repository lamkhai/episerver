--beginvalidatingquery
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_DatabaseVersion]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
		begin
			declare @ver int
			exec @ver = sp_DatabaseVersion
			if (@ver >= 7064)
				select 0, 'Already correct database version'
			else if (@ver = 7063)
				select 1, 'Upgrading database'
			else
				select -1, 'Invalid database version detected'
		end
	else
		select -1, 'Not an EPiServer database'
--endvalidatingquery
GO


PRINT N'Altering [dbo].[tblSiteDefinition]...';


GO
ALTER TABLE [dbo].[tblSiteDefinition]
    ADD [SavedBy] NVARCHAR (255) NULL,
        [Saved]   DATETIME       NULL;


GO
PRINT N'Altering [dbo].[netSiteDefinitionList]...';


GO
ALTER PROCEDURE [dbo].[netSiteDefinitionList]
AS
BEGIN
	SELECT UniqueId, Name, SiteUrl, StartPage, SiteAssetsRoot, SavedBy, Saved FROM tblSiteDefinition

	SELECT site.[UniqueId] AS SiteId, host.[Name], host.[Type], host.[Language], host.[Https] 
	FROM tblHostDefinition host
	INNER JOIN tblSiteDefinition site ON site.pkID = host.fkSiteID

END
GO
PRINT N'Altering [dbo].[netSiteDefinitionSave]...';


GO
ALTER PROCEDURE [dbo].[netSiteDefinitionSave]
(
	@UniqueId uniqueidentifier = NULL OUTPUT,
	@Name nvarchar(255),
	@SiteUrl varchar(MAX),
	@StartPage varchar(255),
	@SiteAssetsRoot varchar(255) = NULL,
	@Hosts dbo.HostDefinitionTable READONLY,
    @UserName nvarchar(255),
	@Saved datetime
)
AS
BEGIN
	DECLARE @SiteID int
	
	IF (@UniqueId IS NULL OR @UniqueId = CAST(0x0 AS uniqueidentifier))
		SET @UniqueId = NEWID()
	ELSE -- If UniqueId is set we must first check if it has been saved before
		SELECT @SiteID = pkID FROM tblSiteDefinition WHERE UniqueId = @UniqueId

	IF (@SiteID IS NULL) 
	BEGIN
		INSERT INTO tblSiteDefinition 
		(
			UniqueId,
			Name,
			SiteUrl,
			StartPage,
			SiteAssetsRoot,
            SavedBy,
            Saved
		) 
		VALUES
		(
			@UniqueId,
			@Name,
			@SiteUrl,
			@StartPage,
			@SiteAssetsRoot,
            @UserName,
            @Saved
		)
		SET @SiteID = SCOPE_IDENTITY()
	END
	ELSE
	BEGIN
		UPDATE tblSiteDefinition SET 
			UniqueId=@UniqueId,
			Name = @Name,
			SiteUrl = @SiteUrl,
			StartPage = @StartPage,
			SiteAssetsRoot = @SiteAssetsRoot,
            SavedBy = @UserName,
            Saved = @Saved
		WHERE 
			pkID = @SiteID
		
	END

	-- Site hosts
	MERGE tblHostDefinition AS Target
    USING @Hosts AS Source
    ON (Target.Name = Source.Name AND Target.fkSiteID=@SiteID)
    WHEN MATCHED THEN 
        UPDATE SET fkSiteID = @SiteID, Name = Source.Name, Type = Source.Type, Language = Source.Language, Https = Source.Https
	WHEN NOT MATCHED BY Source AND Target.fkSiteID = @SiteID THEN
		DELETE
	WHEN NOT MATCHED BY Target THEN
		INSERT (fkSiteID, Name, Type, Language, Https)
		VALUES (@SiteID, Source.Name, Source.Type, Source.Language, Source.Https);

END
GO
PRINT N'Altering [dbo].[sp_DatabaseVersion]...';


GO
ALTER PROCEDURE [dbo].[sp_DatabaseVersion]
AS
	RETURN 7064
GO
PRINT N'Refreshing [dbo].[netSiteDefinitionDelete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[netSiteDefinitionDelete]';


GO
PRINT N'Update complete.';


GO
