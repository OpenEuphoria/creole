-- Kanarie Template System 1.8b
-- Copyright (C) 2004 - 2006 Tommy Carlier
-- http://users.telenet.be/tommycarlier
-- tommy.carlier@telenet.be

include std/wildcard.e
include txtreadr.e
include filreadr.e
include seqreadr.e
include std/sequence.e
include std/text.e

enum 
	COMPONENT_CLASS,
	LIST_CLASS

enum
	ELEMENT_TEXT,
	ELEMENT_LIST

enum
	TEMPLATE_TEXT,
	TEMPLATE_FIELD,
	TEMPLATE_INCLUDE,
	TEMPLATE_LIST,
	TEMPLATE_CONDITIONAL,
	TEMPLATE_END_LIST,
	TEMPLATE_SHORT_CONDITIONAL,
	TEMPLATE_IGNORE

constant
	ID_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_",
	SPACE_CHARS = " \t\n\r"

sequence data, current_template, template_dir = "./"
integer char, eof, open_char, close_char, list_char, condition_char, include_char, comment_char, anyvalue_char, ignore_char
atom readElementRoutine

data = repeat(-1, 32)
current_template = {}
char = -1
eof = 0

export function getTemplateDirectory()
	return template_dir
end function

export procedure setTemplateDirectory(sequence d)
	template_dir = d
end procedure

function createElement(integer class, integer parent)
	integer index
	index = find(-1, data)
	if index = 0 then
		index = length(data) + 1
		data &= repeat(-1, 32)
	end if
	data[index] = {class, {}, {}, {}, parent} -- {class, keys, values, types, parent}
	return index
end function

global function createData()
	--	create a new component
	return createElement(COMPONENT_CLASS, 0)
end function

global procedure closeData(integer data_component)
	--	close a data-component you don't need anymore
	sequence element, values, types, value_
	if data_component > 0 and data_component <= length(data) then
		element = data[data_component]
		values = element[3]
		types = element[4]
		for i = 1 to length(types) do
			if types[i] = ELEMENT_LIST then
				value_ = values[i]
				for j = 1 to length(value_) do
					closeData(value_[j])
				end for
			end if
		end for
		data[data_component] = -1
	end if
end procedure

global procedure setValue(integer parent, sequence id, object field_value)
	--	set the value of id in parent to field_value
	sequence element, keys, values, string, types
	integer index
	if parent > 0 and parent <= length(data) then
		if sequence(field_value) then string = field_value else string = sprint(field_value) end if
		element = data[parent]
		keys = element[2]
		values = element[3]
		types = element[4]
		index = find(id, keys)
		if index = 0 then
			keys = append(keys, id)
			values = append(values, string)
			types = append(types, ELEMENT_TEXT)
			element[2] = keys
		else
			values[index] = string
			types[index] = ELEMENT_TEXT
		end if
		element[3] = values
		element[4] = types
		data[parent] = element
	end if
end procedure

global procedure loadValue(integer parent, sequence id, sequence filename)
	--	set the value of id in parent to the text of the specified file
	integer file
	sequence text
	object line
	text = {}
	file = open(filename, "r")
	if file = -1 then return end if
	line = gets(file)
	while sequence(line) do
		text &= line
		line = gets(file)
	end while
	close(file)
	setValue(parent, id, text)
end procedure

global function addListItem(integer parent, sequence id)
	--	add the instance of a list id to parent
	sequence element, keys, values, types
	integer index, new_index
	if parent > 0 and parent <= length(data) then
		element = data[parent]
		keys = element[2]
		values = element[3]
		types = element[4]
		new_index = createElement(LIST_CLASS, parent)
		index = find(id, keys)
		if index = 0 then
			keys = append(keys, id)
			values = append(values, {new_index})
			types = append(types, ELEMENT_LIST)
			index = length(keys)
			element[2] = keys
		else
			values[index] &= new_index
			types[index] = ELEMENT_LIST
		end if
		element[3] = values
		element[4] = types
		data[parent] = element
		return new_index
	end if
	return -1
end function

--	start private parser-routines
function readElement_(textreader reader)
	return call_func(readElementRoutine, {reader})
end function

procedure skipSpace(textreader reader)
	while find(char, SPACE_CHARS) do
		char = read_char(reader)
	end while
	if char = -1 then eof = 1 end if
end procedure

