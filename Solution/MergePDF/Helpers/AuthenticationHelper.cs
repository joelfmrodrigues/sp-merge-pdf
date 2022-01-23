using System.Security.Cryptography.X509Certificates;
using System.Threading.Tasks;
using Microsoft.Identity.Client;

namespace MergePDF.Helpers
{
    internal class AuthenticationHelper
    {
        internal static async Task<string> GetApplicationAuthenticatedClient(string clientId, X509Certificate2 certificate, string[] scopes, string tenant)
        {
            var clientApp = ConfidentialClientApplicationBuilder
                .Create(clientId)
                .WithCertificate(certificate)
                .WithTenantId(tenant)
                .Build();

            var authResult = await clientApp.AcquireTokenForClient(scopes).ExecuteAsync();
            var accessToken = authResult.AccessToken;
            return accessToken;
        }
    }
}
