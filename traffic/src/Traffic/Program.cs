using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Parquet.Serialization;
using Azure.Identity;
using Azure.Storage.Blobs;
using Azure.Storage.Queues;
using Azure.Storage.Queues.Models;
using Microsoft.Extensions.Logging;
using Polly;
using System.Net;

using ILoggerFactory factory = LoggerFactory.Create(builder =>
{
    builder.AddJsonConsole();
    builder.SetMinimumLevel(LogLevel.Information);
});
ILogger logger = factory.CreateLogger<Program>();

const double OFFSET_DELTA = 0.25;
List<HttpStatusCode> RetryStatuses =
[
    HttpStatusCode.TooManyRequests,        // 429
    HttpStatusCode.InternalServerError,    // 500
    HttpStatusCode.BadGateway,             // 502
    HttpStatusCode.ServiceUnavailable,     // 503
    HttpStatusCode.GatewayTimeout          // 504
];

IConfigurationRoot config = new ConfigurationBuilder()
    .AddUserSecrets<Program>()
    .AddEnvironmentVariables()
    .Build();

var key = config["TOMTOM_API_KEY"]
    ?? throw new InvalidOperationException("TOMTOM_API_KEY not set");
var accountName = "1";
var containerName = "traffic-output";
var queueName = "traffic-queue";

HttpClient httpClient = new()
{
    BaseAddress = new Uri("https://api.tomtom.com")
};

ResiliencePipeline<HttpResponseMessage> pipeline = new ResiliencePipelineBuilder<HttpResponseMessage>()
    .AddRetry(new()
    {
        ShouldHandle = new PredicateBuilder<HttpResponseMessage>()
            .HandleResult(r => RetryStatuses.Contains(r.StatusCode)),
        BackoffType = DelayBackoffType.Exponential,
        UseJitter = true,
        MaxRetryAttempts = 5,
        OnRetry = args =>
        {
            args.Outcome.Result?.Dispose();
            return default;
        }
    })
    .Build();

var queueClient = new QueueClient(
    new Uri($"https://{accountName}.queue.core.windows.net/{queueName}"),
    new DefaultAzureCredential());

BlobServiceClient client = new(
    new Uri($"https://{accountName}.blob.core.windows.net"),
    new DefaultAzureCredential());

QueueMessage message = await queueClient.ReceiveMessageAsync();

if (message is null)
{
    logger.LogInformation("Empty queue, nothing to do.");
    return 0;
}

CityMessage? city = null;
try
{
    city = message.Body.ToObjectFromJson<CityMessage>(options: new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
        ?? throw new InvalidOperationException("null message body");
}
catch (Exception e)
{
    logger.LogError(e, "poison_message {MessageId}", message.MessageId);
    await queueClient.DeleteMessageAsync(message.MessageId, message.PopReceipt);
    return 0;
}

var collectedAt = DateTime.UtcNow;
var blobName = $"{city.City.Replace(' ', '_')}/{collectedAt.ToString("yyyy-MM-ddTHH")}.parquet";
BlobContainerClient container = client.GetBlobContainerClient(containerName);
BlobClient blobClient = container.GetBlobClient(blobName);

logger.LogInformation("city_start, {City}", city.City);

// Ignore Earth curvature for now.
// Create bbox from const delta match tomtom format:
// minLon,minLat,maxLon,maxLat
var bbox = $"{city.Lon - OFFSET_DELTA},{city.Lat - OFFSET_DELTA},{city.Lon + OFFSET_DELTA},{city.Lat + OFFSET_DELTA}";
var fields = "{incidents{properties{id,iconCategory,startTime,magnitudeOfDelay,endTime,length,events{description}}}}";

try
{
    using HttpResponseMessage response = await pipeline.ExecuteAsync(
        async ct => await httpClient
            .GetAsync($"/traffic/services/5/incidentDetails?bbox={bbox}&fields={fields}&key={key}", ct));

    response.WriteRequestToConsole();
    response.EnsureSuccessStatusCode();

    var jsonResponse = await response.Content.ReadAsStringAsync();
    var incidentResponse = JsonSerializer.Deserialize<IncidentResponse>(
        jsonResponse,
        options: new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

    var incidents = incidentResponse?
        .Incidents
        .Select(i => new Incident(
            i.Properties.Id,
            i.Properties.IconCategory.ToString(),
            i.Properties.MagnitudeOfDelay.ToString(),
            i.Properties.StartTime.UtcDateTime,
            i.Properties.EndTime?.UtcDateTime,
            i.Properties.Length,
            i.Properties.Events is null ? "" : string.Join('|', i.Properties.Events.Select(e => e.Description)),
            city.City,
            collectedAt))
        .ToList();

    if (incidents is null)
    {
        logger.LogError("etl_failed, unable to parse response.");
        return 1;
    }

    using var ms = new MemoryStream();
    await ParquetSerializer.SerializeAsync(incidents, ms);
    ms.Position = 0;

    await blobClient.UploadAsync(ms, overwrite: true);

    await queueClient.DeleteMessageAsync(message.MessageId, message.PopReceipt);

    logger.LogInformation("city_complete, {City} {Rows} rows", city.City, incidents.Count);
    return 0;
}
catch (Exception e)
{
    logger.LogError(e, "etl_failed");
    return 1;
}
