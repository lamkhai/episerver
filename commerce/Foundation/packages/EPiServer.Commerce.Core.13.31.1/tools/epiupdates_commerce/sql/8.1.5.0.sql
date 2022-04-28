--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 1, @patch int = 5    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

PRINT N'Updating outdated rows in table [dbo].Country...';
GO

Update Country Set Name = N'Cote d''Ivoire' Where Name = N'Cote D\Ivoire'
GO
Update Country Set Name = N'Congo, Democratic Republic of the' Where Name = N'Congo, the Democratic Republic of the'
GO
Update Country Set Name = N'Congo, Republic of the' Where Name = N'Congo'
GO
Update Country Set Name = N'Cabo Verde' Where Name = N'Cape Verde'
GO
Update Country Set Name = N'Lao People''s Democratic Republic' Where Name = N'Lao People\s Democratic Republic'
GO
Update Country Set Name = N'Libya' Where Name = N'Libyan Arab Jamahiriya'
GO
Update Country Set Name = N'Macedonia, Republic of' Where Name = N'Macedonia, the Former Yugoslav Republic of'
GO
Update Country Set Name = N'Korea, Democratic People''s Republic of' Where Name = N'Korea, Democratic People\s Republic of'
GO
Update Country Set Name = N'Palestine, State of' Where Name = N'Palestinian Territory, Occupied'
GO
Update Country Set Name = N'Serbia' Where Name = N'Serbia and Montenegro'
GO
Update Country Set Name = N'Saint Helena, Ascension and Tristan da Cunha' Where Name = N'Saint Helena'
GO
If Not Exists(Select * From Country Where Name = N'Montenegro')
Begin
	Insert Into Country ([Name], [Ordering], [Visible], [Code]) Values (N'Montenegro', 0, 1, N'MNE')
End
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 1, 5, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
