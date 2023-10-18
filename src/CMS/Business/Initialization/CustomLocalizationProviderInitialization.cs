using EPiServer.Framework.Initialization;
using EPiServer.Framework;
using EPiServer.ServiceLocation;

namespace CMS.Business.Initialization;

[InitializableModule]
[ModuleDependency(typeof(FrameworkInitialization))]
public class CustomLocalizationProviderInitialization : IConfigurableModule
{
    public void ConfigureContainer(ServiceConfigurationContext context)
    {
        // ClassInMyAssembly can be any class in the Assembly where the resources are embedded
        //context.Services.AddEmbeddedLocalization<ClassInMyAssembly>();
    }

    public void Initialize(InitializationEngine context) { }
    public void Uninitialize(InitializationEngine context) { }
}