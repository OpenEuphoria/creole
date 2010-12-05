/**************************************************************************

file: htmlindx.ex

		This software is provided 'as-is', without any express or implied
		warranty. In no event will the authors be held liable for damages
		of any kind arising from the use of this software.

		Permission is hereby granted to anyone to use this software for any
		purpose, including commercial applications, and to alter it and/or
		redistribute it freely, subject to the following restrictions:

		1. The origin of this software must not be misrepresented; you must
		   not claim that you wrote the original software. If you use this
		   software in a product, an acknowledgment within documentation of
		   said product would be appreciated but is not required.

		2. Altered source versions must be plainly marked as such, and must
		   not be misrepresented as being the original software.

		3. This notice may not be removed or altered from any distribution
		   of the source.

		4. Derivative works are permitted, but they must carry this notice
		   in full and credit the original source.


						~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


version:        Initial version, September 2009
authors:        Derek Parnell, Melbourne, Australia.


**************************************************************************/

/*
	This takes zero or more file names from the command line. For each
	file that begins with the regular expression "<html*>" it extracts
	all the words and produces a cross-reference index, in HTML form.

	If no files are on the command line, then it looks at each file in
	the current directory.

*/

include std/map.e
include std/datetime.e
include std/filesys.e
include std/text.e
include std/io.e
include std/sequence.e
include std/convert.e
include std/cmdline.e
include std/search.e
include std/regex.e
include std/types.e
include std/sort.e
include std/error.e

enum -- IndexEntry
	IE_Word,	-- string
	IE_File,	-- string
	IE_Anchor,	-- string
	IE_Before,  -- string array
	IE_After,   -- string array
	$
constant New_IndexEntry = { "", "", "", {}, {}}


sequence vSourceFiles = {} --     string array
map vExcludedWords = map:new() 
map vIncludedWords = map:new()

integer vMinSize = 3
integer vMaxSize = 20
integer vWordCountLimit = 90
integer vBeforeMax = 12
integer vAfterMax = 12

integer vVerbose = 0 -- bool
integer vSilent = 0 -- bool

sequence vFileTypes = {"html", "htm", "dhtml", "xml"}

sequence vWordList = {} --  IndexEntry array

integer vMaxEntriesPerFile = 50
integer vColumnsPerFile = 3

sequence vBaseDir = ""
sequence vOutputDir
sequence vTemplateDir = ""

map vTemplates = map:new() -- string[][string]
sequence vToday

------------------------------------------------
procedure main(sequence pArgs)
------------------------------------------------
	-- Grab the current date and time then format it for display.
	vToday = datetime:format(now_gmt())

	-- Get all the words that must be excluded
	LoadWords( vExcludedWords, locate_file("words.out"))
	
	-- Get all the words that must be included
	LoadWords( vIncludedWords, locate_file("words.in") )

	-- Build a list of target files to scan.
	ProcessArgs( pArgs[3..$] )

	-- Build a set of index entries.
	ProgressMsg("\nBuild index entries")
	for i = 1 to length(vSourceFiles) do
	    ProgressMsg("-")
	    ProcessFile( vSourceFiles[i] )
	end for
	ProgressMsg("\n")

	-- Create the index files.
	Write_Name_Index()

end procedure

------------------------------------------------
procedure AddSource(sequence pPath)
------------------------------------------------
	-- If the given file path is is the right type and we haven't seen it
	-- before, add it to the list of files to examine.
	
	sequence lExt
	
	lExt = fileext(pPath)
	if find(lower(lExt), vFileTypes) then
		pPath = canonical_path(pPath, 0, 1)
		if not find(pPath, vSourceFiles) then
			ProgressMsg(".")
			vSourceFiles = append(vSourceFiles, pPath)
		end if
	end if

end procedure

constant option_definition = {
	{ "v", "verbose",  "Verbose screen output",       {NO_PARAMETER}, -1},
	{ "s", "silent",   "No screen output",            {NO_PARAMETER}, -1},
	{ "t", "templates","Template Directory",          {HAS_PARAMETER, ONCE}, -1},
	{ "c", "col",      "Columns per File. Default is 3",            {HAS_PARAMETER, ONCE} , -1 },
	{ "m", "max",      "Maximum Entries per index file. Default is 50",    {HAS_PARAMETER, ONCE}, -1 },
	{ "a", "after",    "Maximum 'after' words. Default is 12",       {HAS_PARAMETER, ONCE}, -1 },
	{ "b", "before",   "Maximum 'before' words. Default is 12",      {HAS_PARAMETER, ONCE}, -1 },
	{  0,  0, 0, 0, -1},
	$
}

