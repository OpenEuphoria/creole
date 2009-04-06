include creole.e
include std/text.e
include std/search.e as search
include std/filesys.e
include std/io.e
include std/sort.e
include std/get.e
include std/datetime.e
include std/math.e
include std/error.e

include kanarie.e as kan

include html_gen.e

--sequence vDefaultExt
integer vVerbose = 0
integer vQuiet = 0

sequence vDefaultExt = {
	"wiki", "txt", "creole"
}

sequence vTemplateFile = ""
sequence vOutDir = {}
object vCurrentContext	
sequence KnownWikis

atom vStartTime = time()
sequence vPublishedDate

KnownWikis  = {}
KnownWikis &= {{"WIKICREOLE",	"http://wikicreole.org/wiki/"}}
KnownWikis &= {{"OHANA",		"http://wikiohana.net/cgi-bin/wiki.pl/"}}
KnownWikis &= {{"WIKIPEDIA",	"http://wikipedia.org/"}}

-----------------------------------------------------------------
function fixup_seps(sequence pFileName)
-----------------------------------------------------------------
ifdef WIN32 then
	return search:find_replace('/', pFileName, SLASH)
elsedef
	return search:find_replace('\\', pFileName, SLASH)
end ifdef
end function

-----------------------------------------------------------------
function make_filename(sequence pBaseName, object pLinkDir = 0)
-----------------------------------------------------------------
	sequence lOutFile
	sequence lFileParts
	sequence lLinkDir
	
	if length(pBaseName) = 0 then
		return ""
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
	lOutFile &= ".html"
	
	return fixup_seps(lOutFile)
	
	
end function

