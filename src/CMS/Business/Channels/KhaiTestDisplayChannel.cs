using EPiServer.Framework.Web;
using EPiServer.Web;

namespace CMS.Business.Channels;

public class KhaiTestDisplayChannel : DisplayChannel
{
    public override bool IsActive(HttpContext context)
    {
        return true;
        //The sample code uses package 'Wangkanai.Detection' for device detection
        //var detection = context.RequestServices.GetRequiredService<IDetection>();
        //return detection.Device.Type == DeviceType.Mobile;
    }

    public override string ChannelName
    {
        get { return "Khai Test DisplayChannel"; }
    }
}