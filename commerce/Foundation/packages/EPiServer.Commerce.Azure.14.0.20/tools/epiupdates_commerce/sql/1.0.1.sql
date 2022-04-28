--beginvalidatingquery
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
		IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'AzureCompatible')		
		BEGIN			
			IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_OpenSymmetricKey]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
				select 0,'Already correct database version' 
			ELSE 
				select 1, 'Upgrading database' 
		END
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
GO 

-- begin create function mdpfn_sys_EncryptDecryptString
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpfn_sys_EncryptDecryptString]') AND OBJECTPROPERTY(id, N'IsScalarFunction') = 1) DROP FUNCTION [dbo].[mdpfn_sys_EncryptDecryptString] 
GO
CREATE FUNCTION [dbo].[mdpfn_sys_EncryptDecryptString]
(
	@input nvarchar(4000),
	@encrypt bit
)
RETURNS nvarchar(4000)
AS
BEGIN
	-- encryption is disabled by default. To enable encryption, execute EncryptionSupport.sql file of EPiServer.Commerce.Core package.
	RETURN @input;
END
GO
-- end create function mdpfn_sys_EncryptDecryptString

-- begin create function mdpfn_sys_EncryptDecryptString2
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpfn_sys_EncryptDecryptString2]') AND OBJECTPROPERTY(id, N'IsScalarFunction') = 1) DROP FUNCTION [dbo].[mdpfn_sys_EncryptDecryptString2] 
GO
CREATE FUNCTION [dbo].[mdpfn_sys_EncryptDecryptString2]
(	
	@input varbinary(4000), 
	@encrypt bit
)
RETURNS varbinary(4000)
AS
BEGIN
	-- encryption is disabled by default. To enable encryption, execute EncryptionSupport.sql file of EPiServer.Commerce.Core package.
	RETURN @input;
END
GO
-- end create function mdpfn_sys_EncryptDecryptString2

-- begin create function mdpfn_sys_IsAzureCompatible
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpfn_sys_IsAzureCompatible]') AND OBJECTPROPERTY(id, N'IsScalarFunction') = 1) DROP FUNCTION [dbo].[mdpfn_sys_IsAzureCompatible] 
GO
CREATE FUNCTION [dbo].[mdpfn_sys_IsAzureCompatible]()
RETURNS BIT
AS
BEGIN
	DECLARE @RetVal BIT
	SET @RetVal = ISNULL((SELECT AzureCompatible FROM dbo.AzureCompatible), 0)
	RETURN @RetVal;
END
GO
-- end create function mdpfn_sys_IsAzureCompatible

-- begin create SP mdpsp_sys_OpenSymmetricKey
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_OpenSymmetricKey]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mdpsp_sys_OpenSymmetricKey] 
GO
CREATE PROCEDURE [dbo].[mdpsp_sys_OpenSymmetricKey]	
AS
	-- encryption is disabled by default. To enable encryption, execute EncryptionSupport.sql file of EPiServer.Commerce.Core package.
	
GO
-- end of creating mdpsp_sys_OpenSymmetricKey

-- begin create SP mdpsp_sys_CloseSymmetricKey
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_CloseSymmetricKey]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mdpsp_sys_CloseSymmetricKey] 
GO
CREATE PROCEDURE [dbo].[mdpsp_sys_CloseSymmetricKey]	
AS
	-- encryption is disabled by default. To enable encryption, execute EncryptionSupport.sql file of EPiServer.Commerce.Core package.
	
GO
-- end of creating mdpsp_sys_CloseSymmetricKey