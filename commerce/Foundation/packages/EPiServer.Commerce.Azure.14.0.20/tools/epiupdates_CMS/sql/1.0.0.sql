--beginvalidatingquery
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'tblPlugIn')
    IF EXISTS (SELECT 1 FROM dbo.tblPlugIn 
                        WHERE AssemblyName = 'EPiServer.Business.Commerce' AND 
                            TypeName = 'EPiServer.Business.Commerce.ScheduledJobs.RotateEncryptionJob' AND
                            Enabled = 1) 
        BEGIN 
            SELECT 1, 'Migrating to EPiServer Commerce Azure'
        END 
    ELSE 
        SELECT 0, 'Already migrating to EPiServer Commerce Azure'
ELSE 
    SELECT -1, 'Not an EPiServer CMS database' 
--endvalidatingquery

-- TextInRowSize value must first be switched off because Azure do not support TextInRowSize.
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'aspnet_Membership')
BEGIN
    EXECUTE sp_tableoption 'aspnet_Membership', 'text in row', 'OFF';
END

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'aspnet_Profile')
BEGIN
    EXECUTE sp_tableoption 'aspnet_Profile', 'text in row', 'OFF';
END

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'aspnet_PersonalizationAllUsers')
BEGIN
    EXECUTE sp_tableoption 'aspnet_PersonalizationAllUsers', 'text in row', 'OFF';
END

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'aspnet_PersonalizationPerUser')
BEGIN
    EXECUTE sp_tableoption 'aspnet_PersonalizationPerUser', 'text in row', 'OFF';
END

-- Disable Rotate Encrypt key schedule job
DECLARE @JobID INT
SELECT @JobID = pkID FROM dbo.tblPlugIn WHERE AssemblyName = 'EPiServer.Business.Commerce' 
    AND TypeName = 'EPiServer.Business.Commerce.ScheduledJobs.RotateEncryptionJob'
IF @JobID IS NOT NULL
	IF EXISTS (SELECT (1) FROM INFORMATION_SCHEMA.PARAMETERS WHERE SPECIFIC_NAME = 'netPlugInSave' AND PARAMETER_NAME = '@Saved') 
	BEGIN
		DECLARE @Saved DATETIME
		SET @Saved = GetDate()
		EXECUTE netPlugInSave @PlugInID = @JobID, @Enabled = 0, @Saved = @Saved
	END
	ELSE
		EXECUTE netPlugInSave @PlugInID = @JobID, @Enabled = 0
GO

-- Update stored procedure [dbo].aspnet_Setup_RemoveAllRoleMembers
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[aspnet_Setup_RemoveAllRoleMembers]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
    DROP PROCEDURE [dbo].[aspnet_Setup_RemoveAllRoleMembers]
GO

IF (EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'aspnet_Membership'))
  EXEC ('
    CREATE PROCEDURE [dbo].[aspnet_Setup_RemoveAllRoleMembers]
        @name   sysname
    AS
    BEGIN
        CREATE TABLE #aspnet_RoleMembers
        (
            Group_name      sysname,
            Group_id        smallint,
            Users_in_group  sysname,
            User_id         smallint
        )

        INSERT INTO #aspnet_RoleMembers
        select Role_name = substring(r.name, 1, 25), Role_id = r.principal_id,
           Users_in_role = substring(u.name, 1, 25), Userid = u.principal_id
        from sys.database_principals u, sys.database_principals r, sys.database_role_members m
        where r.name = @name
            and r.principal_id = m.role_principal_id
            and u.principal_id = m.member_principal_id
        order by 1, 2

        DECLARE @user_id smallint
        DECLARE @cmd nvarchar(500)
        DECLARE c1 cursor FORWARD_ONLY FOR
            SELECT User_id FROM #aspnet_RoleMembers

        OPEN c1

        FETCH c1 INTO @user_id
        WHILE (@@fetch_status = 0)
        BEGIN
            SET @cmd = ''EXEC sp_droprolemember '' + '''''''' + @name + '''''', '''''' + USER_NAME(@user_id) + ''''''''
            EXEC (@cmd)
            FETCH c1 INTO @user_id
        END

        CLOSE c1
        DEALLOCATE c1
    END
  ')
GO

-- Create a clustered index for table [CompletedScope]

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'CompletedScope') AND NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('[CompletedScope]') AND type_desc = 'CLUSTERED')
    CREATE CLUSTERED INDEX IX_CompletedScope_uidInstanceID ON [dbo].[CompletedScope] ([uidInstanceID]);
GO

-- Update stored procedure [dbo].[InsertCompletedScope]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[InsertCompletedScope]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
    DROP PROCEDURE [dbo].[InsertCompletedScope]
GO

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'CompletedScope')
 EXEC('
    CREATE PROCEDURE [dbo].[InsertCompletedScope]
        @instanceID uniqueidentifier,
        @completedScopeID uniqueidentifier,
        @state image
    AS
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED
    SET NOCOUNT ON
            UPDATE [dbo].[CompletedScope] WITH(ROWLOCK, UPDLOCK) 
                SET state = @state,
                modified = GETUTCDATE()
                WHERE completedScopeID=@completedScopeID 
            IF ( @@ROWCOUNT = 0 )
            BEGIN
                --Insert Operation
                INSERT INTO [dbo].[CompletedScope] WITH(ROWLOCK)
                VALUES(@instanceID, @completedScopeID, @state, GETUTCDATE()) 
            END
            RETURN
    RETURN
 ')   
GO

-- Update stored procedure [dbo].[aspnet_Membership_GetNumberOfUsersOnline]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[aspnet_Membership_GetNumberOfUsersOnline]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
    DROP PROCEDURE [dbo].[aspnet_Membership_GetNumberOfUsersOnline]
GO

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'aspnet_Membership')
  EXEC('
    CREATE PROCEDURE [dbo].[aspnet_Membership_GetNumberOfUsersOnline]
        @ApplicationName            nvarchar(256),
        @MinutesSinceLastInActive   int,
        @CurrentTimeUtc             datetime
    AS
    BEGIN
        DECLARE @DateActive datetime
        SELECT  @DateActive = DATEADD(minute,  -(@MinutesSinceLastInActive), @CurrentTimeUtc)

        DECLARE @NumOnline int
        SELECT  @NumOnline = COUNT(*)
        FROM    dbo.aspnet_Users u WITH (NOLOCK),
                dbo.aspnet_Applications a WITH (NOLOCK),
                dbo.aspnet_Membership m WITH (NOLOCK)
        WHERE   u.ApplicationId = a.ApplicationId                  AND
                LastActivityDate > @DateActive                     AND
                a.LoweredApplicationName = LOWER(@ApplicationName) AND
                u.UserId = m.UserId
        RETURN(@NumOnline)
    END
  ')
GO
