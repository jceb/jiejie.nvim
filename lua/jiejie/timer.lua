local M = {}

--- Execute callback function at the interval until timer is stopped
--- @param interval number Timer interval
--- @param callback fun(timer) Callback function that's called after interval and receives the timer object as an argument
function M.setInterval(interval, callback)
  local timer = vim.uv.new_timer()
  timer:start(interval, interval, function()
    callback(timer)
  end)
  return timer
end

--- Stop interval timer
function M.clearInterval(timer)
  timer:stop()
  timer:close()
end

return M
