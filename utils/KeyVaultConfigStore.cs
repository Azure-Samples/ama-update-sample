using Azure;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

namespace AMAUpdateSample.Utils;

public class KeyVaultConfigStore : IConfigStore
{
    private readonly SecretClient _secretClient;
    public KeyVaultConfigStore(string vaultUrl)
    {
        _secretClient = new SecretClient(new Uri(vaultUrl), new DefaultAzureCredential());
    }

    public async Task<string?> Get(string key)
    {
        try
        {
            var secret = await _secretClient.GetSecretAsync(key);
            return secret.Value.Value;
        }
        catch (RequestFailedException ex) when (ex.Status == 404)
        {
            return null;
        }
    }
}