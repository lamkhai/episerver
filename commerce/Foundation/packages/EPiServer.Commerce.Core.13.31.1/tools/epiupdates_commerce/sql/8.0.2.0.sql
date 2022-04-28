--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 0, @patch int = 2    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

PRINT N'Dropping [dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment];


GO
PRINT N'Dropping [dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment];


GO
PRINT N'Dropping [dbo].[fn_UriSegmentExistsOnSiblingNodeOrEntry]...';


GO
IF EXISTS (SELECT * FROM Information_schema.Routines WHERE Specific_schema = 'dbo' AND specific_name = 'fn_UriSegmentExistsOnSiblingNodeOrEntry' AND Routine_Type = 'FUNCTION' ) DROP FUNCTION [dbo].[fn_UriSegmentExistsOnSiblingNodeOrEntry];


GO

 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 0, 2, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