constant vHelpText = {
	"Create a KWIC index from HTML files.",
	"Either a directory or filename is supplied on the command line",
	"and a set of index HTML files is created in the same directory",
	"as the input files.",
	"",
	"If no input files supplied, the current directory is assumed.",
	$
	}
constant vParsingOptions = {HELP_RID, vHelpText}
constant vBadSourceText = "Must have either a single directory or a set of file names on command line."
------------------------------------------------
procedure ProcessArgs(sequence pArgs)
------------------------------------------------
	sequence lSource
	integer vSourceType = 0

	-- get the command line args.
	map:map opts = cmd_parse(option_definition, vParsingOptions)

	vVerbose           = map:get(opts, "verbose", 0)
	vSilent            = map:get(opts, "silent", 0)
	vTemplateDir       = map:get(opts, "templates", "")
	vColumnsPerFile    = to_integer(map:get(opts, "col", "3"))
	vMaxEntriesPerFile = to_integer(map:get(opts, "max", "50"))	
	vAfterMax          = to_integer(map:get(opts, "after", "12"))
	vBeforeMax         = to_integer(map:get(opts, "before", "12"))
	lSource            = map:get(opts, cmdline:EXTRAS)
	
	-- Get list of source files from command line args.
	for i = 1 to length(lSource) do
		sequence lArg = canonical_path(lSource[i])
		if file_type(lArg) = FILETYPE_FILE then
			if vSourceType = 2 then
				crash(vBadSourceText)
			end if
			vSourceType = 1
			
			if length(vBaseDir) = 0 then
				vBaseDir = dirname(lArg) & SLASH
			end if
			
			if not equal(pathname(vBaseDir), pathname(lArg)) then
				crash("All source files must be in the same directory.")
			end if
			
			AddSource(lArg)
		else
			if vSourceType = 1 then
				crash(vBadSourceText)
			end if
			ProgressMsg("\nSelecting files")
			if length(vBaseDir) = 0 then
				vBaseDir = lArg
				if not ends(SLASH, vBaseDir) then
					vBaseDir &= SLASH
				end if
				GatherFilePaths(lArg)
			else
				crash("Must have only a single directory on command line.")
			end if
		end if
	end for

	-- If there were none on the command line, get files from current directory.
	if length(vSourceFiles) = 0 then
		vBaseDir = init_curdir()
		if not ends(SLASH, vBaseDir) then
			vBaseDir &= SLASH
		end if
		GatherFilePaths(vBaseDir)
	end if

	ProgressMsg(sprintf("\n%d files will be used to build the index\n", length(vSourceFiles)))

	-- Get the templates to use.
	if length(vTemplateDir) = 0 then
		vTemplateDir = vBaseDir
	end if
	GetTemplates(vTemplateDir)
	
	-- Get any subject matter exclude/include words from current directory.
	LoadWords(vExcludedWords, "topic.out")
	LoadWords(vIncludedWords, "topic.in")

end procedure

------------------------------------------------
procedure GatherFilePaths(sequence pParent)
------------------------------------------------
	-- Given a directory, get all the possible source files contained in it.
	object lArgs
	object lIdxPattern
	
	lArgs = dir(pParent)
	if atom(lArgs) then
		return
	end if
	
	if not ends(SLASH, pParent) then
		pParent &= SLASH
	end if
	
	-- Define set of file names to exclude from being source files.
	lIdxPattern = regex:new(`^.*[\\/]index.*\.htm`)
	
	-- Build a list of target files to scan.
	for i = 1 to length(lArgs) do
		sequence lArg
		lArg = lArgs[i][D_NAME]
		
		-- Ignore these all directories whose name starts with a dot.
   		if lArg[1] = '.' then
   			continue
   		end if
   		
		lArg = pParent & lArg	-- Build the full path name.
		
		if file_type(lArg) = FILETYPE_FILE then
			if not has_match(lIdxPattern, lArg) then
				-- Ok to add to file set.
				AddSource(lArg)
			end if

		end if
	end for

