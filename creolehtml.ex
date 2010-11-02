
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
include std/sequence.e
include std/map.e
include std/pretty.e
sequence JSON_OPTS = PRETTY_DEFAULT
JSON_OPTS[DISPLAY_ASCII] = 3

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
sequence vQuickLink = {}

KnownWikis  = {}
KnownWikis &= {{"WIKICREOLE",	"http://wikicreole.org/wiki/"}}
KnownWikis &= {{"OHANA",		"http://wikiohana.net/cgi-bin/wiki.pl/"}}
KnownWikis &= {{"WIKIPEDIA",	"http://wikipedia.org/wiki/"}}
KnownWikis &= {{"OPENEU",       "http://openeuphoria.org/wiki/view.wc?page="}}

-----------------------------------------------------------------
function fixup_seps(sequence pFileName)
-----------------------------------------------------------------
ifdef WINDOWS then
	return search:match_replace('/', pFileName, SLASH)
elsedef
	return search:match_replace('\\', pFileName, SLASH)
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
				kan:setValue(lData, "quicklink", join( vQuickLink, "\n" ) )
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
							"<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">\n" &
							"\n" &
							"<head>\n" &
							"<meta http-equiv=\"Content-Type\" content=\"text/html;charset=utf-8\" />\n" & 
							" <title>" & lHeadings & "</title>\n" &
							" <link rel=\"stylesheet\" media=\"screen, projection, print\" type=\"text/css\" href=\"style.css\"/>\n" &
							"<!-- source=\"" & lThisContext & "\" -->\n" &
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
				
				lValue = {0,2}
				sequence lStartDepth = { 0, 0 }
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
						lSpacer = search:match_replace("^", lParms[i][2], " ")
					
					elsif equal(lParms[i][1], "start") then
						lStartDepth = value(lParms[i][2])
						if lStartDepth[1] != GET_SUCCESS then
							lStartDepth[2] = 0
						end if
					end if
				end for
				
				lHTMLText = buildTOC( 0, 1, {} )
			
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
				lHTMLText = buildTOC( lLevel, lDepth, lHere )
			
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
			
			case "INDEX" then
				lHTMLText = buildIndex( lParms )
			
			case "QUICKLINK" then
				lHTMLText = sprintf("<a name=\"ql%d\"/>\n", { length(vQuickLink)} )
				lHere = creole_parse(Get_CurrentHeading, , lInstance )
				vQuickLink = append( vQuickLink, 
					sprintf( "<li><a href='%s.html#ql%d'>%s</a></li>", { lHere[7], length(vQuickLink), lHere[H_TEXT]}) )
				
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
				if ix then
					if lSplitLength = -1 then
						lSplitLength = find('_', href)
						lSplitName = href[1..lSplitLength]
						
					end if
					map:put( 
							lSearchMap, 
							pretty_sprint( lEntry[7][1..ix-2], JSON_OPTS ), 
							{ 
								href[lSplitLength+1..lSplitLength+4], 
								href[lSplitLength+11..$], 
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

-----------------------------------------------------------------
function bmcleanup(sequence pBookMark)
-----------------------------------------------------------------
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

-----------------------------------------------------------------
function bmsort(sequence A, sequence B)
-----------------------------------------------------------------
	return compare(A[$], B[$])
end function



-----------------------------------------------------------------
function bmdivide(sequence pOrigList)
-----------------------------------------------------------------
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
	
	if vVerbose then
		object VOID = creole_parse(Set_Option, CO_Verbose )
	end if
	
	lOutText = creole_parse(lContent, routine_id("generate_html"), vCurrentContext)
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
			for i = 1 to length(lOutText) do
				lOutFile = make_filename(lOutText[i][1])
				fh = open(lOutFile, "w")
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

	vPublishedDate = sprintf("%s\n", {datetime:format(now_gmt(), "%Y-%m-%d %H:%M UTC")})
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
				
			elsif pArgs[lPos][2] = 'd' then -- template directory
				if find(pArgs[lPos][3], "=:") > 0 then
					lValue = pArgs[lPos][4..$]
				else
					lValue = pArgs[lPos][3..$]
				end if
				setTemplateDirectory( lValue )
				
			elsif equal( pArgs[lPos], "-htmldoc") then
				use_span_for_color = 0
				
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
