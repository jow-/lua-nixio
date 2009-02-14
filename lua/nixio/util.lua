--[[
nixio - Linux I/O library for lua

Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

$Id$
]]--

local table = require "table"
local nixio = require "nixio"
local setmetatable, assert = setmetatable, assert

module "nixio.util"

local BUFFERSIZE = 8096
local socket = nixio.socket_meta

function socket.readall(self, len)
	local block, code, msg = self:recv(len)

	if not block then
		return "", code, msg, len
	end

	local data, total = {block}, #block

	while len > total do
		block, code, msg = self:recv(len - total)

		if not block then
			return data, code, msg, len - #data
		end

		data[#data+1], total = block, total + #block
	end

	return (#data > 1 and table.concat(data) or data[1]), nil, nil, 0
end

function socket.sendall(self, data)
	local total, block = 0
	local sent, code, msg = self:send(data)

	if not sent then
		return total, code, msg, data
	end

	while sent < #data do
		block, total = data:sub(sent + 1), total + sent
		sent, code, msg = self:send(block)
		
		if not sent then
			return total, code, msg, block
		end
	end
	
	return total + sent, nil, nil, ""
end

function socket.linesource(self, limit)
	limit = limit or BUFFERSIZE
	local buffer = ""
	return function(flush)
		local bpos, line, endp, _ = 0
		
		if flush then
			line = buffer
			buffer = ""
			return line
		end

		while not line do
			_, endp, line = buffer:find("^(.-)\r?\n", bpos + 1)
			if line then
				bpos = endp
				return line
			elseif #buffer < limit + bpos then
				local newblock, code = self:recv(limit + bpos - #buffer)
				if not newblock then
					return nil, code
				end
				buffer = buffer:sub(bpos + 1) .. newblock
				bpos = 0
			else
				return nil, 0
			end
		end
	end
end