using System.Net;
using System.Text;
using System.Text.Json.Nodes;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

using AMAUpdateSample.Utils;

namespace AMAUpdateSample.Publisher
{
    public class Deployment
    {
        private readonly ILogger _logger;
        private readonly IObjectStore _store;

        public Deployment(ILoggerFactory loggerFactory, IObjectStore store)
        {
            _logger = loggerFactory.CreateLogger<Deployment>();
            _store = store;
        }

        [Function("deployment")]
        public async Task<HttpResponseData> Run([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
        {
            _logger.LogInformation("Trigger a deployment");

            var json = req.ParseBody();

            var clientId = json.GetOrThrow(Constants.ManagedApplication.ApplicationId);
            var image = json.GetOrThrow(Constants.Commands.Image);
            
            string commandUrl = await GetCommandUrl(clientId);

            var command = new JsonObject();
            command.Add(Constants.Commands.Command, Constants.Commands.Deploy);
            command.Add(Constants.Commands.Image, image);

            var commandStr = command.ToString();

            using (var client = new HttpClient())
            {
                client.Timeout = TimeSpan.FromMinutes(5);
                var commandResponse = await client.PostAsync(
                    commandUrl,
                    new StringContent(commandStr, Encoding.UTF8, "application/json"));

                if (!commandResponse.IsSuccessStatusCode) {
                    _logger.LogError($"Failed to trigger a deployment: {commandResponse.StatusCode}");
                    return req.CreateResponse(HttpStatusCode.InternalServerError);
                }
            }

            return req.CreateResponse(HttpStatusCode.OK);
        }

        private async Task<string> GetCommandUrl(string applicationId)
        {
            var json = await _store.Get(applicationId);
            return json.GetOrThrow(Constants.ManagedApplication.CommandUrl);
        }
    }
}
