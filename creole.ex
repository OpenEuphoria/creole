#!/usr/bin/env eui

include std/cmdline.e
include std/datetime.e
include std/error.e
include std/filesys.e
include std/get.e
include std/io.e
include std/map.e
include std/math.e
include std/pretty.e
include std/search.e
include std/sequence.e
include std/sort.e
include std/text.e
include std/utils.e

include creole.e
include common_gen.e
include html_gen.e
include latex_gen.e

include kanarie.e as kan

--
-- TODO:
--
-- * Move to html_gen:
--   * HTML search interface
--
-- * Abstract
--   * InterWikiLink
--   * TOC plugin
--   * LEVELTOC plugin
--   * FONT plugin
--   * QUICKLINK plugin
--

sequence JSON_OPTS = PRETTY_DEFAULT
JSON_OPTS[DISPLAY_ASCII] = 3

-- Increment version number with each release, not really with each change
-- in the SCM

constant APP_VERSION = "1.0.0"

integer vFormat = 0
integer vVerbose = 0
integer vQuiet = 0

sequence vDefaultExt = {
	"wiki", "txt", "creole"
}

object vTemplateFile = 0
object vTemplateFilename = 0

sequence vOutDir = {}
object vCurrentContext	

atom vStartTime = time()
sequence vPublishedDate
sequence vQuickLink = {}

sequence KnownWikis  = {
	{ "WIKICREOLE",	"http://wikicreole.org/wiki/" },
	{ "OHANA",      "http://wikiohana.net/cgi-bin/wiki.pl/" },
	{ "WIKIPEDIA",  "http://wikipedia.org/wiki/" },
	{ "OPENEU",     "http://openeuphoria.org/wiki/view.wc?page=" },
	{ "WIKI",       "http://openeuphoria.org/wiki/view.wc?page=" }
}

function fixup_seps(sequence pFileName)
	ifdef WINDOWS then
		return search:match_replace('/', pFileName, SLASH)
	elsedef
		return search:match_replace('\\', pFileName, SLASH)
	end ifdef
end function

function make_filename(sequence pBaseName, object pLinkDir = 0)
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
	lOutFile &= common_gen:extension()
	
	return fixup_seps(lOutFile)
end function

sequence vStatus = {}