function readId(textreader reader)
	sequence id
	id = {}
	skipSpace(reader)
	while find(char, ID_CHARS) do
		id &= char
		char = read_char(reader)
	end while
	if char = -1 then eof = 1 else skipSpace(reader) end if
	return id
end function

procedure readRedefinition(textreader reader) -- {? open={ close=} list=: condition== include=$ comment=* anyvalue=*, ignore=* }
	integer new_open_char, new_close_char, new_list_char, new_condition_char, new_include_char, 
		new_comment_char, new_anyvalue_char, new_ignore_char
	sequence var
	new_open_char = open_char
	new_close_char = close_char
	new_list_char = list_char
	new_condition_char = condition_char
	new_include_char = include_char
	new_comment_char = comment_char
	new_anyvalue_char = anyvalue_char
	new_ignore_char = ignore_char
	char = read_char(reader)
	while char != close_char and char != -1 do
		var = readId(reader)
		if char = '=' then 
			char = read_char(reader)
			skipSpace(reader)
		end if
		if equal(var, "open") then new_open_char = char
		elsif equal(var, "close") then new_close_char = char
		elsif equal(var, "list") then new_list_char = char
		elsif equal(var, "condition") then new_condition_char = char
		elsif equal(var, "include") then new_include_char = char
		elsif equal(var, "comment") then new_comment_char = char
		elsif equal(var, "anyvalue") then new_anyvalue_char = char
		elsif equal(var, "ignore") then new_ignore_char = char
		end if
		char = read_char(reader)
		skipSpace(reader)
	end while
	if char = -1 then eof = 1 return end if
	char = read_char(reader)
	open_char = new_open_char
	close_char = new_close_char
	list_char = new_list_char
	condition_char = new_condition_char
	include_char = new_include_char
	comment_char = new_comment_char
	anyvalue_char = new_anyvalue_char
	ignore_char = new_ignore_char
end procedure

