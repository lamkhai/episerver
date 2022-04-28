--beginvalidatingquery
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_DatabaseVersion]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
		begin
			declare @ver int
			exec @ver = sp_DatabaseVersion
			if (@ver >= 7065)
				select 0, 'Already correct database version'
			else if (@ver = 7064)
				select 1, 'Upgrading database'
			else
				select -1, 'Invalid database version detected'
		end
	else
		select -1, 'Not an EPiServer database'
--endvalidatingquery
GO

PRINT N'Altering [dbo].[tblPropertyDefinition]...';
GO

ALTER TABLE [dbo].[tblPropertyDefinition]
    ADD [EditorHint] NVARCHAR (255) NULL;
GO

PRINT N'Altering [dbo].[tblPageDefinition]...';
GO

ALTER VIEW [dbo].[tblPageDefinition]
AS
SELECT  [pkID],
		[fkContentTypeID] AS fkPageTypeID,
		[fkPropertyDefinitionTypeID] AS fkPageDefinitionTypeID,
		[FieldOrder],
		[Name],
		[Property],
		[Required],
		[Advanced],
		[Searchable],
		[EditCaption],
		[HelpText],
		[ObjectProgID],
		[DefaultValueType],
		[LongStringSettings],
		[SettingsID],
		[LanguageSpecific],
		[DisplayEditUI],
		[ExistsOnModel],
        [EditorHint]
FROM    dbo.tblPropertyDefinition
GO

PRINT N'Altering [dbo].[netPageDefinitionGet]...';
GO

ALTER PROCEDURE [dbo].[netPageDefinitionGet]
(
	@PageDefinitionID INT
)
AS
BEGIN
	SELECT tblPageDefinition.pkID AS ID,
		fkPageTypeID AS PageTypeID,
		COALESCE(fkPageDefinitionTypeID,tblPageDefinition.Property) AS PageDefinitionTypeID,
		tblPageDefinition.Name,
		COALESCE(tblPageDefinitionType.Property,tblPageDefinition.Property) AS Type,
		CONVERT(INT,Required) AS Required,
		Advanced,
		CONVERT(INT,Searchable) AS Searchable,
		DefaultValueType,
		EditCaption,
		HelpText,
		ObjectProgID,
		LongStringSettings,
		SettingsID,
		CONVERT(INT,Boolean) AS Boolean,
		Number AS IntNumber,
		FloatNumber,
		PageType,
		PageLink,
		Date AS DateValue,
		String,
		LongString,
		FieldOrder,
		LanguageSpecific,
		DisplayEditUI,
		ExistsOnModel,
        EditorHint
	FROM tblPageDefinition
	LEFT JOIN tblPropertyDefault ON tblPropertyDefault.fkPageDefinitionID=tblPageDefinition.pkID
	LEFT JOIN tblPageDefinitionType ON tblPageDefinitionType.pkID=tblPageDefinition.fkPageDefinitionTypeID
	WHERE tblPageDefinition.pkID = @PageDefinitionID
END
GO

PRINT N'Altering [dbo].[netPageDefinitionList]...';
GO

ALTER PROCEDURE [dbo].[netPageDefinitionList]
(
	@PageTypeID INT = NULL
)
AS
BEGIN
	SELECT tblPageDefinition.pkID AS ID,
		fkPageTypeID AS PageTypeID,
		COALESCE(fkPageDefinitionTypeID,tblPageDefinition.Property) AS PageDefinitionTypeID,
		tblPageDefinition.Name,
		COALESCE(tblPageDefinitionType.Property,tblPageDefinition.Property) AS Type,
		CONVERT(INT,Required) AS Required,
		Advanced,
		CONVERT(INT,Searchable) AS Searchable,
		DefaultValueType,
		EditCaption,
		HelpText,
		ObjectProgID,
		LongStringSettings,
		SettingsID,
		CONVERT(INT,Boolean) AS Boolean,
		Number AS IntNumber,
		FloatNumber,
		PageType,
		PageLink,
		Date AS DateValue,
		String,
		LongString,
		NULL AS OldType,
		FieldOrder,
		LanguageSpecific,
		DisplayEditUI,
		ExistsOnModel,
        EditorHint
	FROM tblPageDefinition
	LEFT JOIN tblPropertyDefault ON tblPropertyDefault.fkPageDefinitionID=tblPageDefinition.pkID
	LEFT JOIN tblPageDefinitionType ON tblPageDefinitionType.pkID=tblPageDefinition.fkPageDefinitionTypeID
	WHERE (fkPageTypeID = @PageTypeID) OR (fkPageTypeID IS NULL AND @PageTypeID IS NULL)
	ORDER BY FieldOrder,tblPageDefinition.pkID
END
GO

PRINT N'Altering [dbo].[netPageDefinitionSave]...';
GO