function generate_doc(integer pAction, sequence pParms, object pContext)
	sequence lDocText
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

	lDocText = ""
	lSpacer = ""

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
			for i = 1 to length(KnownWikis) do
				if equal(lWiki, KnownWikis[i][1]) then
					lDocText = common_gen:generate(NormalLink, { KnownWikis[i][2] & lPage, pParms[2] })
				end if
			end for
			
			if length(lDocText) = 0 then
				-- TODO: Create an InvalidWikiLink action or something
				/*
				lDocText = "<span class=\"euwiki_error\"><font color=\"red\">Interwiki link failed for "
				for i = 1 to length(pParms) do
					lDocText &= pParms[i]
					if i < length(pParms) then
						lDocText &= ", "
					end if
				end for
				lDocText &= "</font></span>"
				*/
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
				kan:setValue(lData, "quicklink", join( vQuickLink, "\n" ) )
				
				lDocText = kan:generate(lData, vTemplateFile)
			else
				lDocText = common_gen:default_template(lHeadings, lThisContext, pParms[1])
			end if

		case Plugin then
			lInstance = pParms[4]
			-- Extract the key/values, but don't parse for quoted text nor whitespace delims.
			lParms = keyvalues(pParms[1], -1, -2, "", "")
			for i = 1 to length(lParms) do
				lParms[i][1] = lower(lParms[i][1])
			end for
			lParms[1][2] = upper(lParms[1][2])
			lDocText = ""
			
			if vVerbose then
				printf(1, "Plugin: %s\n", {lParms[1][2]}) 
			end if
			
			switch lParms[1][2] do
				case "BLAHBLAHBLAH" then
				/*
				case "TOC" then
					lValue = {0,2}
					sequence lStartDepth = { 0, 0 }
					lSpacer = ""
					for i = 2 to length(lParms) do
						if equal(lParms[i][1], "heading") then
							if find(lParms[i][2], {"yes", "on", "show", "1"}) then
								lDocText &= "<p class=\"TOCHead\">Table of Contents</p>"
							end if
						elsif equal(lParms[i][1], "level") then
							lValue = value(lParms[i][2])
							if lValue[1] != GET_SUCCESS then
								lValue[2] = 2
							end if
						elsif equal(lParms[i][1], "spacer") then
							lSpacer = search:match_replace("^", lParms[i][2], " ")
						
						elsif equal(lParms[i][1], "start") then
							lStartDepth = value(lParms[i][2])
							if lStartDepth[1] != GET_SUCCESS then
								lStartDepth[2] = 0
							end if
						end if
					end for
					
					lDocText = buildTOC( 0, 1, {} )
				
				case "NAV" then
					lHere = creole_parse(Get_CurrentHeading, , lInstance)
					lHeadings = creole_parse(Get_Headings, , lHere[1])
	
					lDocText = "<div class=\"NAV\">"
					lPos = find(lHere, lHeadings)
					lIdx = lPos - 1
					while lIdx >= 1 do
						if lHeadings[lIdx][1] = lHere[1] then
							lDocText &= "<a href=\"" & make_filename(lHeadings[lIdx][5],"") & 
									"#" & lHeadings[lIdx][3] & "\">" &
									"Previous" & "</a>"
							exit
						end if
						lIdx -= 1
					end while
					lDocText &= " "
					
					lDocText &= "<a href=\"" & make_filename(lHeadings[1][5],"") & 
							"#" & lHeadings[1][3] & "\">" &
							"Up" & "</a>"
					lDocText &= " "
					
					lIdx = lPos + 1
					while lIdx <= length(lHeadings) do
						if lHeadings[lIdx][1] = lHere[1] then
							lDocText &= "<a href=\"" & make_filename(lHeadings[lIdx][5],"") & 
									"#" & lHeadings[lIdx][3] & "\">" &
									"Next" & "</a>"
							exit
						end if
						lIdx += 1
					end while				
					
					lDocText &= "</div>"
					break
				
				case "LEVELTOC" then
					integer lLevel = 1
					lDepth = 4
					
					for i = 2 to length(lParms) do
						if equal(lParms[i][1], "depth") then
							lValue = value(lParms[i][2])
							if lValue[1] = GET_SUCCESS then
								lDepth = max({1,lValue[2]})
							end if
							
						elsif equal(lParms[i][1], "level") then
							lValue = value(lParms[i][2])
							if lValue[1] = GET_SUCCESS then
								lLevel = max({1,lValue[2]})
							end if
						end if
					end for
					integer lDelim = -1
					integer lIx
					while lIx with entry do
						pParms[1][lIx] = 32
						lDelim -= 1
					entry
						lIx = find( lDelim, pParms[1] )
					end while
					lHere = creole_parse(Get_CurrentLevels, , {pParms[4], lLevel} )
					lDocText = buildTOC( lLevel, lDepth, lHere )
				
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
						lDocText = "<font "
						if length(lFontColor) > 0 then
							lDocText &= "color=\"" & common_gen:generate(Sanitize, lFontColor) & "\" "
						end if
						if length(lFontFace) > 0 then
							lDocText &= "face=\"" & common_gen:generate(Sanitize, lFontFace) & "\" "
						end if
						if length(lFontSize) > 0 then
							lDocText &= "size=\"" & common_gen:generate(Sanitize, lFontSize) & "\" "
						end if
						lDocText &= ">"
						lDocText &= parse_text(lText, 4) -- sanitized by parse_text
						lDocText &= "</font>"
					end if
					
					break
					
				case "INDEX" then
					lDocText = buildIndex( lParms )
				
				case "QUICKLINK" then
					lDocText = sprintf("<a name=\"ql%d\"/>\n", { length(vQuickLink)} )
					lHere = creole_parse(Get_CurrentHeading, , lInstance )
					vQuickLink = append( vQuickLink, 
						sprintf( "<li><a href='%s.html#ql%d'>%s</a></li>", { lHere[7], length(vQuickLink), lHere[H_TEXT]}) )
				*/
				case else
					lDocText = common_gen:generate(pAction, pParms)
				break
			end switch
			
		case else
			lDocText = common_gen:generate(pAction, pParms)
	end switch

	return lDocText
end function

sequence bm_level_names = repeat("", 6)

function showTOC( sequence pContext, integer pLevel, integer pDepth, sequence pHeadings )
	-- check to see if we should be showing the TOC link for this heading
	if length( pContext ) < pLevel then
		return 0
	end if
	
	if pDepth > length(pContext) then
		pDepth = length(pContext)
	end if
	
	if pDepth > length(pHeadings) then
		pDepth = length(pHeadings)
	end if
	
	for i = 1 to pDepth do
		if pContext[i] != pHeadings[i] then
			return 0
		end if
	end for
	
	return 1
end function

