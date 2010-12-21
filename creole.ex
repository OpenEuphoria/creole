#!/usr/bin/env eui
include std/console.e
-- Standard library
include std/cmdline.e
include std/datetime.e
include std/filesys.e
include std/get.e
include std/io.e
include std/map.e
include std/search.e
include std/sequence.e
include std/sort.e
include std/text.e
include std/utils.e

-- Local includes
include creole.e
include common.e
include common_gen.e

-- Our generators
include html_gen.e
include latex_gen.e

-- Increment version number with each release, not really with each change
-- in the SCM

constant APP_VERSION = "1.0.0"

sequence KnownWikis  = {
	{ "WIKIPEDIA",  "http://wikipedia.org/wiki/" },
	{ "C2",         "http://c2.com/cgi/wiki?" },
	$
}

sequence vStatus = {}

function generate_doc(integer pAction, sequence pParms, object pContext)
	sequence lDocText
	integer lPos
	integer lData
	sequence lWiki
	sequence lPage
	object lHeadings
	sequence lElements
	integer lThisElement
	sequence lThisFile
	sequence lThisContext
	sequence lThisText
	sequence lNextPageFile
	sequence lNextChapFile
	sequence lPrevPageFile
	sequence lPrevChapFile
	sequence lParentFile
	sequence lCurrChapFile
	sequence lTOCFile
	sequence lHomeFile
	integer lThisLevel = 0

	lDocText = ""

	if vVerbose then
		lThisFile = creole_parse(Get_Context)		
		if not equal(lThisFile, vStatus) then
			vStatus = lThisFile
			printf(1, "Processing: %s\n", {vStatus})
		end if
	end if
	
	switch pAction do
		case InterWikiLink  then
			lDocText = ""
			lPos = find(':', pParms[1])
			lWiki = upper(pParms[1][1 .. lPos - 1])
			lPage = pParms[1][lPos + 1 .. $]
			for i = 1 to length(KnownWikis) label "wikisearch" do
				if equal(lWiki, KnownWikis[i][1]) then
					lDocText = common_gen:generate(NormalLink, { KnownWikis[i][2] & lPage, pParms[2] }, pContext)

					exit "wikisearch"
				end if
			end for
			
			if length(lDocText) = 0 then
				lDocText = common_gen:generate(InterWikiLinkError, pParms, pContext)
			end if
			
		case Document then
			lHeadings = creole_parse(Get_Macro, "title")
			
			-- First we find out what level this page is on.				
			lThisFile = pParms[2]
			lThisText = ""
			lThisElement = 0
			lThisContext = ""
			if vVerbose then
				printf(1, "Generated: %s\n", {lThisFile})
			end if
			lElements = creole_parse(Get_Elements)
			for i = 1 to length(lElements) do
				if lElements[i][1] = 'h' then
					if equal(lElements[i][6], lThisFile) then
						lThisLevel = lElements[i][2]
						lThisContext = lElements[i][5]
						lThisText = lElements[i][3]
						lThisElement = i
						exit
					end if
				end if
			end for
			
			if sequence(vTemplateFile) then
				lNextPageFile = {{},{}}
				lNextChapFile = {{},{}}
				lPrevPageFile = {{},{}}
				lPrevChapFile = {{},{}}
				lParentFile   = {{},{}}
				lCurrChapFile = {{},{}}
				lTOCFile = ""
				lHomeFile = ""
				lThisContext = ""
				
				-- Find TOC and Home
				for i = 1 to length(lElements) do
					if length(lTOCFile) = 0 then
						if lElements[i][1] = 'p' and begins("TOC" & -1, lElements[i][2]) then
							lTOCFile = lElements[i][4]
						end if
					end if
					if length(lHomeFile) = 0 then
						if lElements[i][1] = 'h' then
							lHomeFile = lElements[i][6]
						end if
					end if
					if length(lHomeFile) > 0 and length(lTOCFile) > 0 then
						exit
					end if
				end for
				
				-- Now we look for the next page and next chapter files.
				for i = lThisElement + 1 to length(lElements) do
					if lElements[i][1] != 'h' then
						continue
					end if

					if length(lNextPageFile[1]) = 0 then
						if not equal(lElements[i][6], lThisFile) then
							lNextPageFile = {lElements[i][6], lElements[i][3]}
						end if
					end if
					
					if length(lNextChapFile[1]) = 0 then
						if lElements[i][2] = 1 then
							lNextChapFile = {lElements[i][6], lElements[i][3]}
							exit
						end if
					end if
				end for
			
				-- Now we look for the prev page, prev chapter and parent chapter files.
				if lThisLevel = 1 then
					lCurrChapFile = {lThisFile, lThisText}
				end if
				for i = lThisElement - 1 to 1 by -1 do
					if lElements[i][1] != 'h' then
						continue
					end if

					if length(lPrevPageFile[1]) = 0 then
						if not equal(lElements[i][6], lThisFile) then
							lPrevPageFile = {lElements[i][6], lElements[i][3]}
						end if
					end if
					
					if length(lParentFile[1]) = 0 then
						if lElements[i][2] = lThisLevel - 1 then
							lParentFile = {lElements[i][6], lElements[i][3]}
						end if
					end if
					
					if length(lCurrChapFile[1]) = 0 then
						if lElements[i][2] = 1 then
							lCurrChapFile = {lElements[i][6], lElements[i][3]}
						end if
					elsif length(lPrevChapFile[1]) = 0 and length(lCurrChapFile) != 0 then
						if lElements[i][2] = 1 then
							lPrevChapFile = {lElements[i][6], lElements[i][3]}
							exit
						end if
					end if
					
				end for

				lDocText = match_replace("@@title@@", vTemplateFile, lHeadings)
				lDocText = match_replace("@@context@@", lDocText, lThisContext)
				lDocText = match_replace("@@thistext@@", lDocText, lThisText)
				lDocText = match_replace("@@previous@@", lDocText, make_filename(lPrevPageFile[1], common_gen:extension(), ""))
				lDocText = match_replace("@@next@@", lDocText, make_filename(lNextPageFile[1], common_gen:extension(), ""))
				lDocText = match_replace("@@prevchap@@", lDocText, make_filename(lPrevChapFile[1], common_gen:extension(), ""))
				lDocText = match_replace("@@nextchap@@", lDocText, make_filename(lNextChapFile[1], common_gen:extension(), ""))
				lDocText = match_replace("@@currchap@@", lDocText, make_filename(lCurrChapFile[1], common_gen:extension(), ""))
				lDocText = match_replace("@@parent@@", lDocText, make_filename(lParentFile[1], common_gen:extension(), ""))
				lDocText = match_replace("@@pptext@@", lDocText, lPrevPageFile[2])
				lDocText = match_replace("@@nptext@@", lDocText, lNextPageFile[2])
				lDocText = match_replace("@@pctext@@", lDocText, lPrevChapFile[2])
				lDocText = match_replace("@@nctext@@", lDocText, lNextChapFile[2])
				lDocText = match_replace("@@chaptext@@", lDocText, lCurrChapFile[2])
				lDocText = match_replace("@@partext@@", lDocText, lParentFile[2])
				lDocText = match_replace("@@home@@", lDocText, make_filename(lHomeFile, common_gen:extension(), ""))
				lDocText = match_replace("@@toc@@", lDocText, make_filename(lTOCFile, common_gen:extension(), ""))
				lDocText = match_replace("@@publishedon@@", lDocText, vPublishedDate)
				lDocText = match_replace("@@quicklink@@", lDocText, join( vQuickLink, "\n" ))

				-- Body will be the largest addition, for efficiency, do it last
				lDocText = match_replace("@@body@@", lDocText, pParms[1])
			else
				lDocText = common_gen:default_template(lHeadings, lThisContext, pParms[1])
			end if
		case else
			lDocText = common_gen:generate(pAction, pParms, pContext)
	end switch

	return lDocText
