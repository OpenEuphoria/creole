
namespace common

include std/filesys.e
include std/search.e
include std/sequence.e
include std/text.e

--include common_gen.e

export integer vFormat = 0
export integer vVerbose = 0
export integer vQuiet = 0

export sequence vDefaultExt = {
	"wiki", "txt", "creole"
}

export object vTemplateFile = 0
export object vTemplateFilename = 0

export sequence vOutDir = {}
export object vCurrentContext

export atom vStartTime = time()
export sequence vPublishedDate
export sequence vQuickLink = {}

export function fixup_seps(sequence pFileName)
	ifdef WINDOWS then
		return search:match_replace('/', pFileName, SLASH)
	elsedef
		return search:match_replace('\\', pFileName, SLASH)
	end ifdef
end function

export function make_filename(sequence pBaseName, sequence ext, object pLinkDir = 0)
	sequence lOutFile
	sequence lFileParts
	sequence lLinkDir
	
	if length(pBaseName) = 0 then
		return ""
	end if

	if length(ext) and ext[1] != '.' then
		ext = '.' & ext
	end if
	
	lOutFile = ""
	lFileParts = pathinfo(pBaseName)

	if sequence(pLinkDir) then
		lLinkDir = pLinkDir
	else
		lLinkDir = vOutDir
	end if
	
	if length(lLinkDir) = 0 then
		if length(lFileParts[PATH_DIR]) > 0 then
			lOutFile &= lFileParts[PATH_DIR] & SLASH
		end if
	else
		lOutFile = lLinkDir & SLASH
	end if
	lOutFile &= pBaseName
	lOutFile &= ext
	
	return fixup_seps(lOutFile)
end function

sequence bm_level_names = repeat("", 6)

export function bmcleanup(sequence pBookMark)
	sequence lText
	sequence lSortText
	sequence lDisplayText
	integer lPos
	
	-- The display text might be blank
	if length(pBookMark[3]) = 0 then
		lText = pBookMark[4]	-- Use bookmark name
	else
		lText = pBookMark[3]    -- Use display text
	end if
	
	-- For headings, strip off any leading numbering.
	if pBookMark[1] = 'h' then
		if find(lText[1], "123456789") then
			lPos = find(' ', lText)
			if lPos > 0 then
				lText = lText[lPos + 1 .. $]
			end if
		end if
		if pBookMark[2] < 3 then
			for i = pBookMark[2] to length(bm_level_names) do
				bm_level_names[i] = lText
			end for
		else
			for i = pBookMark[2] to length(bm_level_names) do
				bm_level_names[i] = bm_level_names[3]
			end for
		end if
	end if
	
	
	if pBookMark[2] > 1 then
		lDisplayText = lText & " (" & bm_level_names[pBookMark[2] - 1] & ")"
	else
		lDisplayText = lText
	end if
	
	-- Do a case-insensitive comparison
	lSortText = lower(lText)
	
	pBookMark = append(pBookMark, trim(lDisplayText))
	pBookMark = append(pBookMark, trim(lSortText))
	
	return pBookMark
end function

export function bmsort(sequence A, sequence B)
	return compare(A[$], B[$])
end function

export function bmdivide(sequence pOrigList)
	sequence lDividedList = {}
	integer lFirstChar
	integer lPrevSlot = 0

	for i = 1 to length(pOrigList) do
		if pOrigList[i][1] != 'h' then
			continue
		end if
		
		if pOrigList[i][2] > 4 then
			continue
		end if
		
		lFirstChar = pOrigList[i][$][1]
		if not find(lFirstChar, "abcdefghijklmnopqrstuvwxyz") then
			lFirstChar = '0'
		end if
		if lFirstChar != lPrevSlot then
			lDividedList = append(lDividedList, {})
			lPrevSlot = lFirstChar
		end if
		
		lDividedList[$] = append(lDividedList[$], pOrigList[i])
	end for
		
	return lDividedList
end function
