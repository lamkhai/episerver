--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 7, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Starting rebuilding table [dbo].[SerializableCart]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_SerializableCart] (
    [CartId]     INT              IDENTITY (1, 1) NOT NULL,
    [CustomerId] UNIQUEIDENTIFIER NOT NULL,
    [Name]       NVARCHAR (128)   NULL,
    [MarketId]   NVARCHAR (16)    CONSTRAINT [DF_SerializableCart_MarketId] DEFAULT ('DEFAULT') NOT NULL,
    [Created]    DATETIME         NOT NULL,
    [Modified]   DATETIME         NULL,
    [Data]       NVARCHAR (MAX)   NULL,
    CONSTRAINT [tmp_ms_xx_constraint_PK_SerializableCart1] PRIMARY KEY CLUSTERED ([CartId] ASC)
);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[SerializableCart])
    BEGIN
        SET IDENTITY_INSERT [dbo].[tmp_ms_xx_SerializableCart] ON;
        INSERT INTO [dbo].[tmp_ms_xx_SerializableCart] ([CartId], [CustomerId], [Name], [Created], [Modified], [Data])
        SELECT   [CartId],
                 [CustomerId],
                 [Name],
                 [Created],
                 [Modified],
                 [Data]
        FROM     [dbo].[SerializableCart]
        ORDER BY [CartId] ASC;
        SET IDENTITY_INSERT [dbo].[tmp_ms_xx_SerializableCart] OFF;
    END

DROP TABLE [dbo].[SerializableCart];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_SerializableCart]', N'SerializableCart';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_SerializableCart1]', N'PK_SerializableCart', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Creating [dbo].[SerializableCart].[IDX_SerializableCart_Indexed_CustomerId_Name]...';


GO
CREATE NONCLUSTERED INDEX [IDX_SerializableCart_Indexed_CustomerId_Name]
    ON [dbo].[SerializableCart]([CustomerId] ASC, [Name] ASC);


GO
PRINT N'Creating [dbo].[SerializableCart].[IDX_SerializableCart_Indexed_MarketId]...';


GO
CREATE NONCLUSTERED INDEX [IDX_SerializableCart_Indexed_MarketId]
    ON [dbo].[SerializableCart]([MarketId] ASC);


GO

PRINT N'Migrate data for [dbo].[SerializableCart].[MarketId]';


GO
UPDATE	[dbo].[SerializableCart]
SET		[MarketId] = SUBSTRING(
							[Data],
							CHARINDEX('"market":"', [Data]) + LEN('"market":"'),
							CHARINDEX('"', [Data], CHARINDEX('"market":"', [Data]) + LEN('"market":"')) - CHARINDEX('"market":"', [Data]) - LEN('"market":"')
							)
WHERE	[MarketId] = 'DEFAULT'

GO

PRINT N'Altering [dbo].[ecf_SerializableCart_FindCarts]...';


GO
ALTER PROCEDURE [dbo].[ecf_SerializableCart_FindCarts]
	@CartId INT = NULL,
	@CustomerId UNIQUEIDENTIFIER = NULL,
	@Name NVARCHAR (128) = NULL,
    @MarketId NVARCHAR (16) = NULL,
	@CreatedFrom DateTime = NULL,
	@CreatedTo DateTime = NULL,
	@StartingRecord INT = NULL,
	@RecordsToRetrieve INT = NULL
AS
BEGIN
	WITH Paging AS 
	(
		SELECT CartId, Created, Modified, [Data], 
			   ROW_NUMBER() OVER (ORDER BY CartId DESC) AS RowNum
		FROM SerializableCart
		WHERE (@CartId IS NULL OR CartId = @CartId)
			AND (@CustomerId IS NULL OR CustomerId = @CustomerId)
			AND (@Name IS NULL OR Name = @Name)
            AND (@MarketId IS NULL OR MarketId = @MarketId)
			AND (@CreatedFrom IS NULL OR Created >= @CreatedFrom)
			AND (@CreatedTo IS NULL OR Created <= @CreatedTo)
	)
	SELECT CartId, Created, Modified, [Data]
	FROM 
		Paging
	WHERE
		RowNum BETWEEN @StartingRecord AND @StartingRecord + @RecordsToRetrieve	
END
GO
PRINT N'Altering [dbo].[ecf_SerializableCart_Load]...';


GO
ALTER PROCEDURE [dbo].[ecf_SerializableCart_Load]
	@CartId INT = NULL,
	@CustomerId UNIQUEIDENTIFIER = NULL,
	@Name NVARCHAR (128) = NULL,
	@MarketId NVARCHAR (16) = NULL
AS
BEGIN
	SELECT CartId, Created, Modified, [Data]
	FROM SerializableCart
	WHERE (@CartId IS NULL OR CartId = @CartId)
		AND (@CustomerId IS NULL OR CustomerId = @CustomerId)
		AND (@Name IS NULL OR Name = @Name)
        AND (@MarketId IS NULL OR MarketId = @MarketId)
END
GO
PRINT N'Altering [dbo].[ecf_SerializableCart_Save]...';


GO
ALTER PROCEDURE [dbo].[ecf_SerializableCart_Save]
	@CartId INT,
	@CustomerId UNIQUEIDENTIFIER,
	@Name NVARCHAR(128),
    @MarketId NVARCHAR(16),
	@Created DATETIME,
	@Modified DATETIME,
	@Data NVARCHAR(MAX)
AS
BEGIN
	IF(@CartId <= 0)
	BEGIN
		INSERT INTO SerializableCart(CustomerId, Name, MarketId, Created, Modified, [Data])
		VALUES (@CustomerId, @Name, @MarketId, @Created, @Modified, @Data)

		SET @CartId = SCOPE_IDENTITY();
	END
	ELSE
	BEGIN
		UPDATE SerializableCart
		SET 			
			CustomerId = @CustomerId,
			Name = @Name,
            MarketId = @MarketId,
			Created = @Created,
			Modified = @Modified,
			[Data] = @Data
		WHERE CartId = @CartId
	END

	SELECT @CartId
END
GO
PRINT N'Refreshing [dbo].[ecf_SerializableCart_Delete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_SerializableCart_Delete]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 7, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
