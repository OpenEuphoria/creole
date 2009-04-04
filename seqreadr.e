-- Tommy's I/O Library: Sequence Readers
-- Copyright (C) 2006 Tommy Carlier
-- tommy online: http://users.telenet.be/tommycarlier
-- tommy.blog: http://tommycarlier.blogspot.com/

include txtreadr.e

sequence readers
readers = {}

constant
	SEQUENCE_DATA = 1,
	SEQUENCE_LOCATION = 2

function open_method(sequence data)
	integer index
	
	index = find(0, readers)
	if index > 0 then
		readers[index] = {data, 1}
		return index
	else
		readers = append(readers, {data, 1})
		return length(readers)
	end if
end function

procedure close_method(integer r)
	if r > 0 and r <= length(readers) then
		readers[r] = 0
	end if
end procedure

function readchars_method(integer r, integer count)
	integer location
	sequence data, s
	
	if count = 0 then return {} end if
	
	s = readers[r]
	location = s[SEQUENCE_LOCATION]
	data = s[SEQUENCE_DATA]
	
	if location + count - 1 > length(data) then
		count = length(data) - location + 1
	end if
	readers[r][SEQUENCE_LOCATION] = location + count
	return data[location..location + count - 1]
end function

function readchar_method(integer r)
	integer location
	sequence data, s
	
	s = readers[r]
	location = s[SEQUENCE_LOCATION]
	data = s[SEQUENCE_DATA]
	
	if location > length(data) then return -1 end if
	readers[r][SEQUENCE_LOCATION] = location + 1
	return data[location]
end function

function readline_method(integer r)
	integer start, stop
	sequence data, s
	
	s = readers[r]
	start = s[SEQUENCE_LOCATION]
	data = s[SEQUENCE_DATA]
	
	if start > length(data) then return -1 end if
	
	stop = length(data)
	for i = start to length(data) do
		if data[i] = '\n' then
			stop = i
			exit
		end if
	end for
	readers[r][SEQUENCE_LOCATION] = stop + 1
	
	if data[stop] = '\n' then return data[start..stop-1]
	else return data[start..stop]
	end if
end function

global constant SEQUENCE_READER = create_textreader_type({
	routine_id("open_method"),
	routine_id("close_method"),
	routine_id("readchars_method"),
	routine_id("readchar_method"),
	routine_id("readline_method")
})

-- opens a sequence reader of the specified data
global function open_sequencereader(sequence data)
	return open_textreader(SEQUENCE_READER, {data})
end function