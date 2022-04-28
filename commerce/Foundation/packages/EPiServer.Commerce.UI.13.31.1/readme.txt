EPiServer.Commerce.UI
- Not part of public API

MIGRATION STEPS
===============

This package contains some migration steps, that are required for the site to run properly. They will
fix certain issues with the content that cannot be done by sql scripts alone. Until all migration steps
are completed successfully, all requests to the site will be redirected to a migration page. From that
page you can start the migration and see information about the current progress. In order to access it
you need to be part of the "CommerceAdmins" role. When all steps have been completed, everything will
return to normal.

It is possible to configure the site to start the migration automatically during initialization.
That is done by adding an app setting called "AutoMigrateEPiServer" and setting the value to "true".
However, until all steps have been completed, any requests will still be redirected to the migration page.

ADDITIONAL INFORMATION
======================

For additional information regarding what's new, please visit the following pages:

http://world.episerver.com/documentation/Release-Notes/?packageGroup=Commerce

http://world.episerver.com/documentation/Upgrading/EPiserver-Commerce/

http://world.episerver.com/releases/