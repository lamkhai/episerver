--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 10, @patch int = 5    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

DECLARE @ApplicationIds TABLE (ApplicationId UNIQUEIDENTIFIER)
INSERT INTO @ApplicationIds
SELECT ApplicationId FROM dbo.Application

DECLARE @ApplicationId UNIQUEIDENTIFIER


WHILE (SELECT Count(*) FROM @ApplicationIds) > 0
BEGIN

    SELECT TOP 1 @ApplicationId = ApplicationId FROM @ApplicationIds

    --Add missing permissions
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'businessfoundation:contact:edit:permission')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'businessfoundation:organization:list:permission')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'businessfoundation:contact:list:permission')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'catalog:admin:currencies:mng:create')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'catalog:admin:currencies:mng:delete')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'catalog:admin:currencies:mng:edit')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'catalog:admin:currencies:mng:view')	
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'core:admin:applog:mng:delete')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'core:admin:applog:mng:view')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'core:admin:syslog:mng:delete')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'core:admin:syslog:mng:view')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'core:mng:businessfoundation')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'core:mng:leftmenu')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'core:mng:search')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'markets:market:mng:create')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'markets:market:mng:delete')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'markets:market:mng:edit')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'markets:market:mng:view')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'markets:tabviewpermission')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'order:mng:change:price')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'Permission')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'reporting:mng:view')
    INSERT INTO dbo.RolePermission (ApplicationId, RoleName, Permission) VALUES(@ApplicationId, 'Administrators', 'reporting:tabviewpermission')

    DELETE @ApplicationIds WHERE ApplicationId = @ApplicationId

END
GO

 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 10, 5, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
