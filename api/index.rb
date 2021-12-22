require "faraday"
require "json"
require "date"

INCIDENTS_URL = "http://justinkenyon.com/belmont-police-blotter/incidents.json"

Handler = Proc.new do |req, res|
	res.status = 200
	res["Content-Type"] = "text/json; charset=utf-8"

	filtered_incidents = if req.query.has_key?("month_number")
		month_number = req.query["month_number"]
    incidents_by_month(month_number)
  elsif req.query.has_key?("street")
		street = req.query["street"]
    incidents_by_month(street)
	else
    incidents
	end

  res.body = filtered_incidents.to_json
end

def incidents
  JSON.parse(Faraday.get(INCIDENTS_URL).body)
end

def incidents_by_month(month_number)
  all_incidents = incidents

  all_incidents.merge(
    "items" => all_incidents["items"].select do |incident|
      DateTime.parse(incident["date"]).month == month_number
    end
  )
end

def incidents_by_street(street)
  all_incidents = incidents

  all_incidents.merge(
    "items" => all_incidents["items"].select do |incident|
      incident["location"].downcase.include?(street.downcase)
    end
  )
end
