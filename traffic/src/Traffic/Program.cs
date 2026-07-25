using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Parquet.Serialization;

var city = new City("Chicago", 41.85, -87.65);
const double OFFSET_DELTA = 0.25;

IConfigurationRoot config = new ConfigurationBuilder()
    .AddUserSecrets<Program>()
    .Build();

var key = config["TOMTOM_API_KEY"]
    ?? throw new InvalidOperationException("TOMTOM_API_KEY not set");

HttpClient httpClient = new()
{
    BaseAddress = new Uri("https://api.tomtom.com")
};

// Ignore Earth curvature for now.
// Create bbox from const delta match tomtom format:
// minLon,minLat,maxLon,maxLat
var bbox = $"{city.Lon - OFFSET_DELTA},{city.Lat - OFFSET_DELTA},{city.Lon + OFFSET_DELTA},{city.Lat + OFFSET_DELTA}";
var fields = "{incidents{properties{id,iconCategory,startTime,magnitudeOfDelay,endTime,length,events{description}}}}";

using HttpResponseMessage response = await httpClient
    .GetAsync($"/traffic/services/5/incidentDetails?bbox={bbox}&fields={fields}&key={key}");

response.WriteRequestToConsole();
response.EnsureSuccessStatusCode();

var jsonResponse = await response.Content.ReadAsStringAsync();
var incidentResponse = JsonSerializer.Deserialize<IncidentResponse>(
    jsonResponse,
    options: new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

var collectedAt = DateTime.UtcNow;
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
        city.Name,
        collectedAt))
    .ToList();

if (incidents is not null)
{
    var directoryName = city.Name.Replace(' ', '_');
    var fileName = collectedAt.ToString("yyyy-MM-ddTH");

    Directory.CreateDirectory($"data/{directoryName}");

    await ParquetSerializer.SerializeAsync(
        incidents,
        $"{directoryName}/{fileName}.parquet");
}