end function

procedure Generate(sequence pFileName)
	sequence lOutFile
	sequence lBookMarks
	sequence lFileParts
	object lContent
	sequence lOutText
	integer fh

	lFileParts = pathinfo(pFileName)
	if length(lFileParts[PATH_BASENAME]) = 0 then
		return
	end if
	
	if length(lFileParts[PATH_FILEEXT]) = 0 then
		for j = 1 to length(vDefaultExt) do
			if length(lFileParts[PATH_DIR]) > 0 then
				pFileName = lFileParts[PATH_DIR] & SLASH
			else
				pFileName = ""
			end if
			pFileName &= lFileParts[PATH_BASENAME] & "." & vDefaultExt[j]
			lContent = read_file(fixup_seps(pFileName))
			if sequence(lContent) then
				exit
			end if
		end for
	else
		lContent = read_file(pFileName)	
	end if
	
	if atom(lContent) then
		return
	end if
		
	lOutFile = ""

	if length(vOutDir) = 0 then
		if length(lFileParts[PATH_DIR]) > 0 then
			lOutFile &= lFileParts[PATH_DIR] & SLASH
		end if
	else
		lOutFile = vOutDir & SLASH
	end if
	if length(lFileParts[PATH_BASENAME]) > 0 then
		lOutFile &= lFileParts[PATH_BASENAME]
	else
		lOutFile &= "result"
	end if
	lOutFile &= common_gen:extension()
	
	lOutFile = fixup_seps(lOutFile)
	pFileName = fixup_seps(pFileName)

	if vVerbose then
		printf(1, "Generating '%s' from '%s'\n", {
						lOutFile,
						pFileName
						})
	end if	
	
	vCurrentContext = pFileName
	
	if vVerbose then
		creole_parse(Set_Option, CO_Verbose )
	end if
	
	lOutText = creole_parse(lContent, routine_id("generate_doc"), vCurrentContext)
	if length(lOutText) > 0 then
		if atom(lOutText[1]) then
			fh = open(lOutFile, "w")
			if fh = -1 then
				printf(STDERR, "Cannot open \'%s\' for writing.\n", {lOutFile})
				abort(1)
			end if
			puts(fh, lOutText)
			close(fh)
		else
			object knownfiles = map:new()
			for i = 1 to length(lOutText) do
				lOutFile = make_filename(lOutText[i][1], common_gen:extension())
				if map:has(knownfiles, lOutFile) then
					-- I know this files, so append to it.
					fh = open(lOutFile, "a")
				else
					-- I don't know this files, so create it.
					fh = open(lOutFile, "w")
					map:put(knownfiles, lOutFile, 1)
				end if
				if fh = -1 then
					printf(STDERR, "Cannot open \'%s\' for writing.\n", {lOutFile})
					abort(1)
				end if
				puts(fh, lOutText[i][2])
				close(fh)	
			end for
		end if
	end if
	
	-- Create Index file.
	if vVerbose then
		puts(1, "Generating: Index\n")
	end if

	lBookMarks = creole_parse(Get_Bookmarks)
	for i = 1 to length(lBookMarks) do
		lBookMarks[i] = bmcleanup(lBookMarks[i])
	end for
	lBookMarks = custom_sort( routine_id("bmsort"), lBookMarks)
	lBookMarks = bmdivide(lBookMarks)