function readTag(textreader reader)
	sequence id, element, values, child_values, child
	char = read_char(reader)
	if char = open_char then -- {{ => text
		char = read_char(reader)
		return {TEMPLATE_TEXT, {open_char}}
	elsif char = '?' then -- {? => redefinition
		readRedefinition(reader)
		return readElement_(reader)
	elsif char = list_char then
		char = read_char(reader)
		id = readId(reader)
		if char = close_char then -- {:id} => closing list tag
			char = read_char(reader)
			return {TEMPLATE_END_LIST, id}
		elsif char = condition_char then -- {:id=value:} => short condition
			char = read_char(reader)
			skipSpace(reader)
			values = {}
			while char != list_char and char != -1 do
				values &= char
				char = read_char(reader)
			end while
			if char = -1 then eof = 1 return {} end if
			while length(values) > 0 and find(values[length(values)],SPACE_CHARS) do values = values[1..length(values)-1] end while
			char = read_char(reader)
			while char != close_char and char != -1 do
				char = read_char(reader)
			end while
			if char = -1 then eof = 1 return {} end if
			char = read_char(reader)
			return {TEMPLATE_SHORT_CONDITIONAL, id, values}
		end if
	elsif char = include_char then -- {$file.x}
		char = read_char(reader)
		skipSpace(reader)
		id = {}
		while char != close_char and char != -1 do
			id &= char
			char = read_char(reader)
		end while
		if char = -1 then eof = 1 return {} end if
		char = read_char(reader)
		return {TEMPLATE_INCLUDE, id}
	elsif char = comment_char then -- {* comments *}
		char = read_char(reader)
		while 1 do
			while char != comment_char and char != -1 do
				char = read_char(reader)
			end while
			if char = -1 then eof = 1 return {} end if
			char = read_char(reader)
			if char = close_char then exit end if
		end while
		skipSpace(reader)
	elsif char = ignore_char then -- {- ignore kanarie code -}
		char = read_char(reader)
		id = {}
		while 1 do
			while char != ignore_char and char != -1 do
				id &= char
				char = read_char(reader)
			end while
			if char = -1 then eof = 1 return {} end if
			char = read_char(reader)
			if char = close_char then 
				char = read_char(reader)
				exit 
			end if
		end while
		return {TEMPLATE_TEXT, id}
	end if
	id = readId(reader)
	if char = list_char then -- {id:} => list tag
		char = read_char(reader)
		while char != close_char and char != -1 do
			char = read_char(reader)
		end while
		if char = -1 then eof = 1 return {} end if
		char = read_char(reader)
		child_values = {}
		while not eof do
			element = readElement_(reader)
			if length(element) > 0 then
				if element[1] = TEMPLATE_END_LIST then
					if equal(element[2], id) then
						exit
					else
						element[1] = TEMPLATE_TEXT
						child_values = append(child_values, element)
					end if
				else
					child_values = append(child_values, element)
				end if
			end if
		end while
		return {TEMPLATE_LIST, id, child_values}
	elsif char = condition_char then -- {id=value:} => condition container
		char = read_char(reader)
		skipSpace(reader)
		values = {}
		while char != list_char and char != -1 do
			values &= char
			char = read_char(reader)
		end while
		if char = -1 then eof = 1 return {} end if
		while length(values) > 0 and find(values[length(values)],SPACE_CHARS) do values = values[1..length(values)-1] end while
		char = read_char(reader)
		while char != close_char and char != -1 do
			char = read_char(reader)
		end while
		if char = -1 then eof = 1 return {} end if
		char = read_char(reader)
		values = {values}
		child_values = {}
		child = {}
		while not eof do
			element = readElement_(reader)
			if length(element) > 0 then
				if element[1] = TEMPLATE_END_LIST then
					if equal(element[2], id) then
						exit
					end if
				elsif element[1] = TEMPLATE_SHORT_CONDITIONAL then
					if equal(element[2], id) then
						child_values = append(child_values, child)
						child = {}
						element[1] = TEMPLATE_CONDITIONAL
						values = append(values, element[3])
					end if
				else
					child = append(child, element)
				end if
			end if
		end while
		if length(child) > 0 then
			child_values = append(child_values, child)
			child = {}
		end if
		return {TEMPLATE_CONDITIONAL, id, values, child_values}
	elsif char = close_char then -- {id} => field
		char = read_char(reader)
		return {TEMPLATE_FIELD, id}
	else
		while char != close_char and char != -1 do
			char = read_char(reader)
		end while
		if char = -1 then eof = 1 return {} end if
		char = read_char(reader)
		return {TEMPLATE_FIELD, id}
	end if
end function

function readText(textreader reader)
	sequence text
	text = {char}
	char = read_char(reader)
	while char != open_char and char != -1 do
		text &= char
		char = read_char(reader)
	end while
	if char = -1 then eof = 1 end if
	return {TEMPLATE_TEXT, text}
end function

function readElement(textreader reader)
	if char = open_char then
		return readTag(reader)
	else
		return readText(reader)
	end if
end function
readElementRoutine = routine_id("readElement")
--	end private parser-routines

function defaultTagCharacter(integer newChar, integer oldChar, integer defaultChar)
	if newChar = -1 then return oldChar
	elsif newChar = 0 then return defaultChar
	else return newChar
	end if
end function

integer 
	defaultOpenChar = 0, defaultCloseChar = 0, defaultListChar = 0, defaultConditionChar = 0, 
	defaultIncludeChar = 0, defaultCommentChar = 0, defaultAnyValueChar = 0, defaultIgnoreChar = 0

global procedure setDefaultTagCharacters(integer openChar, integer closeChar, integer listChar, integer conditionChar, 
		integer includeChar, integer commentChar, integer anyValueChar, integer ignoreChar)
	--	set the default tag-characters: -1 = ignore character, 0 = reset character to system-default
	defaultOpenChar = defaultTagCharacter(openChar, defaultOpenChar, '{')
	defaultCloseChar = defaultTagCharacter(closeChar, defaultCloseChar, '}')
	defaultListChar = defaultTagCharacter(listChar, defaultListChar, ':')
	defaultConditionChar = defaultTagCharacter(conditionChar, defaultConditionChar, '=')
	defaultIncludeChar = defaultTagCharacter(includeChar, defaultIncludeChar, '$')
	defaultCommentChar = defaultTagCharacter(commentChar, defaultCommentChar, '*')
	defaultAnyValueChar = defaultTagCharacter(anyValueChar, defaultAnyValueChar, '*')
	defaultIgnoreChar = defaultTagCharacter(ignoreChar, defaultIgnoreChar, '-')
end procedure
setDefaultTagCharacters(0, 0, 0, 0, 0, 0, 0, 0)

global function loadTemplateFromTextReader(textreader reader)
	--	load a Kanarie-template from a text reader
	sequence element
	current_template = {}
	open_char = defaultOpenChar
	close_char = defaultCloseChar
	list_char = defaultListChar
	condition_char = defaultConditionChar
	include_char = defaultIncludeChar
	comment_char = defaultCommentChar
	anyvalue_char = defaultAnyValueChar
	ignore_char = defaultIgnoreChar
	char = read_char(reader)
	if char = -1 then eof = 1 else eof = 0 end if
	while not eof do
		element = readElement(reader)
		if length(element) > 0 then current_template = append(current_template, element) end if
	end while
	return current_template
end function

global function loadTemplateFromFile(sequence filename)
	--	load a Kanarie-template from a file
	textreader reader
	sequence template, tmp_template
	reader = open_filereader(template_dir & filename)
	if reader[TEXTREADER_INSTANCE] = -1 then 
		return -1
	end if
	template = loadTemplateFromTextReader(reader)
	close_textreader(reader)

	integer idx = 1
	while idx <= length(template) do
		if template[idx][1] = TEMPLATE_INCLUDE then
			tmp_template = loadTemplateFromFile(template[idx][2])
			template = remove(template, idx)
			template = splice(template, tmp_template, idx)
		end if
		idx += 1
	end while

	return template
end function

global function loadTemplateFromSequence(sequence s)
	--	load a Kanarie-template from a sequence
	textreader reader
	sequence template
	reader = open_sequencereader(s)
	template = loadTemplateFromTextReader(reader)
	close_textreader(reader)
	return template
end function

function getFieldValue(integer data_component, sequence fieldName)
	--	returns the value of a field
	sequence component, keys, values, types
	integer parent
	component = data[data_component]
	keys = component[2]
	values = component[3]
	types = component[4]
	for i = 1 to length(keys) do
		if equal(keys[i], fieldName) and types[i] = ELEMENT_TEXT then return values[i] end if
	end for
	parent = component[5]
	if parent > 0 and parent <= length(data) then return getFieldValue(parent, fieldName)
	else return {}
	end if
end function

atom generateRoutine
function generate_(integer data_component, sequence template)
	return call_func(generateRoutine, {data_component, template})
end function

function getConditionalValue(integer data_component, sequence element)
	--	returns the value of a conditional field
	sequence id, value_, component, keys, values, types, data_element
	integer parent
	id = element[2]
	value_ = element[3]
	component = data[data_component]
	keys = component[2]
	values = component[3]
	types = component[4]
	for j = 1 to length(keys) do
		if equal(keys[j], id) and types[j] = ELEMENT_TEXT then
			data_element = values[j]
			for k = 1 to length(value_) do
				if equal(data_element, value_[k]) or (length(data_element) > 0 and equal(value_[k], {anyvalue_char})) then
					return generate_(data_component, element[4][k])
				end if
			end for
			exit
		end if
	end for
	if length(value_) > 1 then
		for k = 1 to length(value_) do
			if length(value_[k]) = 0 then
				return generate_(data_component, element[4][k])
			end if
		end for
	end if
	parent = component[5]
	if parent > 0 and parent <= length(data) then return getConditionalValue(parent, element)
	else return {}
	end if
end function

global function generate(integer data_component, sequence template)
	--	generate a string-sequence by combining a data-component with a template
	sequence generated_text, element, component, keys, id, values, types
	integer element_type, file
	object line, tmp_template
	generated_text = {}
	if data_component > 0 and data_component <= length(data) then component = data[data_component] else return "" end if
	for i = 1 to length(template) do
		element = template[i]
		element_type = element[1]
		if element_type = TEMPLATE_TEXT then
			generated_text &= element[2]
		elsif element_type = TEMPLATE_FIELD then
			generated_text &= getFieldValue(data_component, element[2])
		elsif element_type = TEMPLATE_INCLUDE then
			--tmp_template = loadTemplateFromFile(element[2])
			--template = splice(template, tmp_template, i)
			--retry
			-- ignore
		elsif element_type = TEMPLATE_LIST then
			id = element[2]
			keys = component[2]
			values = component[3]
			types = component[4]
			for j = 1 to length(keys) do
				if equal(keys[j], id) and types[j] = ELEMENT_LIST then
					values = values[j]
					for k = 1 to length(values) do
						generated_text &= generate(values[k], element[3])
					end for
					exit
				end if
			end for
		elsif element_type = TEMPLATE_CONDITIONAL then
			generated_text &= getConditionalValue(data_component, element)
		end if
	end for
	return generated_text
end function
generateRoutine = routine_id("generate")