sequence vStatus = {}
-----------------------------------------------------------------
function generate_html(integer pAction, sequence pParms, object pContext)
-----------------------------------------------------------------
	sequence lHTMLText
	integer lPos
	integer lIdx
	integer lInstance
	integer lData
	integer lDepth
	sequence lSuffix
	sequence lWiki
	sequence lPage
	sequence lParms
	object lHeadings
	object lValue
	sequence lSpacer
	sequence lHere
	sequence lElements
	integer lLookingNext
	integer lSkipping
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
	sequence lFontColor
	sequence lFontSize
	sequence lFontFace
	sequence lText

	lHTMLText = ""
	lSpacer = ""

	if vVerbose then
		lThisFile = creole_parse(Get_Context)		
		if not equal(lThisFile, vStatus) then
			vStatus = lThisFile
			printf(1, "Processing: %s\n", {vStatus})
		end if
	end if
	
	switch pAction do
	case InternalLink  then
			if find('.', pParms[1]) = 0 then
				lSuffix = ".html"
			else
				lSuffix = ""
			end if
			lHTMLText = sprintf("<a class=\"euwiki\" href=\"%s%s\">%s</a>", {pParms[1], lSuffix, pParms[2]})
			break

	case  InterWikiLink  then
			lHTMLText = ""
			lPos = find(':', pParms[1])
			lWiki = upper(pParms[1][1 .. lPos - 1])
			lPage = pParms[1][lPos + 1 .. $]
			for i = 1 to length(KnownWikis) do
				if equal(lWiki, KnownWikis[i][1]) then
					lHTMLText = sprintf("<a class=\"euwiki\" href=\"%s%s\">%s</a>", {KnownWikis[i][2], lPage, pParms[2]})
					
				end if
			end for
			if length(lHTMLText) = 0 then
				lHTMLText = "<span class=\"euwiki_error\"><font color=\"red\">Interwiki link failed for "
				for i = 1 to length(pParms) do
					lHTMLText &= pParms[i]
					if i < length(pParms) then
						lHTMLText &= ", "
					end if
				end for
				lHTMLText &= "</font></span>"
			end if
			break
	case Document then
			lHeadings = creole_parse(Get_Macro,"title")
			
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
			
			if length(vTemplateFile) then
				lLookingNext = 0
				lSkipping = 0
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
					lIdx = i
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
			
				lData = kan:createData()
				kan:setValue(lData, "title", lHeadings)
				kan:setValue(lData, "context", lThisContext)
				kan:setValue(lData, "thistext", lThisText)
				kan:setValue(lData, "body", pParms[1])
				kan:setValue(lData, "previous", make_filename(lPrevPageFile[1],""))
				kan:setValue(lData, "next", make_filename(lNextPageFile[1],""))
				kan:setValue(lData, "prevchap", make_filename(lPrevChapFile[1],""))
				kan:setValue(lData, "nextchap", make_filename(lNextChapFile[1],""))
				kan:setValue(lData, "currchap", make_filename(lCurrChapFile[1],""))
				kan:setValue(lData, "parent", make_filename(lParentFile[1],""))
				kan:setValue(lData, "pptext", lPrevPageFile[2])
				kan:setValue(lData, "nptext", lNextPageFile[2])
				kan:setValue(lData, "pctext", lPrevChapFile[2])
				kan:setValue(lData, "nctext", lNextChapFile[2])
				kan:setValue(lData, "chaptext", lCurrChapFile[2])
				kan:setValue(lData, "partext", lParentFile[2])
				kan:setValue(lData, "home", make_filename(lHomeFile,""))
				kan:setValue(lData, "toc", make_filename(lTOCFile,""))
				kan:setValue(lData, "publishedon", vPublishedDate)
				lHeadings = kan:loadTemplateFromFile(vTemplateFile)
				if atom(lHeadings) then
					printf(2,"\n*** Failed to load template from '%s'\n", {vTemplateFile})
					abort(1)
				end if
				lHTMLText = kan:generate(lData, lHeadings)
			else
				lHTMLText = "<!DOCTYPE html \n" &
							"  PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"\n" &
							"  \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n" &
							"\n" &
							"<html>\n" &
							"\n" &
							"<head>\n" &
							" <title>" & lHeadings & "</title>\n" &
							" <link rel=\"stylesheet\" media=\"screen, projection, print\" type=\"text/css\" href=\"style.css\"/>\n" &
							"<meta source=\"" & lThisContext & "\" />\n" &
							"</head>\n" &
							"<body>\n" & 
							pParms[1] &
							"</body></html>"	
			end if
			break					

	case Plugin then
		lInstance = pParms[4]
		-- Extract the key/values, but don't parse for quoted text nor whitespace delims.
		lParms = keyvalues(pParms[1], -1, -2, "", "")
		for i = 1 to length(lParms) do
			lParms[i][1] = lower(lParms[i][1])
		end for
		lParms[1][2] = upper(lParms[1][2])
		lHTMLText = ""
		
		if vVerbose then
			printf(1, "Plugin: %s\n", {lParms[1][2]}) 
		end if
		switch lParms[1][2] do
			case "TOC" then
				lHTMLText = "<div class=\"TOC\">"
				lValue = {0,2}
				lSpacer = ""
				for i = 2 to length(lParms) do
					if equal(lParms[i][1], "heading") then
						if find(lParms[i][2], {"yes", "on", "show", "1"}) then
							lHTMLText &= "<p class=\"TOCHead\">Table of Contents</p>"
						end if
					elsif equal(lParms[i][1], "level") then
						lValue = value(lParms[i][2])
						if lValue[1] != GET_SUCCESS then
							lValue[2] = 2
						end if
					elsif equal(lParms[i][1], "spacer") then
						lSpacer = search:find_replace("^", lParms[i][2], " ")
					end if
				end for
				
				lHeadings = creole_parse(Get_Headings, , lValue[2])
				lHTMLText &= "<div class=\"TOCBody\">"
				for i = 1 to length(lHeadings) do
					lHTMLText &= "<div class=\"toc_" & sprint(lHeadings[i][1]) & "\">"
					if length(lSpacer) > 0 then
						for j = 2 to lHeadings[i][1] do
							lHTMLText &= lSpacer
						end for
					end if
					lHTMLText &= "<a href=\"" & make_filename(lHeadings[i][5],"") & 
								"#" & lHeadings[i][3] & "\">" &
								lHeadings[i][2] & "</a></div>\n"
				end for
				
				lHTMLText &= "</div>"
				break
			
			case "NAV" then
				lHere = creole_parse(Get_CurrentHeading, , lInstance)
				lHeadings = creole_parse(Get_Headings, , lHere[1])

				lHTMLText = "<div class=\"NAV\">"
				lPos = find(lHere, lHeadings)
				lIdx = lPos - 1
				while lIdx >= 1 do
					if lHeadings[lIdx][1] = lHere[1] then
						lHTMLText &= "<a href=\"" & make_filename(lHeadings[lIdx][5],"") & 
								"#" & lHeadings[lIdx][3] & "\">" &
								"Previous" & "</a>"
						exit
					end if
					lIdx -= 1
				end while
				lHTMLText &= " "
				
				lHTMLText &= "<a href=\"" & make_filename(lHeadings[1][5],"") & 
						"#" & lHeadings[1][3] & "\">" &
						"Up" & "</a>"
				lHTMLText &= " "
				
				lIdx = lPos + 1
				while lIdx <= length(lHeadings) do
					if lHeadings[lIdx][1] = lHere[1] then
						lHTMLText &= "<a href=\"" & make_filename(lHeadings[lIdx][5],"") & 
								"#" & lHeadings[lIdx][3] & "\">" &
								"Next" & "</a>"
						exit
					end if
					lIdx += 1
				end while				
				
				lHTMLText &= "</div>"
				break
			
			case "LEVELTOC" then
				
				lDepth = 1
				for i = 2 to length(lParms) do
					if equal(lParms[i][1], "depth") then
						lValue = value(lParms[i][2])
						if lValue[1] = GET_SUCCESS then
							lDepth = max({1,lValue[2]})
						end if
					end if
				end for
				lHere = creole_parse(Get_CurrentHeading, ,lInstance)

				lHeadings = creole_parse(Get_Headings, , lHere[1] + lDepth)
				
				lHTMLText = ""
				lPos = find(lHere, lHeadings)
				
				lIdx = lPos + 1
				while lIdx <= length(lHeadings) do
					if lHeadings[lIdx][1] = lHere[1] then
						exit
					end if
					if lHeadings[lIdx][1] > lHere[1] then
						lHTMLText &= "<div class=\"toc_" & sprint(lHeadings[lIdx][1]) & "\">"
						lHTMLText &= "<a href=\"" & make_filename(lHeadings[lIdx][5],"") & 
									"#" & lHeadings[lIdx][3] & "\">" &
									lHeadings[lIdx][2] & "</a></div>\n"
					end if
					lIdx += 1
				end while				
				
				if length(lHTMLText) > 0 then
					lHTMLText = "<div class=\"LEVELTOC\">\n" & lHTMLText & "</div>\n"
				end if
			break
			
			case "FONT" then
				lFontColor = ""
				lFontFace = ""
				lFontSize = ""
				lText = ""
				for i = 2 to length(lParms) do
					if equal(lParms[i][1], "color") then
						lFontColor = lParms[i][2]
					elsif equal(lParms[i][1], "size") then
						lFontSize = lParms[i][2]
					elsif equal(lParms[i][1], "face") then
						lFontFace = lParms[i][2]
					elsif equal(lParms[i][1], "text") then
						lText &= lParms[i][2]
					elsif equal(lParms[i][1][1..2], "p[") then
						lText &= lParms[i][2]
					end if
				end for
				if length(lText) > 0 then
					lHTMLText = "<font "
					if length(lFontColor) > 0 then
						lHTMLText &= "color=\"" & html_generator(Sanitize, lFontColor) & "\" "
					end if
					if length(lFontFace) > 0 then
						lHTMLText &= "face=\"" & html_generator(Sanitize, lFontFace) & "\" "
					end if
					if length(lFontSize) > 0 then
						lHTMLText &= "size=\"" & html_generator(Sanitize, lFontSize) & "\" "
					end if
					lHTMLText &= ">"
					lHTMLText &= parse_text(lText, 4) -- sanitized by parse_text
					lHTMLText &= "</font>"
				end if
				
				break
			
			case else
				lHTMLText = html_generator(pAction, pParms)
			break
		end switch
		
		break
			
	case  HostID  then
			lHTMLText = "euwiki"
			break

	case  OptReparseHeadings  then
			lHTMLText = ""
			break

	case else
			lHTMLText = html_generator(pAction, pParms)
			
	end switch

	return lHTMLText