end procedure

procedure main()
	integer lDidSetTemplateDir = 0
	
	vPublishedDate = sprintf("%s\n", {datetime:format(now_gmt(), "%Y-%m-%d %H:%M UTC")})
	
	object base_options = map:load_map( locate_file("creole.opts") )
	if map(base_options) then
		KnownWikis = map:get( base_options, "wikis", KnownWikis)
	end if
	
	sequence cmd_options = {
		{ "A", 0,         "Enable macros",       { NO_PARAMETER,  HAS_CASE, ONCE } },
		{ "m", 0,         "Define a macro",      { HAS_PARAMETER, "macro", HAS_CASE } },
		{ "l", 0,         "Heading levels",      { HAS_PARAMETER, "num", HAS_CASE, ONCE } },
		{ "M", 0,         "Show message",        { HAS_PARAMETER, "message", HAS_CASE } },
		{ "f", "format",  "Output format (" & common_gen:names() & ")", 
		                                         { HAS_PARAMETER, "name", ONCE } },
		{ "o", 0,         "Output directory",    { HAS_PARAMETER, "dir", HAS_CASE, ONCE } },
		{ "t", 0,         "Template file",       { HAS_PARAMETER, "filename", HAS_CASE, ONCE } },
		{ "d", 0,         "Template directory",  { HAS_PARAMETER, "dir", HAS_CASE, ONCE } },
		{   0, "htmldoc", "Use span for colors", { NO_PARAMETER,  HAS_CASE, ONCE } },
		{ "q", 0,         "Quiet",               { NO_PARAMETER,  HAS_CASE, ONCE } },
		{ "v", 0,         "Verbose",             { NO_PARAMETER,  HAS_CASE, ONCE } },
		{   0, "version", "Display version",     { VERSIONING, "CreoleHtml v" & APP_VERSION } },
		{ 0,   0,         0,                     { MULTIPLE, MANDATORY } }
	}
	
	map opts = cmd_parse(cmd_options, { AT_EXPANSION })
	
	-- Handle verbose
	vVerbose = map:get(opts, "v", 0)
	vQuiet   = map:get(opts, "q", 0)
	use_span_for_color = map:get(opts, "htmldoc", 0)		
	vTemplateFilename = map:get(opts, "t", 0)
	creole_parse(Set_Option, CO_AllowMacros, map:get(opts, "A", 0))

	-- Handle output directory
	vOutDir = map:get(opts, "o", "")
	if length(vOutDir) > 0 and find(vOutDir[$], "\\/") > 0 then
		vOutDir = vOutDir[1 .. $-1]
	end if
	
	-- Handle template directory
	if length(map:get(opts, "d", "")) then
		lDidSetTemplateDir = 1
	end if
	
	-- Handle template file
	vTemplateFilename = map:get(opts, "t", 0)
	
	-- Handle heading levels
	sequence headingLevels = value(map:get(opts, "l", ""))
	if headingLevels[1] = GET_SUCCESS then
		creole_parse(Set_Option, CO_MaxNumLevel, headingLevels[2])
	end if
	
	-- Handle Show Message
	sequence messages = map:get(opts, "M", {})
	for i = 1 to length(messages) do
		printf(2, "%s\n", { messages[i] })
	end for
	
	-- Handle macro definitions
	sequence macros = map:get(opts, "m", {})
	for i = 1 to length(macros) do
		sequence macro = macros[i]
		integer lDelimPos = find_any(" \n\r\t", macro)
		sequence lName = macro[1 .. lDelimPos - 1]
		sequence lDefn = macro[lDelimPos + 1 .. $]
		
		creole_parse(Set_Macro, trim(lName), lDefn)
	end for
		
	if sequence(vTemplateFilename) then
		if not file_exists(vTemplateFilename) then
			printf(2,"\n*** Template file does not exist '%s'\n", { vTemplateFilename })
			abort(1)
		end if

		vTemplateFile = read_file(vTemplateFilename)
		if atom(vTemplateFile) then
			printf(2, "\n*** Could not load template file '%s'\n", {
				vTemplateFilename })
			abort(1)
		end if
	end if		
	
	-- Handle format (set default to HTML)
	if not common_gen:set(map:get(opts, "format", "html")) then
		printf(2, "*** Invalid format %s, please try one of %s\n", {
			map:get(opts, "format", "html"),
			common_gen:names()
		})
		
		abort(1)
	end if

	sequence files = map:get(opts, cmdline:EXTRAS, {})
	for i = 1 to length(files) do
		Generate(files[i])
	end for
	
	if vVerbose then
		printf(1, "\nDuration %g\n", time() - vStartTime)
	end if	
end procedure

main()