end procedure

------------------------------------------------
procedure ProcessFile(sequence pFileName)
------------------------------------------------
	-- This routine examines a single file, collecting all the usable words from it.
	-- Usable words are those that begin with an alphabetic or '_' character and are not 
	-- inside an HTML tag or in quoted text or in a 'pre' section.
	
	sequence lFileText = ""
	integer lPos = 0
	integer lInTag = 0
	sequence lWord = ""
	sequence lAnchor = ""
	sequence lTag = ""
	integer lQuoted = 0
	integer lInPre = 0 -- depth counter

	-- Read the entire file into memory.
	lFileText = read_file(pFileName, TEXT_MODE)
	if not vSilent then
		writefln(" []", pFileName)
	end if

	-- Examine the file, one character at a time.	
	while lPos < length(lFileText) do
		integer ch
		
		-- Get the next character
		lPos += 1
		ch = lFileText[lPos]
		
		switch ch do
			case '&' then
				-- Special markup symbol, so just skip it.
				while lPos < length(lFileText) do
					lPos += 1
					ch = lFileText[lPos]
					if not t_alpha(ch) then
						if ch = ';' then
							lPos += 1
						end if
						exit
					else
						lPos += 1
					end if
				end while
			
			case '<' then
				-- For now, I'll assume that anything with the form '<'[a-z]
				-- or '</' or '<!' is a valid HTML tag.
				if not lInTag then
					if lPos+1 != length(lFileText) then
						integer nch = lFileText[lPos+1] 
						if t_alpha(nch) or nch = '/' or nch = '!' then
						
							-- A new tag has started so we must add any word
							-- gathered so far, before processing the new tag.
							if length(lWord) > 0 then
								AddWord(lWord, pFileName, lAnchor)
								lWord = ""
							end if
							
							-- Now we are in a tag.
							lInTag = 1
							lTag = ""
						end if
					end if
				-- else ignore nested '<' 
				end if
			
			case '>' then
	
				if lInTag then
					lInTag = 0
					lTag = lower(lTag) -- Case doesn't matter here.
					
					-- Check for anchors
					if length(lTag) > 1 and equal(lTag[1..2], "a ") then
						integer lNamePos
						lNamePos = match("name=", lTag)
						if lNamePos != 0 then
							-- Remember name of current anchor point. This is
							-- where the index will link to for the current word
							-- being gathered.
							lAnchor = trim(lTag[lNamePos+5 .. $])
						end if
						
					-- Check for start of pre.
					elsif length(lTag) >= 3 and equal(lTag[1..3], "pre") then
						lInPre += 1
						
					-- Check for end of pre.
					elsif length(lTag) >= 4 and equal(lTag[1..4], "/pre") then
						if lInPre > 0 then
							lInPre -= 1
						end if
	
					end if
				end if					
			case '"', '`' then
				if lQuoted = 0 then
					lQuoted = ch
				elsif ch = lQuoted then
					if lFileText[lPos - 1] != '\\' then
						lQuoted = 0
					end if
				end if
			case else
				if not lInTag then
					if not lQuoted then
						if not lInPre then
				
							if t_alpha(ch) or ch = '_' then
								lWord &= ch
								
							elsif t_digit(ch) then
								if length(lWord) > 0 then
									lWord &= ch
								end if
								
							elsif ch = '\'' then
								-- Handle embedded single quote
								if length(lWord) > 0 then
									if lPos != length(lFileText) then
										if t_alpha(lFileText[lPos+1]) then
											lWord &= ch
										end if
									end if
								end if
				
							else
								if length(lWord) > 0 then
									AddWord(lWord, pFileName, lAnchor)
									lWord = ""
								end if
							end if
						end if
					end if
				else
					lTag &= ch
				end if
		end switch
		
	end while

	-- Don't forget last word.		
	if length(lWord) > 0 then
		AddWord(lWord, pFileName, lAnchor)
	end if
end procedure

sequence vBefore = {}
sequence vAfter = {}
 
