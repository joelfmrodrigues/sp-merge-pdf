using System;
using System.Threading.Tasks;
using System.IO;
using System.Security.Cryptography.X509Certificates;
using MergePDF.Helpers;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration; 
using Microsoft.SharePoint.Client;
using Newtonsoft.Json;
using PdfSharp.Pdf;
using PdfSharp.Pdf.IO;
using PnP.Framework;

namespace MergePDF
{
    public static class MergePDF
    {
        [FunctionName("MergePDF")]
        public static async Task Run([QueueTrigger("merge-pdf", Connection = "AzureWebJobsStorage")]string myQueueItem, ExecutionContext context, ILogger log)
        {
            log.LogInformation($"C# Queue trigger function processed: {myQueueItem}");

            // Deserialize queue object
            var queueItem = JsonConvert.DeserializeObject<QueueItem>(myQueueItem);
            var siteUrl = queueItem.SiteUrl;

            var config = new ConfigurationBuilder()
                .SetBasePath(context.FunctionAppDirectory)
                // This gives you access to your application settings 
                // in your local development environment
                .AddJsonFile("local.settings.json", optional: true, reloadOnChange: true) 
                // This is what actually gets you the 
                // application settings in Azure
                .AddEnvironmentVariables() 
                .Build();
				
            var authId = config["AuthId"];
            var spoTenantName = config["SPOTenantName"];
            var spoTenant = $"{spoTenantName}.onmicrosoft.com";
            var scopes = new string[] {$"https://{spoTenantName}.sharepoint.com/.default"};
            
            var base64Cert = config["Certificate"];
            var certBytes = Convert.FromBase64String(base64Cert);
            var certificate = new X509Certificate2(certBytes);

            var accessTokenSP = await AuthenticationHelper.GetApplicationAuthenticatedClient(authId, certificate, scopes, spoTenant);

            using (var ctx = new AuthenticationManager().GetAccessTokenContext(siteUrl, accessTokenSP))
            {
                log.LogInformation($"SharePoint authenticated context acquired");
                await MergePDFs(ctx, queueItem, log);
            }
        }

        internal static async Task MergePDFs(ClientContext ctx, QueueItem queueItem, ILogger log)
        {
            System.Text.Encoding.RegisterProvider(System.Text.CodePagesEncodingProvider.Instance);
            log.LogInformation($"Creating blank PDF file...");
            // instantiate new file
            using (var targetDoc = new PdfDocument())
            {
                Microsoft.SharePoint.Client.File file = null;
                ClientResult<Stream> fileStream = null;
                // parse all files in array
                log.LogInformation($"Parsing {queueItem.FilesPathArray.Length} PDF files");
                foreach (var filePath in queueItem.FilesPathArray)
                {
                    log.LogInformation($"Parsing PDF file: {filePath}");
                    // get file from SharePoint
                    file = ctx.Web.GetFileByUrl(filePath);
                    fileStream = file.OpenBinaryStream();
                    ctx.Load(file);
                    await ctx.ExecuteQueryRetryAsync();

                    // open file and get pages
                    using (var pdfDoc = PdfReader.Open(fileStream.Value, PdfDocumentOpenMode.Import))
                    {
                        for (var i = 0; i < pdfDoc.PageCount; i++)
                        {
                            targetDoc.AddPage(pdfDoc.Pages[i]);

                        }
                    }
                }
                log.LogInformation($"PDF files parsed successfully");

                // create result file
                using (Stream newFileStream = new MemoryStream())
                {                    
                    targetDoc.Save(newFileStream);

                    // upload to SharePoint
                    var destinationFolder = ctx.Web.GetFolderByServerRelativeUrl(queueItem.FolderPath);
                    ctx.Load(destinationFolder);
                    await ctx.ExecuteQueryRetryAsync();

                    await destinationFolder.UploadFileAsync(queueItem.FileName, newFileStream, true);
                    await ctx.ExecuteQueryRetryAsync();
                    log.LogInformation($"Final PDF file added to SharePoint: {queueItem.FolderPath}/{queueItem.FileName}");
                }
            }
        }
    }
}
