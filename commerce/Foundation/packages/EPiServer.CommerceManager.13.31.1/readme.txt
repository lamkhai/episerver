EPiServer.CommerceManager
- Not part of public API

IMPORTANT: Sites installed with Deployment center
=================================================

This information is only valid the first time the EPiServer.CommerceManager package are added on a Commerce Manager site, which was created using Deployment Center.

During installation of this nuget package, any existing Apps directory have been overwritten with new files.

If you have the installed Commerce Manager with Deployment Center, you will need to go to your IIS and remove the virtual directory
for the "Apps" folder so that it from now on will use the Apps folder in the root of the site.

Any modification made to the content of the virtual directory will have to be remade in the new location.

TROUBLESHOOTING
===============

If you get issues running the site after upgrade, delete all files in the bin folder (always keep a backup
just in case) and rebuild the project to clean out old files that might be incompatible.

For more details, see the product specific information for Commerce on
http://world.episerver.com/installupdates

REMOVE EPISERVER.SHELL CONFIGURATION
====================================

In EPiServer 10, EPiServer.Shell is moved from EPiServer.Framework to EPiServer.CMS.UI.Core package. By default Commerce Manager does not have dependencies on
EPiServer.CMS.UI.Core, therefore the EPiServer.Shell configuration in web.config can be removed manually. However, if you use EPiServer.CMS.UI.Core for any reason, 
those settings should be left as-is.
 
UPDATE SEARCH INDEX FOLDER
==========================

If you are upgrading an existing Commerce Manager site, this step can be skipped.

This package installation sets the search index folder to [appDataPath]\Search\ECApplication\.
[appDataPath] is a placeholder which is set in the appData basePath attribute in the episerver.framework section of the web.config.
It is required for this site (Commerce Manager) and front-end site to have same search index folder.
To make sure search works correctly, you need to update the appData basePath to point to the same absolute location of your appData basePath in your frontend server configuration.

ADDITIONAL INFORMATION
======================

For additional information regarding what's new, please visit the following pages:

http://world.episerver.com/documentation/Release-Notes/?packageGroup=Commerce

http://world.episerver.com/documentation/Upgrading/EPiserver-Commerce/

http://world.episerver.com/releases/

