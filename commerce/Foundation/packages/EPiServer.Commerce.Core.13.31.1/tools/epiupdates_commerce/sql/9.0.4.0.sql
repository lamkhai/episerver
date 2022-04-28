--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 9, @minor int = 0, @patch int = 4    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[ApplicationLog]...';

GO
ALTER TABLE [dbo].[ApplicationLog] ALTER COLUMN [Username] NVARCHAR (256) NOT NULL;

GO

PRINT N'Dropping [dbo].[ecf_Order_ReturnReasonsDictionairy]...';
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Order_ReturnReasonsDictionairy]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Order_ReturnReasonsDictionairy];
GO

PRINT N'Dropping [dbo].[ecf_Order_ReturnReasonsDictionairyId]...';
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Order_ReturnReasonsDictionairyId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Order_ReturnReasonsDictionairyId];
GO

PRINT N'Dropping [dbo].[ecf_Order_ReturnReasonsDictionairyName]...';
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Order_ReturnReasonsDictionairyName]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Order_ReturnReasonsDictionairyName];
GO

PRINT N'Creating [dbo].[ecf_Order_ReturnReasonsDictionary]...';

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Order_ReturnReasonsDictionary]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Order_ReturnReasonsDictionary];
GO

CREATE PROCEDURE [dbo].[ecf_Order_ReturnReasonsDictionary]
	@ReturnInactive bit = 0
 AS
 BEGIN
	SELECT * FROM dbo.ReturnReasonDictionary RRD
	WHERE (([Visible] = 1) or @ReturnInactive = 1)
	ORDER BY RRD.[Ordering], RRD.[ReturnReasonText]
END
GO

PRINT N'Creating [dbo].[ecf_Order_ReturnReasonsDictionaryId]...';

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Order_ReturnReasonsDictionaryId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Order_ReturnReasonsDictionaryId];
GO

CREATE PROCEDURE [dbo].[ecf_Order_ReturnReasonsDictionaryId]
	@ReturnReasonId int
 AS
 BEGIN
	SELECT [ReturnReasonId]
		  ,[ReturnReasonText]
		  ,[Ordering]
		  ,[Visible]
	FROM dbo.ReturnReasonDictionary
	WHERE ReturnReasonId = @ReturnReasonId
END
GO
PRINT N'Creating [dbo].[ecf_Order_ReturnReasonsDictionaryName]...';

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Order_ReturnReasonsDictionaryName]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Order_ReturnReasonsDictionaryName];
GO

CREATE PROCEDURE [dbo].[ecf_Order_ReturnReasonsDictionaryName]
	@ReturnReasonName nvarchar(50)
 AS
 BEGIN
	SELECT [ReturnReasonId]
		  ,[ReturnReasonText]
	FROM dbo.ReturnReasonDictionary
	WHERE ReturnReasonText = @ReturnReasonName
END
GO
PRINT N'Refreshing [dbo].[ecf_ApplicationLog]...';

GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_ApplicationLog]';

GO
PRINT N'Refreshing [dbo].[ecf_ApplicationLog_DeletedEntries]...';

GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_ApplicationLog_DeletedEntries]';

GO
PRINT N'Refreshing [dbo].[ecf_ApplicationLog_LogId]...';

GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_ApplicationLog_LogId]';

GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(9, 0, 4, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 