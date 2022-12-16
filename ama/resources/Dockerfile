FROM --platform=linux/amd64 mcr.microsoft.com/azure-cli

COPY ./main.bicep /main.bicep
COPY ./entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]