using AMAUpdateSample.Utils;
using Azure;
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.ContainerInstance;
using Azure.ResourceManager.ContainerInstance.Models;
using Azure.ResourceManager.Resources;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using System.Net;
using System.Text;
using System.Text.Json.Nodes;

namespace AMAUpdateSample.Publisher
{
    public class Commands
    {
        private readonly ILogger _logger;
        private readonly IConfigStore _config;

        public Commands(ILoggerFactory loggerFactory, IConfigStore config)
        {
            _logger = loggerFactory.CreateLogger<Commands>();
            _config = config;
        }

        [Function("commands")]
        public async Task<HttpResponseData> Run([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
        {
            _logger.LogInformation("Process a command");

            var json = req.ParseBody();

            var command = json.GetOrThrow(Constants.Commands.Command);

            switch (command) {
                case "deploy":
                    var image = json.GetOrThrow(Constants.Commands.Image);

                    return await DeployAsync(req, image);

                default:
                    _logger.LogError($"Unknown command: {command}");
                    return req.CreateResponse(HttpStatusCode.BadRequest);
            }
        }

        private async Task<HttpResponseData> DeployAsync(HttpRequestData req, string image)
        {
            _logger.LogInformation($"Deploying image: {image}");
            var credentials = new ManagedIdentityCredential();
            ArmClient client = new ArmClient(credentials);

            string applicationId = await GetConfig(Constants.Config.ApplicationId);
            string eventsUrl = await GetConfig(Constants.Config.EventsUrl);
            string registry = await GetConfig(Constants.Config.Registry);
            string registryUsername = await GetConfig(Constants.Config.RegistryUsername);
            string registryPassword = await GetConfig(Constants.Config.RegistryPassword);
            string rgName = await GetConfig(Constants.Config.ResourceGroupName);
            string containerInstanceName = Constants.AzureContainerInstanceName;

            SubscriptionResource subscription = await client.GetDefaultSubscriptionAsync();
            ResourceGroupCollection resourceGroups = subscription.GetResourceGroups();
            ResourceGroupResource resourceGroup = await resourceGroups.GetAsync(rgName);
            var containerGroups = resourceGroup.GetContainerGroups();
            var existingContainerInstance = await containerGroups.GetAsync(containerInstanceName);

            // if the container instance didn't exist, fail
            if (existingContainerInstance == null) {
                _logger.LogError($"Container instance {containerInstanceName} not found in resource group {rgName}");
                return req.CreateResponse(HttpStatusCode.BadRequest);
            }
            existingContainerInstance.Value.Data.Containers[0].Image = image;
            existingContainerInstance.Value.Data.ImageRegistryCredentials.Add(new ContainerGroupImageRegistryCredential(registry) { Username = registryUsername, Password = registryPassword });
            var result = await containerGroups.CreateOrUpdateAsync(WaitUntil.Completed, containerInstanceName, existingContainerInstance.Value.Data);
            using (var httpClient = new HttpClient())
            {
                httpClient.Timeout = TimeSpan.FromMinutes(5);
                var eventJson = new JsonObject();
                eventJson.Add(Constants.ManagedApplication.ApplicationId, applicationId);
                eventJson.Add(Constants.Config.ResourceGroupName, rgName);
                eventJson.Add(Constants.ManagedApplication.EventType, "deployStarted");
                eventJson.Add(Constants.Commands.Image, image);

                var content = new StringContent(eventJson.ToString(), Encoding.UTF8, "application/json");
                var response = await httpClient.PostAsync(eventsUrl, content);
            }

            return req.CreateResponse(HttpStatusCode.OK);
        }

        private async Task<string> GetConfig(string key)
        {
            var config = await _config.Get(key);

            if (config == null) {
                throw new Exception($"Missing config: {key}");
            }

            return config;
        }
    }
}
