Handler = Proc.new do |req, res|
	res.status = 200
	res['Content-Type'] = 'text/text; charset=utf-8'
	if req.query.has_key?("name")
		name = req.query["name"]
		res.body = "Hello, #{name}!"
	else
		res.body = "Hello, stranger!"
	end
end
