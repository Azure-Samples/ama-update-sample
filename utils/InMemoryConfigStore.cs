using System.Text.Json.Nodes;

namespace AMAUpdateSample.Utils;

public class InMemoryConfigStore : IConfigStore
{
    private Dictionary<string, string?> _store = new Dictionary<string, string?>();

    public void Set(IDictionary<string, string?> config)
    {
        foreach (var kvp in config)
        {
            _store[kvp.Key] = kvp.Value;
        }
    }

    public Task<string?> Get(string key)
    {
        if (_store.ContainsKey(key))
        {
            return Task.FromResult(_store[key]);
        }
        return Task.FromResult<string?>(null);
    }
}