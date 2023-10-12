using EPiServer.Web;

namespace CMS.Business.Channels;

public class MobileResolution : IDisplayResolution
{
    public int Height
    {
        get { return 568; }
    }

    public string Id
    {
        get { return GetType().FullName; }
    }

    public string Name
    {
        get { return "Mobile (320x568)"; }
    }

    public int Width
    {
        get { return 320; }
    }
}