using CMS.Models.Pages;
using EPiServer.Framework.Blobs;
using EPiServer.ServiceLocation;
using EPiServer.Web.Mvc;
using Microsoft.AspNetCore.Mvc;

namespace CMS.Controllers;

public class ImagePageController : PageController<ImagePage>
{
    public async Task<ActionResult> Index(ImagePage currentPage)
    {
        await ReadWriteBlobs(currentPage.BlobPathToReadWrite);

        return View(currentPage);
    }

    public async Task ReadWriteBlobs(string path)
    {
        var blobFactory = ServiceLocator.Current.GetInstance<IBlobFactory>();

        //Define a container
        var container = Blob.GetContainerIdentifier(Guid.NewGuid());

        //Uploading a file to a blob
        var blob1 = blobFactory.CreateBlob(container, ".jpg");
        using (var fs = new FileStream(path, FileMode.Open))
        {
            blob1.Write(fs);
        }

        //Writing custom data to a blob
        var blob2 = blobFactory.CreateBlob(container, ".txt");
        using (var s = blob2.OpenWrite())
        {
            var w = new StreamWriter(s);
            await w.WriteLineAsync("Hello World!");
            await w.FlushAsync();
        }

        //Reading from a blob based on ID
        var blobID = blob2.ID;
        var blob3 = blobFactory.GetBlob(blobID);
        using (var s = blob3.OpenRead())
        {
            var helloWorld = await new StreamReader(s).ReadToEndAsync();
        }

        //Delete single blob
        blobFactory.Delete(blobID);

        //Delete container
        blobFactory.Delete(container);
    }
}