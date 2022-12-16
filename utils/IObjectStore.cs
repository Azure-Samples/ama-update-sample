using System.Text.Json.Nodes;

namespace AMAUpdateSample.Utils;

public interface IObjectStore
{
    Task Set(string partitionKey, string id, JsonNode obj);
    Task<JsonNode> Get(string partitionKey, string id);
}