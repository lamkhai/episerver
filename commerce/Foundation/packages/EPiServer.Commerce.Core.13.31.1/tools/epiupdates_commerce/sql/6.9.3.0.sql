--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 9, @patch int = 3    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

ALTER PROCEDURE [dbo].[ecf_ShippingMethod_Market]
    @ApplicationId uniqueidentifier,
    @MarketId nvarchar(10) = null,
    @ReturnInactive bit = 0
AS
BEGIN
    declare @_shippingMethodIds as table (ShippingMethodId uniqueidentifier)
    insert into @_shippingMethodIds
    select SM.ShippingMethodId
        from [ShippingMethod] SM
        inner join [MarketShippingMethods] MSM
          on SM.ShippingMethodId = MSM.ShippingMethodId
        inner join [Warehouse] W
          on W.ApplicationId = SM.ApplicationId
        where COALESCE(@MarketId, MSM.MarketId) = MSM.MarketId
          and ((SM.[IsActive] = 1) or (@ReturnInactive = 1))
          and SM.ApplicationId = @ApplicationId
          and (SM.Name <> 'In Store Pickup' or W.IsPickupLocation = 1)

    select * from [ShippingOption] where [ApplicationId] = @ApplicationId
    
    select SOP.* from [ShippingOptionParameter] SOP 
    inner join [ShippingOption] SO on SOP.[ShippingOptionId]=SO.[ShippingOptionId]
        where SO.[ApplicationId] = @ApplicationId
        
    select distinct SM.* from [ShippingMethod] SM where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds) order by SM.Ordering
    select * from [ShippingMethodParameter] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
    select * from [ShippingMethodCase] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
    select * from [ShippingCountry] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
    select * from [ShippingRegion] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
    
    select * from [ShippingPaymentRestriction]
        where 
            ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
            and
            [RestrictShippingMethods] = 0
    select * from [Package] where [ApplicationId] = @ApplicationId

    select SP.* from [ShippingPackage] SP 
    inner join [Package] P on SP.[PackageId]=P.[PackageId]
        where P.[ApplicationId] = @ApplicationId
	select * from [MarketShippingMethods] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
END
GO

ALTER PROCEDURE [dbo].[ecf_ShippingMethod_Language]
	@ApplicationId uniqueidentifier,
	@LanguageId nvarchar(10) = null,
	@ReturnInactive bit = 0
AS
BEGIN
    declare @_shippingMethodIds as table (ShippingMethodId uniqueidentifier)
    insert into @_shippingMethodIds
	select ShippingMethodId 
		from ShippingMethod 
		where COALESCE(@LanguageId, LanguageId) = LanguageId 
		and (([IsActive] = 1) or @ReturnInactive = 1) 
		and ApplicationId = @ApplicationId

	select * from [ShippingOption] where [ApplicationId] = @ApplicationId
	select SOP.* from [ShippingOptionParameter] SOP 
	inner join [ShippingOption] SO on SOP.[ShippingOptionId]=SO.[ShippingOptionId]
		where SO.[ApplicationId] = @ApplicationId
	select distinct SM.* from [ShippingMethod] SM 
	inner join [Warehouse] W on SM.ApplicationId = W.ApplicationId
		where COALESCE(@LanguageId, LanguageId) = LanguageId and ((SM.[IsActive] = 1) or @ReturnInactive = 1) and SM.ApplicationId = @ApplicationId
			and (SM.Name <> 'In Store Pickup' or W.IsPickupLocation = 1) 
		order by SM.Ordering
	select * from [ShippingMethodParameter] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
	select * from [ShippingMethodCase] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
	select * from [ShippingCountry] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
	select * from [ShippingRegion] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
	select * from [ShippingPaymentRestriction] 
		where 
			(ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds) )
				and
			[RestrictShippingMethods] = 0
	select * from [Package] where [ApplicationId] = @ApplicationId
	select SP.* from [ShippingPackage] SP 
	inner join [Package] P on SP.[PackageId]=P.[PackageId]
		where P.[ApplicationId] = @ApplicationId
	select * from [MarketShippingMethods] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
END
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 9, 3, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
