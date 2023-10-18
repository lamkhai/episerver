using EPiServer.Cms.Shell;
using EPiServer.Cms.UI.AspNetIdentity;
using EPiServer.Framework.Localization.XmlResources;
using EPiServer.Scheduler;
using EPiServer.ServiceLocation;
using EPiServer.Web;
using EPiServer.Web.Routing;
using System.Collections.Specialized;

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

                services.AddLocalizationProvider<FileXmlLocalizationProvider,
                                                 NameValueCollection>(o =>
                                                 {
                                                     o[FileXmlLocalizationProvider.PhysicalPathKey] = @"c:\temp\resourceFolder";
                                                 });
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
    }
}

public static class ContentAreaTags
{
    public const string FullWidth = "Full";
	 public const string TwoThirdsWidth = "Wide";
	 public const string HalfWidth = "Half";
	 public const string OneThirdWidth = "Narrow";
}