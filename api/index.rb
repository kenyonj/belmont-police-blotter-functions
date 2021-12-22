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

  filtered_incidents = if req.query.keys.all?(&method(:valid_query?))
    filter_incidents(req.query)
	else
    { error: "You are using an invalid query param!" }
	end

  res.body = filtered_incidents.to_json
end

def filter_incidents(query)
  filtered = incidents

  query.keys.each do |query|
    filter_method = QUERY_FILTER_METHOD_MAPPING[query][:filter_method]
    filtered = send(filter_method, query, filtered)
  end

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

def incidents_by_street(query, filtered_incidents)
  street = query["street"].downcase

  filtered_incidents.merge(
    "items" => filtered_incidents["items"].select do |incident|
      incident["location"].downcase.include?(street)
    end
  )
end

def valid_query?(query)
  QUERY_FILTER_METHOD_MAPPING.keys.include?(query)
end
