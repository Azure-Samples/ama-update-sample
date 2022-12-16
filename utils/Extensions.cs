using System.Text.Json.Nodes;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection;

namespace AMAUpdateSample.Utils;

public static class Extensions
{
    private const string CosmosDBConnectionStringKey = "CosmosDBConnectionString";
    private const string AzureKeyVaultUrlKey = "AzureKeyVaultUrl";

    private const string DatabaseName = "ama";

    public static IHostBuilder AddConfigStore(this IHostBuilder hostBuilder) {
        return hostBuilder.ConfigureServices((context, services) =>
        {
            var azureKeyVaultUrl = context.Configuration[AzureKeyVaultUrlKey];
            if (azureKeyVaultUrl == null)
            {
                services.AddSingleton<IConfigStore, InMemoryConfigStore>();
            }
            else
            {
                var store = new KeyVaultConfigStore(azureKeyVaultUrl);
                services.AddSingleton<IConfigStore>(store);
            }
        });
    }

    public static IHostBuilder AddObjectStore(this IHostBuilder hostBuilder, string storeName) {
        return hostBuilder.ConfigureServices((context, services) =>
        {
            var azureStorageConnString = context.Configuration[CosmosDBConnectionStringKey];
            if (azureStorageConnString == null)
            {
                services.AddSingleton<IObjectStore, InMemoryObjectStore>();
            }
            else
            {
                var store = new CosmosDBObjectStore(azureStorageConnString, DatabaseName, storeName);
                services.AddSingleton<IObjectStore>(store);
            }
        });
    }

    public static string GetOrThrow(this JsonNode json, string key) {
        var value = json[key]?.GetValue<string>();
        if (value == null) {
            throw new Exception($"Json does not contain {key}. Json: {json.ToJsonString()}");
        }
        return value;
    }

    public static JsonNode ParseBody(this HttpRequestData req) {
        var bodyStr = req.ReadAsStringAsync().Result;
        if (bodyStr == null) {
            throw new Exception("Request body is null");
        }
        var json = JsonObject.Parse(bodyStr);
        if (json == null) {
            throw new Exception("Request body is not a valid JSON");
        }
        return json;
    }
    
    public static Task Set(this IObjectStore store, string partitionKey, JsonNode json) {
        return store.Set(partitionKey, partitionKey, json);
    }

    public static Task<JsonNode> Get(this IObjectStore store, string partitionKey) {
        return store.Get(partitionKey, partitionKey);
    }

    public static string CleanForID(this string val)
    {
        var illegalChars = new string[] { "/", "\\", "?", "#" };
        
        foreach (var c in illegalChars) {
            val = val.Replace(c, "");
        }

        return val.ToLowerInvariant();
    }
}
