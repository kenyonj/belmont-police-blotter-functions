require "faraday"
require "json"
require "date"

INCIDENTS_URL = "http://justinkenyon.com/belmont-police-blotter/incidents.json"
VALID_QUERIES = [
  "month_number",
  "four_digit_year",
  "street",
]

Handler = Proc.new do |req, res|
	res.status = 200
	res["Content-Type"] = "text/json; charset=utf-8"

  filtered_incidents = if req.query.keys.all?(&method(:valid_query?))
    filter_incidents(req.query)
	else
    { error: "You are using an invalid query param!" }
	end

  res.body = filtered_incidents.to_json
end

def filter_incidents(query)
  filtered = incidents
  filtered = incidents_by_month(query, filtered) if month_query?(query)
  filtered = incidents_by_year(query, filtered) if year_query?(query)
  filtered = incidents_by_street(query, filtered) if street_query?(query)

  filtered
end

def incidents
  JSON.parse(Faraday.get(INCIDENTS_URL).body)
end

def incidents_by_month(query, filtered_incidents)
  month_number = query["month_number"]

  filtered_incidents.merge(
    "items" => filtered_incidents["items"].select do |incident|
      DateTime.parse(incident["date"]).month.to_s == month_number
    end
  )
end

def incidents_by_year(query, filtered_incidents)
  year = query["four_digit_year"]

  filtered_incidents.merge(
    "items" => filtered_incidents["items"].select do |incident|
      DateTime.parse(incident["date"]).year.to_s == year
    end
  )
end

def incidents_by_street(street, filtered_incidents)
  street = query["street"].downcase

  filtered_incidents.merge(
    "items" => filtered_incidents["items"].select do |incident|
      incident["location"].downcase.include?(street)
    end
  )
end

def valid_query?(query)
  VALID_QUERIES.include?(query)
end

def month_query?(query)
  query.has_key?("month_number")
end

def year_query?(query)
  query.has_key?("four_digit_year")
end

def street_query?(query)
  query.has_key?("street")
end
