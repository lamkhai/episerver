using EPiServer.Cms.Shell;
using EPiServer.Cms.UI.AspNetIdentity;
using EPiServer.Framework.Localization.XmlResources;
using EPiServer.Scheduler;
using EPiServer.Security;
using EPiServer.ServiceLocation;
using EPiServer.Web;
using EPiServer.Web.Routing;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;
using System.Collections.Specialized;
using System.Security.Claims;
using System.Text;

namespace CMS
{
    public class Startup
    {
        private readonly IWebHostEnvironment _webHostingEnvironment;

        public Startup(IWebHostEnvironment webHostingEnvironment)
        {
            _webHostingEnvironment = webHostingEnvironment;
        }

        public void ConfigureServices(IServiceCollection services)
        {
            if (_webHostingEnvironment.IsDevelopment())
            {
                AppDomain.CurrentDomain.SetData("DataDirectory", Path.Combine(_webHostingEnvironment.ContentRootPath, "App_Data"));

                services.Configure<SchedulerOptions>(options => options.Enabled = false);

                services.Configure<DisplayOptions>(options =>
                {
                    options
                    .Add("full", "/displayoptions/full", ContentAreaTags.FullWidth, "", "epi-icon__layout--full")
                    .Add("wide", "/displayoptions/wide", ContentAreaTags.TwoThirdsWidth, "", "epi-icon__layout--two-thirds")
                    .Add("narrow", "/displayoptions/narrow", ContentAreaTags.OneThirdWidth, "", "epi-icon__layout--one-third");
                });

                services.AddEmbeddedLocalization<Startup>();

                //services.AddLocalizationProvider<FileXmlLocalizationProvider,
                //                                 NameValueCollection>(o =>
                //                                 {
                //                                     o[FileXmlLocalizationProvider.PhysicalPathKey] = @"c:\temp\resourceFolder";
                //                                 });

                //services.AddFileBlobProvider("myFileBlobProvider", @"c:\path\to\file\blobs");
                //services.AddBlobProvider<MyCustomBlobProvider>("myCustomBlobProvider", defaultProvider: false);
                //services.Configure<MyCustomBlobProvider>(o =>
                //{
                //    o.AddProvider<MyCustomBlobProvider>("anotherCustomBlobProvider");
                //    o.DefaultProvider = "anotherCustomBlobProvider";
                //});

                ConfigureAzureADService(services);
            }

            services
                .AddCmsAspNetIdentity<ApplicationUser>()
                .AddCms()
                .AddAdminUserRegistration()
                .AddEmbeddedLocalization<Startup>()
                .AddCmsTagHelpers();
        }

        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }

            app.UseStaticFiles();
            app.UseRouting();
            app.UseAuthentication();
            app.UseAuthorization();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapContent();
            });
        }

        private void ConfigureAzureADService(IServiceCollection services)
        {
            services
                .AddAuthentication(options =>
                {
                    options.DefaultAuthenticateScheme = "azure-cookie";
                    options.DefaultChallengeScheme = "azure";
                })
                .AddCookie("azure-cookie", options =>
                {
                    options.Events.OnSignedIn = async ctx =>
                    {
                        if (ctx.Principal?.Identity is ClaimsIdentity claimsIdentity)
                        {
                            // Syncs user and roles so they are available to the CMS
                            var synchronizingUserService = ctx.HttpContext.RequestServices.GetRequiredService<ISynchronizingUserService>();
                            await synchronizingUserService.SynchronizeAsync(claimsIdentity);
                        }
                    };
                })
                .AddOpenIdConnect("azure", options =>
                {
                    options.SignInScheme = "azure-cookie";
                    options.SignOutScheme = "azure-cookie";
                    options.ResponseType = OpenIdConnectResponseType.Code;
                    options.CallbackPath = "/signin-oidc";
                    options.UsePkce = true;

                    // If Azure AD is register for multi-tenant
                    //options.Authority = "https://login.microsoftonline.com/" + "common" + "/v2.0";
                    options.Authority = "https://login.microsoftonline.com/" + "tenant id" + "/v2.0";
                    options.ClientId = "client id";

                    options.Scope.Clear();
                    options.Scope.Add(OpenIdConnectScope.OpenIdProfile);
                    options.Scope.Add(OpenIdConnectScope.OfflineAccess);
                    options.Scope.Add(OpenIdConnectScope.Email);
                    options.MapInboundClaims = false;

                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        RoleClaimType = ClaimTypes.Role,
                        NameClaimType = "preferred_username",
                        ValidateIssuer = false
                    };

                    options.Events.OnRedirectToIdentityProvider = ctx =>
                    {
                        // Prevent redirect loop
                        if (ctx.Response.StatusCode == 401)
                        {
                            ctx.HandleResponse();
                        }

                        return Task.CompletedTask;
                    };

                    options.Events.OnAuthenticationFailed = context =>
                    {
                        context.HandleResponse();
                        context.Response.BodyWriter.WriteAsync(Encoding.ASCII.GetBytes(context.Exception.Message));
                        return Task.CompletedTask;
                    };
                });
        }
    }
}

public static class ContentAreaTags
{
    public const string FullWidth = "Full";
    public const string TwoThirdsWidth = "Wide";
    public const string HalfWidth = "Half";
    public const string OneThirdWidth = "Narrow";
}