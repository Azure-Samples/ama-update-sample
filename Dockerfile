FROM mcr.microsoft.com/dotnet/sdk:6.0 AS installer-base

COPY . /src

WORKDIR /src

RUN dotnet build

FROM installer-base as installer-env
ARG FUNCTION_PATH

RUN mkdir /output

WORKDIR /src/$FUNCTION_PATH
RUN dotnet publish --no-build ./*.csproj --output /output

# To enable ssh & remote debugging on app service change the base image to the one below
# FROM mcr.microsoft.com/azure-functions/dotnet-isolated:4-dotnet-isolated6.0-appservice
FROM mcr.microsoft.com/azure-functions/dotnet-isolated:4-dotnet-isolated6.0

COPY --from=installer-env ["/output", "/home/site/wwwroot"]