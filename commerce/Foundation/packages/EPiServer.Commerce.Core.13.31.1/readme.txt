EPiServer.Commerce.Core


INSTALLATION
============

Applying database transforms
----------------------------

Database transforms are never applied automatically when updating a package to avoid unintentional
changes, make sure you have a backup of the database before running the update command. The
Update-EPiDatabase will automatically detect all install packages that support the pattern for
transformation used by EPiServer.

- Open "Package Manager Console".
- Make sure "Default project" points to the web site.
- Execute Update-EPiDatabase in the console.

Important note: Update-EPiDatabase should only be run in context of front-end site. Do not run it for
Commerce Manager site.

TROUBLESHOOTING
===============

If you get issues running the site after upgrade, delete all files in the bin folder (always keep a backup
just in case) and rebuild the project to clean out old files that might be incompatible.

When you upgrading from older versions to Commerce 11 or later, the new promotion system is enabled by default.
To disable the new promotion system and continue use the legacy promotion system, you need to adding (or update
if it existed) config to configs/ecf.app.config
<add feature="WorkflowsVNext" state="Disabled" type="Mediachase.Commerce.Core.Features.WorkflowsVNext, Mediachase.Commerce" />


For more details, see the product specific information for Commerce on
http://world.episerver.com/installupdates

ADDITIONAL INFORMATION
======================

For additional information regarding what's new, please visit the following pages:

http://world.episerver.com/documentation/Release-Notes/?packageGroup=Commerce

http://world.episerver.com/documentation/Upgrading/EPiserver-Commerce/

http://world.episerver.com/releases/