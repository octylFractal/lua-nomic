local ffi = require"ffi"

---@class SliceReservation
---@field offset integer offset into buffer where this reservation was added
---@field length integer length of the slice reserved

---@class ByteBuffer
---@field private buffer ffi.cdata*
---@field private cursor integer current offset into buffer
---@field private reservations table<SliceReservation, boolean> reservations, must be empty to convert to string
---@field knownPointers table<any,PointerInfo> map from object to pointer info
local ByteBuffer = {}
local ByteBuffer_mt = {
  __index = ByteBuffer;
}

local bufferSize = 1024

-- Creates a new ByteBuffer
---@return ByteBuffer
local function createByteBuffer()
  local self = {
    buffer = ffi.new("uint8_t[?]", bufferSize),
    cursor = 0,
    reservations = {},
    knownPointers = {},
    size = bufferSize,
  }
  return setmetatable(self, ByteBuffer_mt)
end

function ByteBuffer:length()
  return self.cursor
end

-- Doubles the buffer size
function ByteBuffer:grow()
  local newsize = self.size * 2
  local newbuffer = ffi.new("uint8_t[?]", newsize)
  ffi.copy(newbuffer, self.buffer, self.cursor)
  self.buffer = newbuffer
  self.size = newsize
end

-- Write some bytes into the buffer
---@param length integer length of the bytes to write
---@return ffi.cdata* pointer to the slice
function ByteBuffer:write(length)
  if self.cursor + length > self.size then
    self:grow()
    -- tail call to re-run length check
    -- TODO: optimize with a size hint to grow
    return self:write(length)
  end
  local slice = self.buffer + self.cursor
  self.cursor = self.cursor + length
  return slice
end

-- Reserve this slot in the buffer for filling in later
---@param length integer length of the slot to reserve
---@return SliceReservation
function ByteBuffer:reserve(length)
  if self.cursor + length > self.size then
    self:grow()
    -- tail call to re-run length check
    -- TODO: optimize with a size hint to grow
    return self:reserve(length)
  end
  local reservation = {
    offset = self.cursor,
    length = length,
  }
  self.reservations[reservation] = true
  self.cursor = self.cursor + length
  return reservation
end

-- Fill in a reservation with bytes
---@param reservation SliceReservation
---@return ffi.cdata* pointer to the reserved slice
function ByteBuffer:fill(reservation, writer)
  assert(self.reservations[reservation] ~= nil, "ByteBuffer:fill: reservation must be unused")
  self.reservations[reservation] = nil
  return self.buffer + reservation.offset
end

-- Retrieves the buffer as a string
---@return string
function ByteBuffer:toString()
  assert(next(self.reservations) == nil, "ByteBuffer:buffer: reservations must be empty to convert to string")
  return ffi.string(self.buffer, self.cursor)
end

return {
  createByteBuffer = createByteBuffer;
}
