using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

using AMAUpdateSample.Utils;
using System.Text.Json.Nodes;

namespace AMAUpdateSample.Publisher
{
    public class SetCommandUrl
    {
        private readonly ILogger _logger;
        private readonly IObjectStore _store;

        public SetCommandUrl(ILoggerFactory loggerFactory, IObjectStore store)
        {
            _logger = loggerFactory.CreateLogger<SetCommandUrl>();
            _store = store;
        }

        [Function("setcommandurl")]
        public async Task<HttpResponseData> Run([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
        {
            _logger.LogInformation("Sets a function key for an Azure Managed Application command function");

            var json = req.ParseBody();

            var applicationId = json.GetOrThrow(Constants.ManagedApplication.ApplicationId);
            var commandUrl = json.GetOrThrow(Constants.ManagedApplication.CommandUrl);

            await StoreCommandUrl(applicationId, commandUrl);

            return req.CreateResponse(HttpStatusCode.OK);
        }

        private async Task StoreCommandUrl(string applicationId, string commandUrl)
        {
            var json = await _store.Get(applicationId);
            json[Constants.ManagedApplication.CommandUrl] = commandUrl;
            await _store.Set(applicationId, json);
        }
    }
}
