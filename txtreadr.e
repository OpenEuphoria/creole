-- Tommy's I/O Library: Text Readers
-- Copyright (C) 2006 Tommy Carlier
-- tommy online: http://users.telenet.be/tommycarlier
-- tommy.blog: http://tommycarlier.blogspot.com/

sequence textreader_types
textreader_types = {}

global type textreadertype(integer textreader_type)
	return textreader_type > 0 and textreader_type <= length(textreader_types)
end type

-- a text reader instance is a sequence of 2 integers: { type, instance }
global constant
	TEXTREADER_TYPE = 1,
	TEXTREADER_INSTANCE = 2

global type textreader(sequence r)
	return length(r) = 2
		and textreadertype(r[TEXTREADER_TYPE])
		and integer(r[TEXTREADER_INSTANCE])
end type

-- the methods (functions/procedures) a text reader type has to implement
global constant
	TEXTREADER_OPEN_METHOD = 1, -- function open_method(params) -- params can be anything
	TEXTREADER_CLOSE_METHOD = 2, -- procedure close_method(textreader r)
	TEXTREADER_READCHARS_METHOD = 3, -- function readchars_method(textreader r, integer count)
	TEXTREADER_READCHAR_METHOD = 4, -- function readchar_method(textreader r)
	TEXTREADER_READLINE_METHOD = 5 -- function readline_method(textreader r)

constant TEXTREADER_METHODS = 5

function call_function(textreader r, integer method, sequence params)
	return call_func(textreader_types[r[TEXTREADER_TYPE]][method], r[TEXTREADER_INSTANCE] & params)
end function

procedure call_procedure(textreader r, integer method, sequence params)
	call_proc(textreader_types[r[TEXTREADER_TYPE]][method], r[TEXTREADER_INSTANCE] & params)
end procedure


-- creates a new textreader type: methods is a sequence where each element is a routine-id of an implemented function or procedure
global function create_textreader_type(sequence methods)
	if length(methods) != TEXTREADER_METHODS then return 0 end if
	
	textreader_types = append(textreader_types, methods)
	return length(textreader_types)
end function

-- opens a textreader of the specified type with the specified parameters
global function open_textreader(textreadertype textreader_type, sequence params)
	return {textreader_type, call_func(textreader_types[textreader_type][TEXTREADER_OPEN_METHOD], params)}
end function

-- closes a textreader
global procedure close_textreader(textreader r)
	call_procedure(r, TEXTREADER_CLOSE_METHOD, {})
end procedure

-- reads the specified number of characters from the specified textreader
global function read_chars(textreader r, integer count)
	if count <= 0 then return {}
	else return call_function(r, TEXTREADER_READCHARS_METHOD, {count})
	end if
end function

-- reads 1 character from the specified textreader
global function read_char(textreader r)
	return call_function(r, TEXTREADER_READCHAR_METHOD, {})
end function

-- reads 1 line from the specified textreader
global function read_line(textreader r)
	return call_function(r, TEXTREADER_READLINE_METHOD, {})
end function

-- reads all the text from the specified reader as 1 large sequence of characters
global function read_all_text(textreader r)
	sequence data, buffer
	data = {}
	buffer = call_function(r, TEXTREADER_READCHARS_METHOD, {4096})
	while length(buffer) > 0 do
		data &= buffer
		buffer = call_function(r, TEXTREADER_READCHARS_METHOD, {4096})
	end while
	return data
end function

-- reads all the lines from the specified reader as a sequence, where each element is a line of characters
global function read_all_lines(textreader r)
	sequence lines
	object line
	lines = {}
	line = call_function(r, TEXTREADER_READLINE_METHOD, {})
	while sequence(line) do
		lines = append(lines, line)
		line = call_function(r, TEXTREADER_READLINE_METHOD, {})
	end while
	return lines
end function