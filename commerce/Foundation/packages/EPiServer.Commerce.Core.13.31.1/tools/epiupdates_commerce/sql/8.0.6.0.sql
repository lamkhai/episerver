--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 0, @patch int = 6
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

--Change ANSI_NULLS and QUOTED_IDENTIFIER to ON on all affected stored procedures and views
  SET NOCOUNT ON

  SET ANSI_NULLS ON
  SET QUOTED_IDENTIFIER ON

  --- Used in try/catch below
  DECLARE @ErrorMessage nvarchar(4000);
  DECLARE @ErrorSeverity int;
  DECLARE @ErrorState int;

  DECLARE @name sysname
  DECLARE @type char(2)
  DECLARE @objType nvarchar(50)
  DECLARE @createCommand nvarchar(max)
  DECLARE @dropCommand nvarchar(max)

  CREATE TABLE #ObjectsToBeRefreshed
  (
      name            sysname         NOT NULL PRIMARY KEY,
      id              int             NOT NULL,
      type            char(2)         NOT NULL,
      definition      nvarchar(max)   NULL,
      alterStatement  nvarchar(max)   NULL,
      processed       bit             NOT NULL
  )

  --- Build the list of objects that have quoted_identifier off
  INSERT INTO #ObjectsToBeRefreshed
  SELECT 
      so.name, 
      so.object_id, 
      so.type, 
      sm.definition, 
      NULL, 
      0
  FROM sys.objects so
      INNER JOIN sys.sql_modules sm
          ON so.object_id = sm.object_id
	  INNER JOIN sys.schemas sc
	      ON sc.schema_id = so.schema_id
  WHERE 
      (sm.uses_quoted_identifier = 0 
      OR sm.uses_ansi_nulls = 0)
      -- These are automatically generated SP, we will create them later
      AND so.name NOT LIKE 'mdpsp_avto_%'
	  AND sc.name = 'dbo'
  ORDER BY
      so.name

  -- Get the first object
  SELECT @name = MIN(name) FROM #ObjectsToBeRefreshed WHERE processed = 0

  WHILE (@name IS NOT NULL)
  BEGIN
    SELECT
        @createCommand = definition,
        @type = type
    FROM #ObjectsToBeRefreshed 
    WHERE name = @name

    --- Determine what type of object it is
    SET @objType = CASE @type
            WHEN 'P'  THEN 'PROCEDURE' 
            WHEN 'TF' THEN 'FUNCTION'
            WHEN 'IF' THEN 'FUNCTION'
            WHEN 'FN' THEN 'FUNCTION'
            WHEN 'V'  THEN 'VIEW'
            WHEN 'TR' THEN 'TRIGGER'
        END

    --- Create the drop command
    SET @dropCommand = 'DROP ' + @objType + ' ' + @name

    --- record the drop statement that we are going to execute
    UPDATE #ObjectsToBeRefreshed 
    SET 
        processed = 1, 
        alterStatement = @dropCommand 
    WHERE name = @name

    BEGIN TRANSACTION

    --- Drop the current proc
    EXEC sp_executesql @dropCommand

    BEGIN TRY

        EXEC sp_executesql @createCommand

        COMMIT

    END TRY
    BEGIN CATCH

        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        PRINT ' Unable to recreate ' + @name
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState, @name)

        ROLLBACK

    END CATCH   

    SELECT @name = MIN(name) FROM #ObjectsToBeRefreshed WHERE processed = 0
END

DROP TABLE #ObjectsToBeRefreshed

GO

EXEC mdpsp_sys_CreateMetaClassProcedureAll

GO
ALTER PROCEDURE [dbo].[ecf_OrderSearch]
(
	@SQLClause 					nvarchar(max),
	@MetaSQLClause 				nvarchar(max),
	@OrderBy 					nvarchar(max),
	@Namespace					nvarchar(1024) = N'',
	@Classes					nvarchar(max) = N'',
	@StartingRec 				int,
	@NumRecords   				int,
	@RecordCount                int OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @query_tmp nvarchar(max)
	DECLARE @FilterQuery_tmp nvarchar(max)
	DECLARE @TableName_tmp sysname
	DECLARE @SelectMetaQuery_tmp nvarchar(max)
	DECLARE @FromQuery_tmp nvarchar(max)
	DECLARE @FullQuery nvarchar(max)
	DECLARE @SelectQuery nvarchar(max)
	DECLARE @CountQuery nvarchar(max)

	-- 1. Cycle through all the available product meta classes
	--print 'Iterating through meta classes'
	DECLARE MetaClassCursor CURSOR READ_ONLY
	FOR SELECT TableName FROM MetaClass 
		WHERE Namespace like @Namespace + '%' AND ([Name] in (select Item from ecf_splitlist(@Classes)) or @Classes = '')
		and IsSystem = 0

	OPEN MetaClassCursor
	FETCH NEXT FROM MetaClassCursor INTO @TableName_tmp
	WHILE (@@fetch_status = 0)
	BEGIN 
		--print 'Metaclass Table: ' + @TableName_tmp
		set @Query_tmp = 'select META.ObjectId as ''Key'' from ' + @TableName_tmp + ' META'
		
		-- Add meta Where clause
		if(LEN(@MetaSQLClause)>0)
			set @query_tmp = @query_tmp + ' WHERE ' + @MetaSQLClause

		if(@SelectMetaQuery_tmp is null)
			set @SelectMetaQuery_tmp = @Query_tmp;
		else
			set @SelectMetaQuery_tmp = @SelectMetaQuery_tmp + N' UNION ALL ' + @Query_tmp;

	FETCH NEXT FROM MetaClassCursor INTO @TableName_tmp
	END
	CLOSE MetaClassCursor
	DEALLOCATE MetaClassCursor

	-- Create from command
	SET @FromQuery_tmp = N' INNER JOIN (select distinct U.[Key] from (' + @SelectMetaQuery_tmp + N') U) META ON OrderGroup.[OrderGroupId] = META.[Key] '

	set @FilterQuery_tmp = N' WHERE 1=1'
	-- add sql clause statement here, if specified
	if(Len(@SQLClause) != 0)
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND (' + @SqlClause + ')'
		
	if(Len(@OrderBy) = 0)
	begin
		set @OrderBy = ' OrderGroupId DESC'
	end

	set @SelectQuery = N'SELECT OrderGroupId'  + 
		' FROM dbo.OrderGroup OrderGroup ' + @FromQuery_tmp + @FilterQuery_tmp + ' ORDER BY ' + @OrderBy +
		' OFFSET '  + cast(@StartingRec as nvarchar(50)) + '  ROWS ' +
		' FETCH NEXT ' + cast(@NumRecords as nvarchar(50)) + ' ROWS ONLY ;';
	set @CountQuery= N'SET @RecordCount= (SELECT Count(1) FROM dbo.OrderGroup OrderGroup ' + @FromQuery_tmp + @FilterQuery_tmp +');';
	set @FullQuery =  @CountQuery+ @SelectQuery;

	--print @FullQuery
	exec sp_executesql @FullQuery, N'@RecordCount int output', @RecordCount = @RecordCount OUTPUT

	SET NOCOUNT OFF
END
GO
PRINT N'Refreshing [dbo].[ecf_Search_PaymentPlan]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_PaymentPlan]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_PurchaseOrder]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_PurchaseOrder]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_ShoppingCart]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_ShoppingCart]';


GO
 
GO 


--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 0, 6, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
