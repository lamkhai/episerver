--beginvalidatingquery
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
		IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'AzureCompatible')
		BEGIN
			IF EXISTS (SELECT 1 FROM dbo.AzureCompatible WHERE AzureCompatible = 1)
				select 0,'Already correct database version' 
			ELSE 
				select 1, 'Upgrading database' 
		END
		ELSE
			select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
GO 

-- TextInRowSize value must first be switched off because Azure do not support TextInRowSize.
EXECUTE sp_tableoption 'aspnet_Membership', 'text in row', 'OFF';
EXECUTE sp_tableoption 'aspnet_Profile', 'text in row', 'OFF';
EXECUTE sp_tableoption 'aspnet_PersonalizationAllUsers', 'text in row', 'OFF';
EXECUTE sp_tableoption 'aspnet_PersonalizationPerUser', 'text in row', 'OFF';

-- Decrypt credit card data
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'cls_CreditCard') AND
	EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_OpenSymmetricKey]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) AND
	EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_CloseSymmetricKey]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
BEGIN
	EXEC mdpsp_sys_OpenSymmetricKey
	UPDATE dbo.cls_CreditCard
	SET [CreditCardNumber] = CCD.CardNumber_string,
		[SecurityCode] = CCD.SecurityCode_string
	FROM (SELECT CONVERT(VARCHAR(max), DecryptByKey(cast(N'' AS XML).value('xs:base64Binary(sql:column("CC.CreditCardNumber"))', 'varbinary(max)'))) AS [CardNumber_string],
				 CONVERT(VARCHAR(max), DecryptByKey(cast(N'' AS XML).value('xs:base64Binary(sql:column("CC.SecurityCode"))','varbinary(max)'))) AS [SecurityCode_string]
		FROM cls_CreditCard CC
		WHERE CC.CreditCardNumber is not NULL AND CC.SecurityCode is not NULL) CCD
	EXEC mdpsp_sys_CloseSymmetricKey
END
GO

-- Decrypt metadata
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_OpenSymmetricKey]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) AND
	EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_CloseSymmetricKey]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
BEGIN
	EXEC mdpsp_sys_OpenSymmetricKey
	IF EXISTS (SELECT TOP (1) 1 FROM dbo.SchemaVersion WHERE Major >= 7) 
	BEGIN
		-- Commerce 9, decrypt published contents
		UPDATE p 
		SET 
			LongString = dbo.mdpfn_sys_EncryptDecryptString(LongString, 0)
		FROM CatalogContentProperty p
		INNER JOIN MetaField mf ON mf.MetaFieldId = p.MetaFieldId
		INNER JOIN MetaDataType t ON mf.DataTypeId = t.DataTypeId
		WHERE mf.IsEncrypted = 1 
		
		-- and also decrypt draft versions
		UPDATE p 
		SET 
			LongString = dbo.mdpfn_sys_EncryptDecryptString(LongString, 0)
		FROM ecfVersionProperty p
		INNER JOIN MetaField mf ON mf.MetaFieldId = p.MetaFieldId
		INNER JOIN MetaDataType t ON mf.DataTypeId = t.DataTypeId
		WHERE mf.IsEncrypted = 1 
	END
	ELSE
	BEGIN
		DECLARE @MetaClassTable NVARCHAR(256), @MetaFieldName NVARCHAR(256), @MultiLanguageValue BIT, @MetaQuery_tmp nvarchar(max)
		DECLARE classall_cursor CURSOR FOR
		SELECT MF.Name, MF.MultiLanguageValue, MC.TableName FROM MetaField MF
				INNER JOIN MetaClassMetaFieldRelation MCFR ON MCFR.MetaFieldId = MF.MetaFieldId
				INNER JOIN MetaClass MC ON MC.MetaClassId = MCFR.MetaClassId
				WHERE MF.IsEncrypted = 1
		OPEN classall_cursor
			FETCH NEXT FROM classall_cursor INTO @MetaFieldName, @MultiLanguageValue, @MetaClassTable	
		WHILE(@@FETCH_STATUS = 0)
		BEGIN
			IF @MultiLanguageValue = 0
				SET @MetaQuery_tmp = '
					UPDATE '+@MetaClassTable+'
						SET ['+@MetaFieldName+'] = dbo.mdpfn_sys_EncryptDecryptString(['+@MetaFieldName+'], 0)
						WHERE [' + @MetaFieldName + '] IS NOT NULL'
			ELSE
				SET @MetaQuery_tmp = '
					UPDATE '+@MetaClassTable+'_Localization
						SET ['+@MetaFieldName+'] = dbo.mdpfn_sys_EncryptDecryptString(['+@MetaFieldName+'], 0)
						WHERE [' + @MetaFieldName + '] IS NOT NULL'
						
			EXEC(@MetaQuery_tmp)
			FETCH NEXT FROM classall_cursor INTO @MetaFieldName, @MultiLanguageValue, @MetaClassTable
		END
		CLOSE classall_cursor
		DEALLOCATE classall_cursor
	END
	EXEC mdpsp_sys_CloseSymmetricKey
