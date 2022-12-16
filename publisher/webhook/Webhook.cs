using System.Net;
using System.Text.Json.Nodes;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

using AMAUpdateSample.Utils;

namespace AMAUpdateSample.Publisher
{
    public class Webhook
    {
        private readonly ILogger _logger;
        private readonly IObjectStore _store;

        public Webhook(ILoggerFactory loggerFactory, IObjectStore store)
        {
            _logger = loggerFactory.CreateLogger<Webhook>();
            _store = store;
        }

        [Function("resource")]
        public async Task<HttpResponseData> Run([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
        {
            _logger.LogInformation("Webhook received from Azure Managed Application");

            var json = req.ParseBody();

            var provisioningState = json.GetOrThrow(Constants.ManagedApplication.ProvisioningState);
            var applicationId = json.GetOrThrow(Constants.ManagedApplication.ApplicationId);
            
            await SaveState(applicationId, provisioningState);
            
            return req.CreateResponse(HttpStatusCode.OK);
        }

        private async Task SaveState(string applicationId, string provisioningState)
        {
            var json = await _store.Get(applicationId);
            json[Constants.ManagedApplication.ProvisioningState] = provisioningState;
            await _store.Set(applicationId, json);
        }
    }
}
