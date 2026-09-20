FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /App

# Copy project files first for better layer caching
COPY *.csproj ./
RUN dotnet restore

# Copy the rest and publish
COPY . ./
RUN dotnet publish -c Release -o out --no-restore

# Runtime image
FROM mcr.microsoft.com/dotnet/runtime:10.0
WORKDIR /App
COPY --from=build /App/out .

USER $APP_UID

ENTRYPOINT ["dotnet", "Traffic.dll"]