function buildTOC( integer pLevel, integer pDepth, sequence pHere, sequence pSpacer = "" )
	sequence lHeadings = creole_parse(Get_Headings, , pDepth )
	sequence lHTMLText = "<div class=\"TOC\">\n<div class=\"TOCBody\">"
	sequence lHeadingContext = {}
	for i = 1 to length(lHeadings) do
		sequence lHeading = lHeadings[i]
		integer lHeadingDepth = lHeading[1]
		if lHeadingDepth < length( lHeadingContext ) then
			lHeadingContext = lHeadingContext[1..lHeadingDepth]
			
		elsif lHeadingDepth > length( lHeadingContext ) then
			lHeadingContext &= repeat( 0, lHeadingDepth - length( lHeadingContext ) )
			
		end if
		lHeadingContext[lHeadingDepth] += 1
		
		if showTOC( pHere, pLevel, pDepth, lHeadingContext ) then
		
			lHTMLText &= "<div class=\"toc_" & sprint(lHeadings[i][1]) & "\">"
			if length(pSpacer) > 0 then
				for j = 2 to lHeadings[i][1] do
					lHTMLText &= pSpacer
				end for
			end if
			lHTMLText &= "<a href=\"" & make_filename(lHeadings[i][5],"") & 
						"#" & lHeadings[i][3] & "\">" &
						lHeadings[i][2] & "</a></div>\n"
			
		end if
	end for
	lHTMLText &= "</div>\n"
	lHTMLText &= "</div>\n"
	return lHTMLText
end function

function buildIndex( sequence pParms )
-- Create Index file
	integer lGenerateSearch = 0
	integer px = 1
	while px <= length( pParms ) do
		-- parse the arguments for the plugin
		if equal( pParms[px][2], "search" ) then
			lGenerateSearch = 1
		end if
		px += 1
	end while
	
	sequence lHtml = ""
	if vVerbose then
		puts(1, "Generating: Index\n")
	end if

	sequence lBookMarks = creole_parse(Get_Bookmarks)
	for i = 1 to length(lBookMarks) do
		lBookMarks[i] = bmcleanup(lBookMarks[i])
	end for
	lBookMarks = custom_sort( routine_id("bmsort"), lBookMarks)
	lBookMarks = bmdivide(lBookMarks)

	lHtml &= "<h1>Subject and Routine Index</h1>\n" 
	sequence entries
	integer jj
	
	jj = 0
	for i = 1 to length(lBookMarks) do
		jj += 1
		if jj > 9 then
			lHtml &= "<br />\n" 
			jj = 1
		end if
		lHtml &= "&nbsp;&nbsp;&nbsp;<a href=\"#bm_" & lBookMarks[i][1][7][1] & "\"><strong>&nbsp;" &
									upper(lBookMarks[i][1][7][1]) & "</strong>&nbsp;</a>&nbsp;&nbsp;&nbsp;"
	end for
	lHtml &= "<br /><br />\n" 
	
	map:map lSearchMap = map:new()
	
	entries = {}
	sequence lSplitName = ""
	integer lSplitLength = -1

	for i = 1 to length(lBookMarks) do	
		entries = append(entries, "<br />&nbsp;&nbsp;<a name=\"bm_" & lBookMarks[i][1][7][1] & "\"><strong>" &
									upper(lBookMarks[i][1][7][1]) & "</strong></a>&nbsp;&nbsp;<br />")
		for j = 1 to length(lBookMarks[i]) do
			sequence lEntry
			integer pos
			sequence htmlentry

			lEntry = lBookMarks[i][j]
			htmlentry = "<a href=\"" 
			sequence href = indexEntryHref( lEntry )
			htmlentry &= href
			htmlentry &= "\">"
			htmlentry &= lEntry[7] -- cleaned up name
			htmlentry &= "</a>"
			entries = append(entries, htmlentry)
			
			if lGenerateSearch then
				integer ix = find( '(', lEntry[7] )
				integer sl
				if ix then
					if lSplitLength = -1 then
						lSplitLength = find('_', href)
						lSplitName = href[1..lSplitLength]
					end if
					if lSplitLength + 11 > length(href) then
						sl = length(href)
					else
						sl = lSplitLength + 11
					end if
					map:put( 
							lSearchMap, 
							pretty_sprint( lEntry[7][1..ix-2], JSON_OPTS ), 
							{ 
								href[lSplitLength+1..lSplitLength+4], 
								href[sl .. $], 
								pretty_sprint( lEntry[7][ix+1..$-1], JSON_OPTS)
							}, 
							map:APPEND )
				end if
			end if
		end for
		
	end for

	lHtml &= "<table class=\"index\">\n"
	jj = floor( (1 + length(entries)) / 2 )
	for j = 1 to jj do
		lHtml &= "<tr>\n"
		lHtml &= "<td>"
		lHtml &= entries[j]
		lHtml &= "</td>\n"

		if j + jj <= length(entries) then
			lHtml &= "<td>"
			lHtml &= entries[j + jj]
			lHtml &= "</td>\n"
		end if
		lHtml &= "</tr>\n"
	end for
	lHtml &= "</table>"
	
	if lGenerateSearch then
		-- create JSON
		sequence lWords = map:keys( lSearchMap )
		sequence lSearchData = sprintf("var base='%s';\nvar index={\n", {lSplitName})
		integer wx = 1
		while wx <= length(lWords) with entry do
			lSearchData &= ",\n"
		entry
			lSearchData &= jsonWord( lWords[wx], map:get( lSearchMap, lWords[wx] ) )
			wx += 1
		end while
		lSearchData &= "};\n"
		
		create_directory( sprintf("%s%sjs", { vOutDir, SLASH }) )
		atom js = open( sprintf("%s%sjs%ssearch.js", { vOutDir, SLASH, SLASH } ), "w", 1 )
		puts( js, lSearchData ) 
		puts( js, SEARCH_JS )
	end if
	
	return lHtml
