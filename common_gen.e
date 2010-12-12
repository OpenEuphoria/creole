--
-- Common Generator Routines
--

namespace common_gen

include std/sequence.e
include std/text.e

enum GEN_NAME, GEN_EXTENSION, GEN_RID

export sequence generators = {}
export integer format = 0

--**
-- Get a pretty list of the available generator names
--

export function names()
	return join(vslice(generators, 1), ", ")
end function

--**
-- Register a new generator
--
-- Parameters:
--   * name - Name to display to user from pick list
--   * ext - Extension to write files as
--   * rid - Creole generate routine id
--

export procedure register(sequence name, sequence ext, integer rid)
	generators = append(generators, { name, ext, rid })
end procedure

--**
-- Set the format/generator to use during this instance
--
-- Parameters:
--   * name - name of the generator as defined by the [[:register]] and [[:names]] methods.
--
-- Returns:
--   0 on invalid format, otherwise an index value for the format

export function set(sequence name)
	for i = 1 to length(generators) do
		if equal(upper(name), upper(generators[i][GEN_NAME])) then
			format = i
			return format
		end if
	end for
	
	return 0
end function

--**
-- Get the name for the current generator/format
--

export function name()
	return generators[format][GEN_NAME]
end function

--**
-- Get the extension for the current generator/format
--
-- Parameters:
--   * include_period - include a leading period?
--

export function extension(integer include_period=1)
	sequence base = generators[format][GEN_EXTENSION]
	
	if include_period then
		return '.' & base
	end if
	
	return base
end function

--**
-- Get the generator routine for the current generator/format
--

export function rid()
	return generators[format][GEN_RID]
end function
