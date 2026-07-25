using System.Text.Json.Serialization;

record CityMessage(
    string City,
    double Lat,
    double Lon);

record IncidentResponse(List<IncidentDto> Incidents);

record IncidentDto(IncidentProperties Properties);

record IncidentProperties(
    string Id,
    IconCategory IconCategory,
    MagnitudeOfDelay MagnitudeOfDelay,
    DateTimeOffset StartTime,
    DateTimeOffset? EndTime,
    double Length,
    List<IncidentEvent> Events);

record IncidentEvent(
    string Description);

record Incident(
    string Id,
    string IconCategory,
    string MagnitudeOfDelay,
    DateTime StartTime,
    DateTime? EndTime,
    double Length,
    string Events,
    string City,
    DateTime CollectedAt);
