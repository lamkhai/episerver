--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 9, @minor int = 1, @patch int = 8    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

IF EXISTS (SELECT 1 FROM sys.types WHERE is_table_type = 1 AND name =N'udttSerializableCart')
    DROP TYPE [dbo].[udttSerializableCart];
GO

GO
PRINT N'Creating [dbo].[udttSerializableCart]...';
GO
CREATE TYPE [dbo].[udttSerializableCart] AS TABLE (
	[CartId]				  [INT]                NOT NULL,
    [CustomerId]			  [UNIQUEIDENTIFIER]   NOT NULL,
    [Name]					  [NVARCHAR](128)	   NULL,
    [MarketId]				  [NVARCHAR](16)       NOT NULL,
	[Created]				  [DATETIME]		   NOT NULL,
	[Modified]				  [DATETIME]		   NULL,
    [Data]					  [NVARCHAR](MAX)      NULL);
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_SerializableCart_SaveBatch]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
    DROP PROCEDURE [dbo].[ecf_SerializableCart_SaveBatch] 
GO

GO
CREATE PROCEDURE [dbo].[ecf_SerializableCart_SaveBatch] 
	@OrderData [dbo].[udttSerializableCart] READONLY
AS
BEGIN
  UPDATE SerializableCart
  SET 			
		[CustomerId] = t2.CustomerId,
		[Name] = t2.Name,
		[MarketId] = t2.MarketId,
		[Created] = t2.Created,
		[Modified] = t2.Modified,
		[Data] = t2.Data
 FROM SerializableCart t1
 INNER JOIN @OrderData t2 ON t1.CartId = t2.CartId
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(9, 1, 8, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
