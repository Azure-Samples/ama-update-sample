using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.Azure.Cosmos;

namespace AMAUpdateSample.Utils;

public class CosmosDBObjectStore : IObjectStore
{
    private const string PartitionKeyPath = Constants.ManagedApplication.ApplicationId;
    private readonly Container _container;

    public CosmosDBObjectStore(string connectionString, string databaseName, string containerName)
    {
        var client = new CosmosClient(connectionString);
        var db = client.CreateDatabaseIfNotExistsAsync(databaseName).Result.Database;
        var container = db.CreateContainerIfNotExistsAsync(containerName, "/" + PartitionKeyPath).Result.Container;

        _container = container;
    }


    public async Task<JsonNode> Get(string partitionKey, string id)
    {
        partitionKey = partitionKey.CleanForID();
        id = id.CleanForID();

        try
        {
            var responseMessage = await _container.ReadItemStreamAsync(id, new PartitionKey(partitionKey));

            if (responseMessage.IsSuccessStatusCode)
            {
                using (var streamReader = new StreamReader(responseMessage.Content))
                {
                    var content = await streamReader.ReadToEndAsync();
                    var json = JsonObject.Parse(content)!.AsObject();

                    var propsToRemove = new List<string>();
                    foreach (var prop in json) {
                        if (prop.Key.StartsWith("_")) {
                            propsToRemove.Add(prop.Key);
                        }
                    }

                    foreach (var prop in propsToRemove) {
                        json.Remove(prop);
                    }

                    return json;
                }
            }
            else
            {
                return new JsonObject();
            }
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return new JsonObject();
        }
    }

    public async Task Set(string partitionKey, string id, JsonNode json)
    {
        partitionKey = partitionKey.CleanForID();
        id = id.CleanForID();

        json[PartitionKeyPath] = partitionKey;
        json["id"] = id;
        
        using (var stream = new MemoryStream())
        {
            await JsonSerializer.SerializeAsync(stream, json);
            stream.Position = 0;
            await _container.UpsertItemStreamAsync(stream, new PartitionKey(partitionKey));
        }
    }
}