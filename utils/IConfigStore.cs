namespace AMAUpdateSample.Utils;

public interface IConfigStore
{
    Task<string?> Get(string key);
}