end function

-----------------------------------------------------------------
function bmcleanup(sequence pBookMark)
-----------------------------------------------------------------
	sequence lText
	integer lPos
	
	-- The display text might be blank
	if length(pBookMark[3]) = 0 then
		lText = pBookMark[4]	-- Use bookmark name
	else
		lText = pBookMark[3]    -- Use display text
	end if
	
	-- Do a case-insensitive comparison
	lText = lower(lText)
	
	-- For headings, strip off any leading numbering.
	if pBookMark[1] = 'h' then
		if find(lText[1], "123456789") then
			lPos = find(';', lText)
			if lPos > 0 then
				lText = lText[lPos + 1 .. $]
			end if
		end if
	end if
	
	return lText
end function

-----------------------------------------------------------------
function bmsort(sequence A, sequence B)
-----------------------------------------------------------------
	return compare(bmcleanup(A), bmcleanup(B))
end function

-----------------------------------------------------------------
procedure Generate(sequence pFileName)
-----------------------------------------------------------------
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
	lOutFile &= ".html"
	
	lOutFile = fixup_seps(lOutFile)
	pFileName = fixup_seps(pFileName)

	if vVerbose then
		printf(1, "Generating '%s' from '%s'\n", {
						lOutFile,
						pFileName
						})
	end if	
	
	vCurrentContext = pFileName
	lOutText = creole_parse(lContent, routine_id("generate_html"), vCurrentContext)
	if length(lOutText) > 0 then
		if atom(lOutText[1]) then
			fh = open(lOutFile, "w")
			puts(fh, lOutText)
			close(fh)
		else
			for i = 1 to length(lOutText) do
				lOutFile = make_filename(lOutText[i][1])
				fh = open(lOutFile, "w")
				puts(fh, lOutText[i][2])
				close(fh)	
			end for
		end if
	end if
	
	-- Create Index file.
	if vVerbose then
		puts(1, "Generating: Index\n")
	end if
	lBookMarks = custom_sort( routine_id("bmsort"), creole_parse(Get_Bookmarks))
	fh = open(make_filename("index"), "w")
	puts(fh, "<!DOCTYPE html \n" )
	puts(fh, "  PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"\n" )
	puts(fh, "  \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n" )
	puts(fh, "\n" )
	puts(fh, "<html>\n" )
	puts(fh, "\n" )
	puts(fh, "<head>\n" )
	puts(fh, " <title>Index</title>\n" )
	puts(fh, " <link rel=\"stylesheet\" media=\"screen, projection, print\" type=\"text/css\" href=\"style.css\"/>\n" )
	puts(fh, "</head>\n" )
	puts(fh, "<body>\n" )
	for i = 1 to length(lBookMarks) do
		puts(fh, "<a href=\"")
		puts(fh, make_filename(lBookMarks[i][6],"")) -- Containing file
		puts(fh, "#")
		puts(fh, lBookMarks[i][4]) -- Bookmark name
		puts(fh, "\">")
		if length(lBookMarks[i][3]) > 0 then
			puts(fh, lBookMarks[i][3]) -- Display Text
		else
			puts(fh, lBookMarks[i][4])
		end if
		puts(fh, "</a><br />\n")
	end for
	puts(fh, "</body></html>\n")
	close(fh)	
	
end procedure

-----------------------------------------------------------------
function getArgs(sequence pArgFile)
-----------------------------------------------------------------
	object lLines
	sequence lArgs = {}
	integer lAppending = 0

	lLines = read_lines(pArgFile)
	if atom(lLines) then
		return {"-M=Arg file '" & pArgFile & "' not available."}
	end if
	
	for i = 1 to length(lLines) do
		if length(lLines[i]) = 0 then
			if lAppending then
				lArgs[$] &= '\n'
			end if
			continue
		end if
		
		if lLines[i][$] = '(' then
			lAppending = 1
			lArgs = append(lArgs, lLines[i][1..$-1])
		elsif equal(trim(lLines[i]), ")") then
			if lAppending then
				lAppending = 0
			else
				lArgs = append(lArgs, lLines[i])
			end if
		elsif lAppending then
			lArgs[$] &= '\n' & lLines[i]
		else
			lArgs = append(lArgs, lLines[i])
		end if
	end for

	return lArgs
end function

-----------------------------------------------------------------
procedure main(sequence pArgs)
-----------------------------------------------------------------
	integer lPos
	integer lCount
	sequence lValue
	sequence lNewArgs
	sequence lName
	sequence lDefn
	integer lDelimPos

	vPublishedDate = sprintf("%s\n", {format(now_gmt(), "%Y-%m-%d %H:%M UTC")})
	lPos = 3
	lCount = length(pArgs)
	while 1 do
		if lPos > lCount then
			exit
		end if
		if length(pArgs[lPos]) = 0 then
			lPos += 1
			continue
		end if
		
		if pArgs[lPos][1] = '@' then
			lNewArgs = getArgs(pArgs[lPos][2..$])
			pArgs = pArgs[1 .. lPos - 1] & lNewArgs & pArgs[lPos + 1 .. $]
			lCount = length(pArgs)
			continue
		end if
		
		if pArgs[lPos][1] = '-' then
			if pArgs[lPos][2] = 'M' then -- Show message
				if not vQuiet then
					if find(pArgs[lPos][3], "=:") > 0 then
						lValue = pArgs[lPos][4..$]
					else
						lValue = pArgs[lPos][3..$]
					end if
					if length(lValue) > 0 then
						puts(2, lValue)
						puts(2, '\n')
					end if
				end if
								
			elsif pArgs[lPos][2] = 'm' then -- Define a macro
				if find(pArgs[lPos][3], "=:") > 0 then
					lValue = pArgs[lPos][4..$]
				else
					lValue = pArgs[lPos][3..$]
				end if
				lDelimPos = find_any(" \n\r\t", lValue)
				lName = lValue[1 .. lDelimPos - 1]
				lDefn = lValue[lDelimPos + 1 .. $]
				lValue = creole_parse(Set_Macro, trim(lName), lDefn)
				
			elsif pArgs[lPos][2] = 'v' then -- Verbose
				if find(pArgs[lPos][3], "=:") > 0 then
					lValue = pArgs[lPos][4..$]
				else
					lValue = pArgs[lPos][3..$]
				end if
				if find(trim(upper(lValue)), {"ON","YES","1"}) > 0 then
					vVerbose = 1
				else
					vVerbose = 0
				end if
				
			elsif pArgs[lPos][2] = 'A' then -- Macro Usage

				if find(pArgs[lPos][3], "=:") > 0 then
					lValue = pArgs[lPos][4..$]
				else
					lValue = pArgs[lPos][3..$]
				end if
				if find(trim(upper(lValue)), {"ON","YES","1"}) > 0 then
					lValue = creole_parse(Set_Option, CO_AllowMacros, "YES")
				else
					lValue = creole_parse(Set_Option, CO_AllowMacros, "NO")
				end if
				
			elsif pArgs[lPos][2] = 'q' then -- Quiet
				if find(pArgs[lPos][3], "=:") > 0 then
					lValue = pArgs[lPos][4..$]
				else
					lValue = pArgs[lPos][3..$]
				end if
				if find(trim(upper(lValue)), {"ON","YES","1"}) > 0 then
					vQuiet = 1
				else
					vQuiet = 0
				end if
				
			elsif pArgs[lPos][2] = 'o' then -- Output directory
				if find(pArgs[lPos][3], "=:") > 0 then
					lValue = pArgs[lPos][4..$]
				else
					lValue = pArgs[lPos][3..$]
				end if
				vOutDir = lValue
				if length(vOutDir) > 0 and find(vOutDir[$], "\\/") > 0 then
					vOutDir = vOutDir[1 .. $-1]
				end if
			
			elsif pArgs[lPos][2] = 't' then -- Template File
				if find(pArgs[lPos][3], "=:") > 0 then
					lValue = pArgs[lPos][4..$]
				else
					lValue = pArgs[lPos][3..$]
				end if
				vTemplateFile = lValue
				
			elsif pArgs[lPos][2] = 'l' then -- Heading Levels
				if find(pArgs[lPos][3], "=:") > 0 then
					lValue = pArgs[lPos][4..$]
				else
					lValue = pArgs[lPos][3..$]
				end if
				lValue = value(lValue)
				if lValue[1] = GET_SUCCESS then
					lValue = creole_parse(Set_Option, CO_MaxNumLevel, lValue[2])
				end if
				
				
			elsif pArgs[lPos][2] = '-' then -- Output directory
				-- A comment so ignore it
				
			else
				printf(2, "** Unrecognized option '%s' ignored.\n", {pArgs[lPos]})
				
			end if
		end if
		
		lPos += 1
	end while
	
	for i = 3 to length(pArgs) do	
		if length(pArgs[i]) = 0 then
			continue
		end if
		if pArgs[i][1] != '-' then
			Generate(pArgs[i])
		end if
	end for
	
	if vVerbose then
		printf(1, "\nDuration %g\n", time() - vStartTime)
	end if
	
end procedure

-----------------------------------------------------------------
-----------------------------------------------------------------

main(command_line())