------------------------------------------------
procedure AddWord(sequence pWord, sequence pFile, sequence pAnchor)
------------------------------------------------

	
	if not Exclude_Word(pWord) then
		vWordList = append(vWordList, New_IndexEntry)
		vWordList[$][IE_Word] = pWord
		vWordList[$][IE_File] = pFile


		if length(pAnchor) > 0 then
			if pAnchor[1] = '"' then
				-- Strip off any enclosing quotes.
				integer lEnd = 2
				while lEnd <= length(pAnchor) and pAnchor[lEnd] != '"' do
					lEnd += 1
				end while
				pAnchor = pAnchor[2..lEnd-1]
			end if
		end if
		
		vWordList[$][IE_Anchor] = pAnchor

		-- Take a snapshot of the 'before' context'.
		vWordList[$][IE_Before] = vBefore
	end if

	Add_Before_Word(pWord, vBeforeMax)

	for i = length(vWordList)-1 to 1 by -1 do
		integer lLength
		lLength = 0
		for j = 1 to length(vWordList[i][IE_After]) do
			lLength += length(vWordList[i][IE_After][j])
		end for
		if lLength >= vAfterMax then
			exit
		end if
		Add_After_Word(pWord, i, vAfterMax)
	end for
 
end procedure

integer vSortCntMax
integer vSortCnt
--------------------------------------------------
function Sort_Entry_Words(sequence A, sequence B)
--------------------------------------------------

	integer lRes
	if vSortCnt = 0 then
		puts(1, '.')
	end if
	vSortCnt += 1
	if vSortCnt = vSortCntMax then
		vSortCnt = 0
	end if
	
	lRes =  compare(lower(A[IE_Word]), lower(B[IE_Word]))
	if lRes != 0 then
		return lRes
	end if

	lRes =  compare(lower(A[IE_File]), lower(B[IE_File]))
	if lRes != 0 then
		return lRes
	end if

	return compare(lower(A[IE_Anchor]), lower(B[IE_Anchor]))

end function

with trace
------------------------------------------------
procedure LoadWords( map theMap, sequence pFileName)
------------------------------------------------
	sequence lFileText
	sequence lWords

	if not file_exists(pFileName) then
		return
	end if

	lFileText = read_file(pFileName, TEXT_MODE)
	lWords = split_any(lFileText, " \n\t")
	for i = 1 to length(lWords) do
		map:put(theMap, lower(lWords[i]), 1)
	end for

end procedure


