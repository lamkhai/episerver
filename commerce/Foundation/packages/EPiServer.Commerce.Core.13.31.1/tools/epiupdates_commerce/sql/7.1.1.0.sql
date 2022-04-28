--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 1, @patch int = 1    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationSave]
GO

CREATE PROCEDURE [dbo].[PromotionInformationSave]
    @OrderFormId INT,
    @PromotionInformation dbo.udttPromotionInformation READONLY
AS
BEGIN

    DELETE FROM dbo.PromotionInformation WHERE OrderFormId = @OrderFormId;

    INSERT INTO dbo.PromotionInformation(OrderFormId, ContentLink, PromotionLink, SavedAmount, RewardType, Description, DiscountType, AdditionalInformation)
    SELECT @OrderFormId, ContentLink, PromotionLink, SavedAmount, RewardType, Description, DiscountType, AdditionalInformation
    FROM @PromotionInformation

END

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Pricing_SetCatalogEntryPrices]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Pricing_SetCatalogEntryPrices] 
GO

create procedure dbo.ecf_Pricing_SetCatalogEntryPrices
    @CatalogKeys udttCatalogKey readonly,
    @PriceValues udttCatalogEntryPrice readonly
as
begin
    begin try
        declare @initialTranCount int = @@TRANCOUNT
        if @initialTranCount = 0 begin transaction

        delete pv
        from @CatalogKeys ck
        join dbo.PriceGroup pg on ck.ApplicationId = pg.ApplicationId and ck.CatalogEntryCode = pg.CatalogEntryCode
        join dbo.PriceValue pv on pg.PriceGroupId = pv.PriceGroupId

        merge into dbo.PriceGroup tgt
        using (select distinct ApplicationId, CatalogEntryCode, MarketId, CurrencyCode, PriceTypeId, PriceCode from @PriceValues) src
        on (    tgt.ApplicationId = src.ApplicationId
            and tgt.CatalogEntryCode = src.CatalogEntryCode
            and tgt.MarketId = src.MarketId
            and tgt.CurrencyCode = src.CurrencyCode
            and tgt.PriceTypeId = src.PriceTypeId
            and tgt.PriceCode = src.PriceCode)
        when matched then update set Modified = GETUTCDATE()
        when not matched then insert (Created, Modified, ApplicationId, CatalogEntryCode, MarketId, CurrencyCode, PriceTypeId, PriceCode)
            values (GETUTCDATE(), GETUTCDATE(), src.ApplicationId, src.CatalogEntryCode, src.MarketId, src.CurrencyCode, src.PriceTypeId, src.PriceCode);

        insert into dbo.PriceValue (PriceGroupId, ValidFrom, ValidUntil, MinQuantity, MaxQuantity, UnitPrice)
        select pg.PriceGroupId, src.ValidFrom, src.ValidUntil, src.MinQuantity, src.MaxQuantity, src.UnitPrice
        from @PriceValues src
        left outer join PriceGroup pg
            on  src.ApplicationId = pg.ApplicationId
            and src.CatalogEntryCode = pg.CatalogEntryCode
            and src.MarketId = pg.MarketId
            and src.CurrencyCode = pg.CurrencyCode
            and src.PriceTypeId = pg.PriceTypeId
            and src.PriceCode = pg.PriceCode

        delete tgt
        from dbo.PriceGroup tgt
        join @CatalogKeys ck on tgt.ApplicationId = ck.ApplicationId and tgt.CatalogEntryCode = ck.CatalogEntryCode
        left join dbo.PriceValue pv on pv.PriceGroupId = tgt.PriceGroupId
        where pv.PriceGroupId is null

        if @initialTranCount = 0 commit transaction
    end try
    begin catch
        declare @msg nvarchar(4000), @severity int, @state int
        select @msg = ERROR_MESSAGE(), @severity = ERROR_SEVERITY(), @state = ERROR_STATE()
        if @initialTranCount = 0 rollback transaction
        raiserror(@msg, @severity, @state)
    end catch
end

GO

ALTER TABLE [dbo].[PriceGroup] DROP CONSTRAINT [PK_PriceGroup]
GO

ALTER TABLE [dbo].[PriceGroup] ADD  CONSTRAINT [PK_PriceGroup] PRIMARY KEY CLUSTERED 
(
    [CatalogEntryCode] ASC,
    [ApplicationId] ASC,
    [MarketId] ASC,
    [CurrencyCode] ASC,
    [PriceTypeId] ASC,
    [PriceCode] ASC
)
GO

IF EXISTS(SELECT * FROM sys.indexes WHERE object_id = object_id('dbo.ShipmentDiscount') AND NAME ='IX_ShipmentDiscount_ShipmentId')
    DROP INDEX IX_ShipmentDiscount_ShipmentId ON dbo.ShipmentDiscount;
GO

CREATE NONCLUSTERED INDEX [IX_ShipmentDiscount_ShipmentId] 
    ON [dbo].[ShipmentDiscount]([ShipmentId] ASC);
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 1, 1, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
