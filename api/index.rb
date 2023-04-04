require "faraday"
require "json"
require "date"
require "geocoder"

FALLBACK_DATETIME = DateTime.new(1971, 9, 1)
INCIDENTS_URL = "https://bpb.heyo.pw/incidents.json"
QUERY_FILTER_METHOD_MAPPING = {
  "month_number" => :incidents_by_month,
  "four_digit_year" => :incidents_by_year,
  "street" => :incidents_by_street,
  "distance_from" => :incidents_by_distance_from,
}
EXTRA_QUERY_FILTERS = [
  "limit",
  "offset",
  "distance_limit",
]
RADIAN_DIVISOR = 57.29577951

Handler = Proc.new do |req, res|
  res.status = 200
  res["Content-Type"] = "text/json; charset=utf-8"
  res["Access-Control-Allow-Origin"] = "*"

  query = req.query.slice(*(QUERY_FILTER_METHOD_MAPPING.keys + EXTRA_QUERY_FILTERS))
  filtered_incidents = filter_incidents(query)

  res.body = filtered_incidents.to_json
end

def filter_incidents(query)
  filtered = incidents

  query.each do |key, value|
    filter_method = QUERY_FILTER_METHOD_MAPPING[key]
    next unless filter_method
    filtered = send(filter_method, value, filtered, query)
  end

  if query.has_key?("limit")
    incidents_with_limit(query["limit"], query["offset"], filtered)
  else
    filtered
  end
end

def incidents
  JSON.parse(Faraday.get(INCIDENTS_URL).body)
end

def incidents_by_month(month_number, filtered_incidents, query)
  filtered_incidents.merge(
    "items" => filtered_incidents["items"].select do |incident|
      parsed_date(incident["date"]).month.to_s == month_number
    end
  )
end

def incidents_by_year(year, filtered_incidents, query)
  filtered_incidents.merge(
    "items" => filtered_incidents["items"].select do |incident|
      parsed_date(incident["date"]).year.to_s == year
    end
  )
end

def incidents_by_street(street, filtered_incidents, query)
  filtered_incidents.merge(
    "items" => filtered_incidents["items"].select do |incident|
      next false unless incident["location"]
      incident["location"].downcase.include?(street.downcase)
    end
  )
end

def incidents_by_distance_from(street_address, filtered_incidents, query)
  distance_limit = query["distance_limit"].to_f
  return filtered_incidents unless distance_limit > 0
  from_lat, from_lng = Geocoder.search(combined_location(street_address)).first&.coordinates
  return filtered_incidents unless from_lat && from_lng

  from_lat_radian = from_lat / RADIAN_DIVISOR
  from_lng_radian = from_lng / RADIAN_DIVISOR

  # Distance, d = 3963.0 * arccos[(sin(lat1) * sin(lat2)) + cos(lat1) * cos(lat2) * cos(long2 – long1)]

  filtered_incidents.merge(
    "items" => filtered_incidents["items"].select do |incident|
      to_lat_radian = incident["latitude"] / RADIAN_DIVISOR
      to_lng_radian = incident["longitude"] / RADIAN_DIVISOR
      distance = 3963.0 * Math.acos(
        (Math.sin(from_lat_radian) * Math.sin(to_lat_radian)) +
        Math.cos(from_lat_radian) *
        Math.cos(to_lat_radian) *
        Math.cos(to_lng_radian - from_lng_radian)
      )

      distance <= distance_limit
    end
  )
end

def incidents_with_limit(limit, offset, filtered_incidents)
  filtered_incidents.merge("items" => filtered_incidents["items"].slice(offset.to_i, limit.to_i))
end

def combined_location(street)
  "#{street}, Belmont, MA 02478"
end

def parsed_date(date_string)
  DateTime.parse(incident["date"])
rescue TypeError
  FALLBACK_DATETIME
end

