EPiServer.Commerce.Azure


Installation
============

During installation of this nuget package, any existing files and directory have been overwritten with new ones.

Applying database transforms
============================

Database transforms are never applied automatically when updating a package to avoid unintentional changes, make sure you have a backup of the database before running the update command. 
The Update-EPiDatabase will automatically detect all install packages that support the pattern for transformation used by EPiServer.

- Open "Package Manager Console".
- Make sure "Default project" points to the web site.
- Write Update-EPiDatabase in the console and press Enter.

Important note: Update-EPiDatabase should only be run in context of front-end site. Do not run it for Commerce Manager site.

Updating database manually
==========================

Some database transforms have special requirements and they will need to be applied manually.
Execute the PrepareForSqlAzure.sql in context of Commerce database.

It is recommended to backup databases before applying any database transformations.


Mapping of BLOB and event providers
===================================

Open EPiServerFramework.config and note configuration under the episerver.framework section to map blob/event providers to Azure
<blob defaultProvider="azureblobs">
    <providers>
        <add name="azureblobs" type="EPiServer.Azure.Blobs.AzureBlobProvider,EPiServer.Azure" connectionStringName="EPiServerAzureBlobs" container="mysitemedia"/>
    </providers> 
</blob> 
<event defaultProvider="azureevents">
    <providers>
        <add name="azureevents" type="EPiServer.Azure.Events.AzureEventProvider,EPiServer.Azure" connectionStringName="EPiServerAzureEvents" topic="mysiteevents"/>
    </providers>
</event>

Update connection strings for Blobs and Events
==============================================

- Open web.config, connectionStrings section. Edit the connection string named EPiServerAzureBlobs (matching the setting in EPiServerFramework.config, episerver.framework section for the provider). 
  The connection string to the BLOB storage should be in the format: 
  connectionString="DefaultEndpointsProtocol=https;AccountName=<name>;AccountKey=<key>", where <name> is what was given in section Create Azure Storage, 
  and <key>. You can find the Storage Account access Keys and connection strings under the settings section, "Access Keys" of the Storage Account in the Azure Portal.
- Edit connection string named EPiServerAzureEvents (matching the setting in episerver.framework, too). This connection string can be copied from your Azure Services Bus
  found under the settings section, "Shared access policies" -> "RootManageSharedAccessKey" in the Azure Portal.  

Important note: After changing connection string for Blobs and Events, make sure your site is migrated and works before moving to next step.

Update Lucene Search configuration
==================================

If you are not using LuceneSearchProvider as default search provide, don't need to update this config.
And you're using LuceneSearchProvider as default search provider, you need to change using LuceneAzureSearchProvider instead:
- Open Mediachase.Search.config, in SearchProviders, set the attribute defaultProvider to LuceneAzureSearchProvider.
- Set your connectionStringName so that the provider has name="LuceneAzureSearchProvider" matching with your Azure Storage name (in web.config, connectionStrings section) 
  and storage="<container you want to index>"
- Set your connectionStringName in Indexers tab matching with your Azure Storage name (in web.config, connectionStrings section) and basePath is "<container you want to store build information>"

Update connection string to Azure SQL Database
==============================================

Open web.config, connectionStrings section, change the connection string for EPiServerDB, EcfSqlConnection to the connection string from Azure SQL Database. 
Remember to keep the setting MultipleActiveResultSets=true and note that in EPiServer Commerce, TWO databases need to be migrated to Azure SQL Database.

Update Commerce Manager Link to Commerce Manager site
=====================================================

For the front-end site to be able to use the Commerce Manager site in the EPiServer UI, update the CommerceManagerLink key under AppSettings in web.config. 


Following "Deploying Commerce to Azure Web Apps" guide on https://world.episerver.com/documentation/developer-guides/commerce/deployment/deploying-commerce-to-azure-web-apps/ for more information.