--------------------------------------------------
procedure Write_Name_Index()
--------------------------------------------------
	sequence lPrev = {}
	sequence lRefFile = {}
	sequence lHREF = {}
	integer lIndex_Count= 0
	sequence lFrom = {}
	sequence lTo = {}
	integer lEntry_Count = 0
	sequence lCurrentName = {}
	integer lIndex_File = 0
	integer lWordsUsed_File = 0
	sequence lTopLevel = {}
	sequence lPageHeader = {}
	sequence lFileContent = {}
	
	if not vSilent then
		writefln("\nSorting [] index entries", length(vWordList))
	end if
	vSortCnt = 0
	vSortCntMax = floor(length(vWordList) / 5)
	vWordList = custom_sort(routine_id("Sort_Entry_Words"), vWordList) 

	vOutputDir = vBaseDir

	if vOutputDir[$] != SLASH then
		vOutputDir &= SLASH
	end if

	ProgressMsg("\nCreating Index Subranges")
	
	-- First pass creates the index sub ranges.
	for i = 1 to length(vWordList) do
		sequence x
		sequence curword
		x = vWordList[i]
		curword = lower(x[IE_Word])
		
		if not equal(curword, lPrev) then
			if ((lEntry_Count = 0) or (lEntry_Count > vMaxEntriesPerFile)) then
				if (lEntry_Count != 0) then
					-- Close off current file.
					ProgressMsg(".")
					lPageHeader = append(lPageHeader, 
										text:format(`[]&nbsp;&nbsp;-&nbsp;&nbsp;[]`,
												{lFrom, lTo})
										)
					lTopLevel = append(lTopLevel, 
										text:format(`<a href="[]">[]</a><br/>`,
											{lCurrentName, lPageHeader[$]})
										)
				end if
				lFrom = curword
				lIndex_Count += 1
				lCurrentName = text:format("index_[z:3].html", lIndex_Count)
				lEntry_Count = 1
			end if

			lTo = x[IE_Word]
			lPrev = curword
			lEntry_Count += 1
		end if
	end for
	
	if (lEntry_Count != 0) then
		-- Close off current file.
		ProgressMsg(".")
		lPageHeader = append(lPageHeader, 
							text:format(`[]&nbsp;&nbsp;-&nbsp;&nbsp;[]`,
									{lFrom, lTo})
							)
		lTopLevel = append(lTopLevel, 
							text:format(`<a href="[]">[]</a><br/>`,
								{lCurrentName, lPageHeader[$]})
							)
	end if


	ProgressMsg(text:format("\n Generating [] index files", lIndex_Count))
	-- Second pass generates the files.
	lEntry_Count = 0
	lPrev = ""
	lIndex_Count = 0
	lRefFile = ""
	lCurrentName = ""
	lWordsUsed_File = open(vOutputDir & "words_used.txt", "w")

	for i = 1 to length(vWordList) do
		sequence x
		sequence curword
		x = vWordList[i]
		curword = lower(x[IE_Word])
		if not equal(curword, lPrev) then
			if ((lEntry_Count = 0) or (lEntry_Count > vMaxEntriesPerFile)) then
				if (lEntry_Count != 0) then
					-- Create the next index file
					Write_Index_File(lIndex_Count, lPageHeader, lFileContent)
					ProgressMsg(".")
				end if
				lIndex_Count += 1
				lFileContent = ""
				lEntry_Count = 1
			end if
			lFileContent = append(lFileContent, text:format("<strong>[]</strong><br/>\n", {x[IE_Word]}))
			
			lPrev = curword
			lRefFile = ""
			lEntry_Count += 1
			writefln(lWordsUsed_File, "[]", x[IE_Word])
		end if

		lHREF = filename(x[IE_File])
		if length(x[IE_Anchor]) > 0 then
			lHREF  &= "#" & x[IE_Anchor]
		end if

		if not equal(lRefFile, lHREF) then
			sequence lContext
			
			lContext = ""
			for j = 1 to length(x[IE_Before]) do
				sequence s
				s = x[IE_Before][j]
				if (length(lContext) > 0) then
					lContext &= " "
				end if
				lContext &= s
			end for
			
			lContext &= " " & x[IE_Word]
			
			for j = 1 to length(x[IE_After]) do
				sequence s
				s = x[IE_After][j]
				if (length(lContext) > 0) then
					lContext &= " "
				end if
				lContext &= s
			end for
			
			lFileContent[$] &= text:format(
					`<a href="[]" class="ref"><span class="ref">[]</span></a><br/>
					`,
					{lHREF, lContext})
			lRefFile = lHREF
		end if
	end for
	close(lWordsUsed_File)


	if (lEntry_Count != 0) then
		-- Write last file.
		Write_Index_File(lIndex_Count, lPageHeader, lFileContent)

		-- Create the master index file.
		lIndex_File = open(vOutputDir & "index_000.html", "w")
		Write_Template_Block(lIndex_File, "", "", "DOCTYPE")
		Write_Template_Block(lIndex_File, "", "", "DOCSTART")
		Write_Template_Block(lIndex_File, "<head>", "</head>", "FORMHEAD")

		writefln(lIndex_File, "<body>")
		
		Write_Template_Block(lIndex_File, `<div id="heading">`, `</div>`, "HEADER")

		Write_Table(lIndex_File, vColumnsPerFile, lTopLevel)

		Write_Template_Block(lIndex_File, `<div id="footer">`, `</div>`, "FOOTER")
		
		writefln(lIndex_File, "</body>")
		writefln(lIndex_File, "</html>")
		close(lIndex_File)
	end if

	ProgressMsg("\n")
end procedure
 
------------------------------------------------
procedure ProgressMsg(sequence pMsg)
------------------------------------------------
	if (vVerbose) then
		writef(pMsg)
	end if
end procedure

