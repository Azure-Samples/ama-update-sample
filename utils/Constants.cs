namespace AMAUpdateSample.Utils;

public static class Constants {
    public const string AzureContainerInstanceName = "aci";
    public const string AzureManagedAppsStoreName = "ama";
    public const string EventsStoreName = "events";

    public static class ManagedApplication {
        public const string ApplicationId = "applicationId";
        public const string CommandUrl = "commandUrl";
        public const string ProvisioningState = "provisioningState";
        public const string EventType = "eventType";
    }

    public static class Commands {
        public const string Command = "command";
        public const string Deploy = "deploy";
        public const string Image = "image";
    }

    public static class Config {
        public const string ApplicationId = "applicationid";
        public const string EventsUrl = "eventsurl";
        public const string Registry = "registry";
        public const string RegistryUsername = "registryUsername";
        public const string RegistryPassword = "registryPassword";
        public const string ResourceGroupName = "resourceGroupName";
    }
}