ALTER PROCEDURE dbo.netPageDefinitionSave
(
	@PageDefinitionID      INT OUTPUT,
	@PageTypeID            INT,
	@Name                  NVARCHAR(100),
	@PageDefinitionTypeID  INT,
	@Required              BIT = NULL,
	@Advanced              INT = NULL,
	@Searchable            BIT = NULL,
	@DefaultValueType      INT = NULL,
	@EditCaption           NVARCHAR(255) = NULL,
	@HelpText              NVARCHAR(2000) = NULL,
	@ObjectProgID          NVARCHAR(255) = NULL,
	@LongStringSettings    INT = NULL,
	@SettingsID            UNIQUEIDENTIFIER = NULL,
	@FieldOrder            INT = NULL,
	@Type                  INT = NULL OUTPUT,
	@OldType               INT = NULL OUTPUT,
	@LanguageSpecific      INT = 0,
	@DisplayEditUI         BIT = NULL,
	@ExistsOnModel         BIT = 0,
    @EditorHint               NVARCHAR(255) = NULL
)
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	SELECT @OldType = tblPageDefinitionType.Property 
	FROM tblPageDefinition
	INNER JOIN tblPageDefinitionType ON tblPageDefinitionType.pkID=tblPageDefinition.fkPageDefinitionTypeID
	WHERE tblPageDefinition.pkID=@PageDefinitionID

	SELECT @Type = Property FROM tblPageDefinitionType WHERE pkID=@PageDefinitionTypeID
	IF @Type IS NULL
		RAISERROR('Cannot find data type',16,1)
	IF @PageTypeID=0
		SET @PageTypeID = NULL

	IF @PageDefinitionID = 0 AND @ExistsOnModel = 1
	BEGIN
		SET @PageDefinitionID = ISNULL((SELECT pkID FROM tblPageDefinition where Name = @Name AND fkPageTypeID = @PageTypeID), @PageDefinitionID)
	END

	IF @PageDefinitionID=0
	BEGIN	
		INSERT INTO tblPageDefinition
		(
			fkPageTypeID,
			fkPageDefinitionTypeID,
			Name,
			Property,
			Required,
			Advanced,
			Searchable,
			DefaultValueType,
			EditCaption,
			HelpText,
			ObjectProgID,
			LongStringSettings,
			SettingsID,
			FieldOrder,
			LanguageSpecific,
			DisplayEditUI,
			ExistsOnModel,
            EditorHint
		)
		VALUES
		(
			@PageTypeID,
			@PageDefinitionTypeID,
			@Name,
			@Type,
			@Required,
			@Advanced,
			@Searchable,
			@DefaultValueType,
			@EditCaption,
			@HelpText,
			@ObjectProgID,
			@LongStringSettings,
			@SettingsID,
			@FieldOrder,
			@LanguageSpecific,
			@DisplayEditUI,
			@ExistsOnModel,
            @EditorHint
		)
		SET @PageDefinitionID =  SCOPE_IDENTITY() 
	END
	ELSE
	BEGIN
		UPDATE tblPageDefinition SET
			Name 		= @Name,
			fkPageDefinitionTypeID	= @PageDefinitionTypeID,
			Property 	= @Type,
			Required 	= @Required,
			Advanced 	= @Advanced,
			Searchable 	= @Searchable,
			DefaultValueType = @DefaultValueType,
			EditCaption 	= @EditCaption,
			HelpText 	= @HelpText,
			ObjectProgID 	= @ObjectProgID,
			LongStringSettings = @LongStringSettings,
			SettingsID = @SettingsID,
			LanguageSpecific = @LanguageSpecific,
			FieldOrder = @FieldOrder,
			DisplayEditUI = @DisplayEditUI,
			ExistsOnModel = @ExistsOnModel,
            EditorHint = @EditorHint
		WHERE pkID=@PageDefinitionID
	END
	DELETE FROM tblPropertyDefault WHERE fkPageDefinitionID=@PageDefinitionID
	IF @LanguageSpecific<3
	BEGIN
		/* NOTE: Here we take into consideration that language neutral dynamic properties are always stored on language 
			with id 1 (which perhaps should be changed and in that case the special handling here could be removed). */
		IF @PageTypeID IS NULL
		BEGIN
			DELETE tblProperty
			FROM tblProperty
			INNER JOIN tblPage ON tblPage.pkID=tblProperty.fkPageID
			WHERE fkPageDefinitionID=@PageDefinitionID AND tblProperty.fkLanguageBranchID<>1
		END
		ELSE
		BEGIN
			DELETE tblProperty
			FROM tblProperty
			INNER JOIN tblPage ON tblPage.pkID=tblProperty.fkPageID
			WHERE fkPageDefinitionID=@PageDefinitionID AND tblProperty.fkLanguageBranchID<>tblPage.fkMasterLanguageBranchID
		END
		DELETE tblWorkProperty
		FROM tblWorkProperty
		INNER JOIN tblWorkPage ON tblWorkProperty.fkWorkPageID=tblWorkPage.pkID
		INNER JOIN tblPage ON tblPage.pkID=tblWorkPage.fkPageID
		WHERE fkPageDefinitionID=@PageDefinitionID AND tblWorkPage.fkLanguageBranchID<>tblPage.fkMasterLanguageBranchID

		DELETE 
			tblCategoryPage
		FROM
			tblCategoryPage
		INNER JOIN
			tblPage
		ON
			tblPage.pkID = tblCategoryPage.fkPageID
		WHERE
			CategoryType = @PageDefinitionID
		AND
			tblCategoryPage.fkLanguageBranchID <> tblPage.fkMasterLanguageBranchID

		DELETE 
			tblWorkCategory
		FROM
			tblWorkCategory
		INNER JOIN 
			tblWorkPage
		ON
			tblWorkCategory.fkWorkPageID = tblWorkPage.pkID
		INNER JOIN
			tblPage
		ON
			tblPage.pkID = tblWorkPage.fkPageID
		WHERE
			CategoryType = @PageDefinitionID
		AND
			tblWorkPage.fkLanguageBranchID <> tblPage.fkMasterLanguageBranchID
	END
END
GO

PRINT N'Altering [dbo].[sp_DatabaseVersion]...';
GO

ALTER PROCEDURE [dbo].[sp_DatabaseVersion]
AS
	RETURN 7065
GO

PRINT N'Update complete.';
GO