------------------------------------------------
procedure GetTemplates(sequence pDir)
------------------------------------------------

	sequence lFileName
	sequence lLines
	sequence lSection

	lFileName = pDir & "htmlindx.templates"
	if not file_exists(lFileName) then
		return
	end if
	
	lLines = read_lines(lFileName)
	for i = 1 to length(lLines) do
		sequence lLine
		lLine = lLines[i]
		
		lLine = trim(lLine)
		if length(lLine) = 0 then
			continue
		end if
				
		if lLine[1] = '[' and lLine[$] = ']' then
			lSection = upper(trim(lLine[2 .. $-1]))
			
		elsif length(lSection) > 0 then
			map:put (vTemplates, lSection, lLine, APPEND)
		end if
	end for
end procedure

--------------------------------------------------
procedure Write_Template_Block(integer pFile, sequence pPrefix, sequence pSuffix, sequence pSection)
--------------------------------------------------

	if length(pPrefix) > 0 then
		writefln(pFile, pPrefix)
	end if

	if map:has(vTemplates, pSection) then
		sequence lLines
		lLines = map:get(vTemplates, pSection, "")
		for i = 1 to length(lLines) do
			writefln(pFile, lLines[i], {"today=" & vToday})
		end for
	end if
	
	if length(pSuffix) > 0 then
		writefln(pFile, pSuffix)
	end if

end procedure

--------------------------------------------------
procedure Write_Table(integer pFile, integer pNumCols, sequence pEntries, sequence pStyle="index")
--------------------------------------------------

	integer lDepth = 0

	writefln(pFile, `<div id="[]">`, pStyle)
	writefln(pFile, `<table id="[]">`, pStyle)
	lDepth = floor((pNumCols - 1 + length(pEntries)) / pNumCols)
	for i = 1 to lDepth do
		integer k
		writefln(pFile, "<tr>")
		k = i
		for j = 1 to  pNumCols do
			if (k < length(pEntries)) then
				writefln(pFile, "<td>[]</td>", {pEntries[k]})
			else
				writefln(pFile, "<td>&nbsp;</td>")
			end if
			k += lDepth
		end for
		writefln(pFile, "</tr>")
	end for

	writefln(pFile, "</table>")
	writefln(pFile, "</div>")
end procedure

--------------------------------------------------
procedure Write_Index_File(integer pIndex_Count, sequence pPageHeaders, sequence pFileContent)
--------------------------------------------------

	sequence lCurrentName
	integer lFile

	lCurrentName = text:format("index_[z:3].html", pIndex_Count)
	lFile = open(vOutputDir & lCurrentName, "w")

	Write_Template_Block(lFile, "", "", "DOCTYPE")
	Write_Template_Block(lFile, "", "", "DOCSTART")
	Write_Template_Block(lFile, `<head>`, `</head>`, "FORMHEAD")

	writefln(lFile, `<body>`)
	writefln(lFile, `<a align=right href="index_000.html">Master Index</A>`)

	Write_Template_Block(lFile, `<div id="header">`, `</div>`, "HEADER")
	writefln(lFile, `<h2>[]</h2>`, pPageHeaders[pIndex_Count])

	Write_Table(lFile, vColumnsPerFile, pFileContent, "subrange")
	writefln(lFile, `<br/><a align=right href="index_000.html">Master Index</a>`)

	Write_Template_Block(lFile, `<div id="footer">`, `</div>`, "FOOTER")
	writefln(lFile, "</body>\n</html>")
	close(lFile)
	ProgressMsg(":")
end procedure

--------------------------------------------------
procedure Add_Before_Word(sequence pWord, integer pMaxLength)
--------------------------------------------------
	integer lTotalLength
	loop do
		lTotalLength = 0
		for i = 1 to length(vBefore) do
			lTotalLength += length(vBefore[i])
		end for
		
		if lTotalLength >= pMaxLength then
			for i = 2 to length(vBefore) do
				vBefore[i-1] = vBefore[i]
			end for
			vBefore = vBefore[1.. $-1]
		end if
		until lTotalLength < pMaxLength
	end loop

	vBefore = append(vBefore, pWord)
end procedure

