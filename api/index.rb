require "faraday"
require "json"
require "date"

INCIDENTS_URL = "http://justinkenyon.com/belmont-police-blotter/incidents.json"
QUERY_FILTER_METHOD_MAPPING = {
  "month_number" => :incidents_by_month,
  "four_digit_year" => :incidents_by_year,
  "street" => :incidents_by_street,
}

Handler = Proc.new do |req, res|
  res.status = 200
  res["Content-Type"] = "text/json; charset=utf-8"
  res["Access-Control-Allow-Origin"] = "*"

  filtered_incidents = if req.query.keys.all?(&method(:valid_query?))
    filter_incidents(req.query)
  else
    { error: "You are using an invalid query param!" }
  end

  res.body = filtered_incidents.to_json
end

def filter_incidents(query)
  filtered = incidents

  query.each do |key, value|
    filter_method = QUERY_FILTER_METHOD_MAPPING[key]
    next unless filter_method
    filtered = send(filter_method, value, filtered)
  end

  if query.has_key?("limit")
    filtered.first(query["limit"])
  else
    filtered
  end
end

def incidents
  JSON.parse(Faraday.get(INCIDENTS_URL).body)
end

def incidents_by_month(month_number, filtered_incidents)
  filtered_incidents.merge(
    "items" => filtered_incidents["items"].select do |incident|
      DateTime.parse(incident["date"]).month.to_s == month_number
    end
  )
end

def incidents_by_year(year, filtered_incidents)
  filtered_incidents.merge(
    "items" => filtered_incidents["items"].select do |incident|
      DateTime.parse(incident["date"]).year.to_s == year
    end
  )
end

def incidents_by_street(street, filtered_incidents)
  filtered_incidents.merge(
    "items" => filtered_incidents["items"].select do |incident|
      next false unless incident["location"]
      incident["location"].downcase.include?(street.downcase)
    end
  )
end

def valid_query?(query)
  QUERY_FILTER_METHOD_MAPPING.keys.include?(query) || query == "limit"
end
