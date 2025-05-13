FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY ["TemporalWorker.csproj", "./"]
RUN dotnet restore

# Copy everything else and build
COPY . .
RUN dotnet build -c Release -o /app/build

# Publish stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app/build .

ENV TEMPORAL_HOST=temporal-frontend.temporal.svc.cluster.local:7233
ENV TEMPORAL_NAMESPACE=default

ENTRYPOINT ["dotnet", "TemporalWorker.dll"] 