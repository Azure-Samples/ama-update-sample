using Microsoft.Extensions.Hosting;
using AMAUpdateSample.Utils;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .AddConfigStore()
    .Build();

host.Run();
