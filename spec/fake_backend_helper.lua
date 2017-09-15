local fake_backend = {}

function fake_backend.new(response)
  local backend = { requests = {} }

  backend.send = function(_, request)
    backend.requests[#backend.requests + 1] = request
    backend.last_request = request

    if response then
      return response(request)
    else
      return { request = request, status = 200 }
    end
  end

  return backend
end


return fake_backend