--------------------------------------------------
procedure Add_After_Word(sequence pWord, integer pContext, integer pMaxLength)
--------------------------------------------------
	integer lTotalLength

	lTotalLength = 0
	for i = 1 to length(vWordList[pContext][IE_After]) do
		lTotalLength += length(vWordList[pContext][IE_After][i])
	end for
		
	if lTotalLength < pMaxLength then
		vWordList[pContext][IE_After] = append(vWordList[pContext][IE_After], pWord)
	end if
end procedure

--------------------------------------------------
function Exclude_Word( sequence pWord)
--------------------------------------------------
	sequence lLowerWord

	-- Make sure words explicitly included are not checked for exclusion.
	if map:has(vIncludedWords, pWord) then
		return 0
	end if

	lLowerWord = lower(pWord)
	

	if ends("'s", lLowerWord) then
		lLowerWord = lLowerWord[1 .. $-2]
	end if

	if length(lLowerWord) < vMinSize then
		return 1
	end if

	if length(lLowerWord) > vMaxSize then
		return 1
	end if

	-- Exclude "_<digit>..." words.
	if lLowerWord[1] = '_' then
		if t_digit(lLowerWord[2]) then
			return 1
		end if
	end if
	
	
	
	if map:has(vExcludedWords, lLowerWord) then
		return 1
	end if

	/* Exclude any word ending in ...
		"'t"
		"'ll"
		"'m"
		"'ve"
		"'re"
	*/
	if ends("'t", lLowerWord) then
		return 1
	end if
	if ends("'ll", lLowerWord) then
		return 1
	end if
	if ends("'m", lLowerWord) then
		return 1
	end if
	if ends("'ve", lLowerWord) then
		return 1
	end if
	if ends("'re", lLowerWord) then
		return 1
	end if

	/* Exclude words ending in ... if their root is already excluded.
		"ing"
		"ly"
		"ed"
		"ied"
		greater 4 chars.
	*/
	/* Exclude words starting with ... if their root is already excluded.
		"un"
		"mis"
		"de"
		greater 4 chars.
	*/
	if length(pWord) >= 5 then
		sequence lWordRoot = lLowerWord

		if ends("ing", lLowerWord) then
			lWordRoot = lLowerWord[1 .. $-3]

			-- Check for words like 'running' that have a duplicated char
			--   prior to the 'ing' suffix.
			if length(lWordRoot) >= 2 then
				if lWordRoot[$] = lWordRoot[$-1] then
					lWordRoot = lWordRoot[1 .. $-1]
				end if
			end if

		elsif ends("ily", lLowerWord) then
			lWordRoot = lLowerWord[1 .. $-3] & "y"
		elsif ends("ies", lLowerWord) then
			lWordRoot = lLowerWord[1 .. $-3] & "y"
		elsif ends("ied", lLowerWord) then
			lWordRoot = lLowerWord[1 .. $-3] & "y"
		elsif ends("ier", lLowerWord) then
			lWordRoot = lLowerWord[1 .. $-3] & "y"
		elsif ends("ly", lLowerWord) then
			lWordRoot = lLowerWord[1 .. $-2]
		elsif ends("ed", lLowerWord) then
			lWordRoot = lLowerWord[1 .. $-2]
		elsif ends("er", lLowerWord) then
			lWordRoot = lLowerWord[1 .. $-2]
		elsif ends("es", lLowerWord) then
			lWordRoot = lLowerWord[1 .. $-2]
		elsif ends("s", lLowerWord) then
			lWordRoot = lLowerWord[1 .. $-1]
		end if
		
		if begins("mis", lLowerWord) then
			lWordRoot = lLowerWord[4..$]
		elsif begins("un", lLowerWord) then
			lWordRoot = lLowerWord[3..$]
		elsif begins("de", lLowerWord) then
			lWordRoot = lLowerWord[3..$]
		end if
		
		if length(lWordRoot) > 0 then
			if map:has(vExcludedWords, lWordRoot) then
				return 1
			end if
			if map:has(vExcludedWords, lWordRoot & 'e') then
				return 1
			end if
		end if
	end if

	-- Any word with three consecutive characters is excluded.
	for i = 3 to length(lLowerWord) do
		integer c
		c = lLowerWord[i]
		if c = lLowerWord[i-1] and c = lLowerWord[i-2] then
			return 1
		end if
	end for

	-- If I get here, it's to be included.
	return 0
end function

main(command_line())
