-- Tommy's I/O Library: File Readers
-- Copyright (C) 2006 Tommy Carlier
-- tommy online: http://users.telenet.be/tommycarlier
-- tommy.blog: http://tommycarlier.blogspot.com/

include std/get.e
include txtreadr.e

function open_method(sequence path)
	if length(path) = 0 then return 0 -- no path => standard input
	else return open(path, "r")
	end if
end function

procedure close_method(integer r)
	if r > 0 then close(r) end if
end procedure

function readchars_method(integer r, integer count)
	sequence data
	integer c
	
	data = repeat(0, count)
	for i = 1 to count do
		c = getc(r)
		if c >= 0 then data[i] = c
		else exit
		end if
	end for
	
	return data[1..count]
end function

function readchar_method(integer r)
	return getc(r)
end function

function readline_method(integer r)
	object line
	line = gets(r)
	if sequence(line) then
		if line[$] = '\n' then return line[1..$-1]
		else return line
		end if
	else return -1
	end if
end function

global constant FILE_READER = create_textreader_type({
	routine_id("open_method"),
	routine_id("close_method"),
	routine_id("readchars_method"),
	routine_id("readchar_method"),
	routine_id("readline_method")
})

-- opens a file reader of the specified path
-- if path is an empty sequence, the standard input will be used for reading
global function open_filereader(sequence path)
	return open_textreader(FILE_READER, {path})
end function