end function
constant SEARCH_JS = `
function search(frm) {
    var m = index[frm.value];
    var list = '';
    list = frm.value + ':'

    if ( m == undefined ) {
        list += '<font color=#FF0000>not found!</font>';
    } 
    else {
		list += '<ul>';
		for( var ix = 0; ix <  m.length; ++ix ){
			var r = m[ix];
			list += '<li>';
			list += "<a href=" + base + r[0] + ".html#" + r[1] + ">";
			list += r[2] + ": " + frm.value;
			list += '</a></li>';
		}
		list += '</ul>';
    }
    document.getElementById('searchresults').innerHTML = list; 

    return false;    
}

`

function indexEntryHref( sequence pBookMark )
	sequence htmlentry = ""
	if length(pBookMark[6]) > 0 then
		htmlentry &= make_filename(filebase(pBookMark[6]),"") -- Containing file
	else
		htmlentry &= make_filename(filebase(pBookMark[5]),"") -- Containing file
	end if
	htmlentry &= "#"
	htmlentry &= pBookMark[4] -- Bookmark name
	return htmlentry
end function

function jsonWord( sequence pWord, sequence pSections )
	-- "word":{"section 1":"link",...}
	sequence json = sprintf(`%s:[`, {pWord} )
	integer ix = 1
	while ix <= length( pSections ) with entry do
		json &= ','
	entry
		json &= sprintf( `["%s","%s",%s]`, pSections[ix] )
		ix += 1
	end while
	json &= "]"
	return json
end function

function bmcleanup(sequence pBookMark)
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

function bmsort(sequence A, sequence B)
	return compare(A[$], B[$])
end function

function bmdivide(sequence pOrigList)
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
		object VOID = creole_parse(Set_Option, CO_Verbose )
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
				lOutFile = make_filename(lOutText[i][1])
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
	
	object base_options = map:load_map( locate_file("creolehtml.opts") )
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
	creole_parse(Set_Option, CO_AllowMacros, iif(map:get(opts, "A", 0), "NO", "YES"))

	-- Handle output directory
	vOutDir = map:get(opts, "o", "")
	if length(vOutDir) > 0 and find(vOutDir[$], "\\/") > 0 then
		vOutDir = vOutDir[1 .. $-1]
	end if
	
	-- Handle template directory
	if length(map:get(opts, "d", "")) then
		lDidSetTemplateDir = 1
		setTemplateDirectory(map:get(opts, "d"))
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
		sequence templateDir, templateFilename = vTemplateFilename
		
		if not lDidSetTemplateDir then
			sequence canonicalFilename
			
			canonicalFilename = canonical_path(vTemplateFilename)
			templateDir       = pathname(canonicalFilename)
			templateFilename  = filename(canonicalFilename)
			
			kan:setTemplateDirectory(templateDir & SLASH)
			lDidSetTemplateDir = 1
		end if
		
		vTemplateFile = kan:loadTemplateFromFile(templateFilename)
		
		if atom(vTemplateFile) then
			printf(2,"\n*** Failed to load template from '%s'\n", { 
				kan:getTemplateDirectory() & vTemplateFilename })
			
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
