using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection;
using AMAUpdateSample.Utils;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .AddObjectStore(Constants.AzureManagedAppsStoreName)
    .Build();

host.Run();
