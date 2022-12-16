using System.Net;
using System.Text.Json.Nodes;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

using AMAUpdateSample.Utils;

namespace AMAUpdateSample.Publisher
{
    public class Events
    {
        private readonly ILogger _logger;
        private readonly IObjectStore _store;

        public Events(ILoggerFactory loggerFactory, IObjectStore storage)
        {
            _logger = loggerFactory.CreateLogger<Events>();
            _store = storage;
        }

        [Function("Events")]
        public async Task<HttpResponseData> Run([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
        {
            _logger.LogInformation("Receive an event from an Azure Managed Application");

            var json = req.ParseBody();
            
            await StoreEvent(json);
            
            return req.CreateResponse(HttpStatusCode.OK);
        }

        private async Task StoreEvent(JsonNode json)
        {
            var applicationId = json.GetOrThrow(Constants.ManagedApplication.ApplicationId);
            await _store.Set(applicationId, Guid.NewGuid().ToString(), json);
        }
    }
}