END
GO

-- Set on the ALLOW_PAGE_LOCKS option
declare @index_name nvarchar(400),
		@table_name nvarchar(400);
declare list_index cursor for
select i.name, OBJECT_NAME(i.object_id) from sys.indexes i where i.is_unique = 0 and i.allow_page_locks = 0

open list_index
fetch next from list_index into @index_name, @table_name
while @@FETCH_STATUS = 0
begin
	exec('ALTER INDEX ' + @index_name + ' ON dbo.[' + @table_name + '] SET (ALLOW_PAGE_LOCKS = ON)')
	fetch next from list_index into @index_name, @table_name
end
close list_index
deallocate list_index
GO

-- Remove stored procedure [mdpsp_sys_RotateEncryptionKeys]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_RotateEncryptionKeys]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[mdpsp_sys_RotateEncryptionKeys]
GO

-- Need to drop these SP last and following the order
-- Remove function [mdpfn_sys_EncryptDecryptString]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpfn_sys_EncryptDecryptString]') AND OBJECTPROPERTY(id, N'IsScalarFunction') = 1) 
	DROP FUNCTION [dbo].[mdpfn_sys_EncryptDecryptString]
GO
-- Remove function [mdpfn_sys_EncryptDecryptString2]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpfn_sys_EncryptDecryptString2]') AND OBJECTPROPERTY(id, N'IsScalarFunction') = 1) 
	DROP FUNCTION [dbo].[mdpfn_sys_EncryptDecryptString2]
GO

-- Remove SP [mdpsp_sys_CloseSymmetricKey]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_CloseSymmetricKey]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[mdpsp_sys_CloseSymmetricKey]
GO
-- Remove SP [mdpsp_sys_OpenSymmetricKey]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_OpenSymmetricKey]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[mdpsp_sys_OpenSymmetricKey]
GO

-- Drop mediachase symmetric key
IF EXISTS (SELECT * FROM SYS.SYMMETRIC_KEYS WHERE NAME = 'Mediachase_ECF50_MDP_Key')
	DROP SYMMETRIC KEY [Mediachase_ECF50_MDP_Key]
GO
-- Drop mediachase certificate
IF EXISTS (SELECT * FROM SYS.CERTIFICATES WHERE NAME = 'Mediachase_ECF50_MDP')
	DROP CERTIFICATE [Mediachase_ECF50_MDP]
GO
-- Drop master key encryption
IF EXISTS (SELECT * FROM SYS.SYMMETRIC_KEYS WHERE NAME = 'MS_DatabaseMasterKey')
	DROP MASTER KEY
GO

--beginUpdatingtableAzureCompatible 
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'AzureCompatible')
BEGIN
	CREATE TABLE dbo.AzureCompatible (AzureCompatible bit)
	INSERT INTO dbo.AzureCompatible VALUES (1)
END
ELSE
	IF NOT EXISTS (SELECT * FROM dbo.AzureCompatible)
		INSERT INTO dbo.AzureCompatible VALUES (1)
	ELSE
		UPDATE dbo.AzureCompatible SET AzureCompatible = 1
GO 

-- Update all meta class SP to remove symmetric key in case the meta classes using encryption.
EXECUTE dbo.mdpsp_sys_CreateMetaClassProcedureAll
--endUpdatingtableAzureCompatible