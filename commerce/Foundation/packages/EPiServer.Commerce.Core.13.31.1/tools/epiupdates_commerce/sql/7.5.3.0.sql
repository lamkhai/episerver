--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 5, @patch int = 3    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mc_OrderGroupNotesUpdate]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mc_OrderGroupNotesUpdate] 
GO

CREATE PROCEDURE [dbo].[mc_OrderGroupNotesUpdate]
@OrderGroupNotes udttOrderGroupNote readonly
AS
BEGIN
SET NOCOUNT ON;

DELETE FROM OrderGroupNote WHERE OrderNoteId IN
(SELECT n.OrderNoteId FROM OrderGroupNote n INNER JOIN @OrderGroupNotes ogn ON ogn.OrderGroupId = n.OrderGroupId AND ogn.OrderNoteId <> n.OrderNoteId)

MERGE dbo.OrderGroupNote AS T
USING @OrderGroupNotes AS S
ON T.OrderNoteId = S.OrderNoteId
WHEN NOT MATCHED BY TARGET
	THEN INSERT (
		[OrderGroupId],
		[CustomerId],
		[Title],
		[Type],
		[Detail],
		[Created],
		[LineItemId])
	VALUES(S.OrderGroupId,
		S.CustomerId,
		S.Title,
		S.Type,
		S.Detail,
		S.Created,
		S.LineItemId)
WHEN MATCHED THEN 
UPDATE SET
	[OrderGroupId] = S.OrderGroupId,
	[CustomerId] = S.CustomerId,
	[Title] = S.Title,
	[Type] = S.Type,
	[Detail] = S.Detail,
	[Created] = S.Created,
	[LineItemId] = S.LineItemId;
END

GO 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 5, 3, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
