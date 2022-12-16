using System.Text.Json.Nodes;

namespace AMAUpdateSample.Utils;

public class InMemoryObjectStore : IObjectStore
{
    private Dictionary<string, string?> _store = new Dictionary<string, string?>();

    public Task<JsonNode> Get(string partitionKey, string id)
    {
        partitionKey = partitionKey.CleanForID();
        id = id.CleanForID();
        var internalKey = partitionKey + "-" + id;
        if (_store.ContainsKey(internalKey))
        {
            var val = _store[internalKey];
            var json = val is null ? null : JsonObject.Parse(val);
            return Task.FromResult(json ?? new JsonObject());
        }
        return Task.FromResult<JsonNode>(new JsonObject());
    }

    public Task Set(string partitionKey, string id, JsonNode json)
    {
        partitionKey = partitionKey.CleanForID();
        id = id.CleanForID();
        var internalKey = partitionKey + "-" + id;
        _store[internalKey] = json.ToJsonString();

        return Task.CompletedTask;
    }
}