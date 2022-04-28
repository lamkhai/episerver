--beginvalidatingquery
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_DatabaseVersion]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
    begin
            declare @ver int
            exec @ver=sp_DatabaseVersion
            if (@ver >= 7060)
				select 0, 'Already correct database version'
            else if (@ver = 7059)
                 select 1, 'Upgrading database'
            else
                 select -1, 'Invalid database version detected'
    end
    else
            select -1, 'Not an EPiServer database'
--endvalidatingquery

GO

PRINT N'Altering [dbo].[tblSynchedUser]...';


GO
ALTER TABLE [dbo].[tblSynchedUser]
    ADD [RolesHash] INT NULL;


GO
PRINT N'Altering [dbo].[netSynchedUserRoleUpdate]...';


GO

ALTER PROCEDURE dbo.netSynchedUserRoleUpdate
(
	@UserName NVARCHAR(255),
	@Roles dbo.StringParameterTable READONLY,
    @RolesHash INT = NULL
)
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	DECLARE @UserID INT
    DECLARE @CurrentRolesHash INT
	SELECT @UserID = pkID, @CurrentRolesHash = RolesHash FROM [tblSynchedUser] WHERE LoweredUserName = LOWER(@UserName)
	IF (@UserID IS NULL)
	BEGIN
		RAISERROR(N'No user with username %s was found', 16, 1, @UserName)
	END
    
    IF ((@RolesHash IS NULL AND @CurrentRolesHash IS NOT NULL) OR (@RolesHash IS NOT NULL AND @CurrentRolesHash IS NULL) OR @RolesHash <>  @CurrentRolesHash)
    BEGIN
        UPDATE [tblSynchedUser] SET RolesHash = @RolesHash WHERE pkID = @UserID

	    /*First ensure roles are in role table*/
	    MERGE [tblSynchedUserRole] AS Target
		    USING @Roles AS Source
		    ON (Target.LoweredRoleName = LOWER(Source.String))
		    WHEN NOT MATCHED BY Target THEN
			    INSERT (RoleName, LoweredRoleName)
			    VALUES (Source.String, LOWER(Source.String));

	    /* Remove all existing fole for user */
	    DELETE FROM [tblSynchedUserRelations] WHERE [fkSynchedUser] = @UserID

	    /* Insert roles */
	    INSERT INTO [tblSynchedUserRelations] ([fkSynchedRole], [fkSynchedUser])
	    SELECT [tblSynchedUserRole].pkID, @UserID FROM 
	    [tblSynchedUserRole] INNER JOIN @Roles AS R ON [tblSynchedUserRole].LoweredRoleName = LOWER(R.String)
    END
END
GO

GO
PRINT N'Dropping [dbo].[netPageDefinitionTypeList]...';


GO
DROP PROCEDURE [dbo].[netPageDefinitionTypeList];


GO
PRINT N'Starting rebuilding table [dbo].[tblPropertyDefinitionType]...';


GO
ALTER TABLE [dbo].[tblPropertyDefinitionType] ADD [GUID] uniqueidentifier NULL


GO
PRINT N'Altering [dbo].[netPropertyDefinitionTypeSave]...';


GO
ALTER PROCEDURE [dbo].[netPropertyDefinitionTypeSave]
(
	@ID 			INT OUTPUT,
	@Property 		INT,
	@Name 			NVARCHAR(255),
    @GUID           uniqueidentifier = NULL,
	@TypeName 		NVARCHAR(255) = NULL,
	@AssemblyName 	NVARCHAR(255) = NULL,
	@BlockTypeID	uniqueidentifier = NULL
)
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	/* In case several sites start up at sametime, e.g. in enterprise it may occour that both sites tries to insert at same time. 
	Therefore a check is made to see it it already exist an entry with same guid, and if so an update is performed instead of insert.*/
	IF @ID <= 0
	BEGIN
		SET @ID = ISNULL((SELECT pkID FROM tblPropertyDefinitionType WHERE fkContentTypeGUID = @BlockTypeID), @ID)
	END

	IF @ID<0
	BEGIN
		IF @AssemblyName='EPiServer'
			SELECT @ID = Max(pkID)+1 FROM tblPropertyDefinitionType WHERE pkID<1000
		ELSE
			SELECT @ID = CASE WHEN Max(pkID)<1000 THEN 1000 ELSE Max(pkID)+1 END FROM tblPropertyDefinitionType
		INSERT INTO tblPropertyDefinitionType
		(
			pkID,
			Property,
			Name,
            GUID,
			TypeName,
			AssemblyName,
			fkContentTypeGUID
		)
		VALUES
		(
			@ID,
			@Property,
			@Name,
            @GUID,
			@TypeName,
			@AssemblyName,
			@BlockTypeID
		)
	END
	ELSE
		UPDATE tblPropertyDefinitionType SET
			Name 		= @Name,
			Property		= @Property,
            GUID        = @GUID,
			TypeName 	= @TypeName,
			AssemblyName 	= @AssemblyName,
			fkContentTypeGUID = @BlockTypeID
		WHERE pkID=@ID
		
END
GO
PRINT N'Creating [dbo].[netPropertyDefinitionTypeList]...';


GO
CREATE PROCEDURE dbo.netPropertyDefinitionTypeList
AS
BEGIN
	SELECT 	DT.pkID AS ID,
			DT.Name,
			DT.Property,
            DT.GUID,
			DT.TypeName,
			DT.AssemblyName, 
			DT.fkContentTypeGUID AS BlockTypeID,
			PT.Name as BlockTypeName,
			PT.ModelType as BlockTypeModel
	FROM tblPropertyDefinitionType as DT
		LEFT OUTER JOIN tblContentType as PT ON DT.fkContentTypeGUID = PT.ContentTypeGUID
	ORDER BY DT.Name
END
GO


PRINT N'Altering [dbo].[sp_DatabaseVersion]...';


GO
ALTER PROCEDURE [dbo].[sp_DatabaseVersion]
AS
	RETURN 7060
GO
PRINT N'Refreshing [dbo].[netSynchedUserGetMetadata]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[netSynchedUserGetMetadata]';


GO
PRINT N'Refreshing [dbo].[netSynchedUserInsertOrUpdate]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[netSynchedUserInsertOrUpdate]';


GO
PRINT N'Refreshing [dbo].[netSynchedUserList]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[netSynchedUserList]';


GO
PRINT N'Refreshing [dbo].[netSynchedUserMatchRoleList]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[netSynchedUserMatchRoleList]';


GO
PRINT N'Refreshing [dbo].[netSynchedUserRoleList]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[netSynchedUserRoleList]';


GO
PRINT N'Update complete.';


GO
