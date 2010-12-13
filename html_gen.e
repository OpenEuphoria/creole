include std/filesys.e
include std/get.e
include std/map.e
include std/math.e
include std/pretty.e
include std/search.e
include std/sequence.e
include std/sort.e
include std/text.e

include creole.e
include common.e
include common_gen.e

constant kHTML = {
	{ "&", "&amp;" },
	{ "<", "&lt;" },
	{ ">", "&gt;" },
	$
}

sequence JSON_OPTS = PRETTY_DEFAULT
JSON_OPTS[DISPLAY_ASCII] = 3

export integer use_span_for_color = 1

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
	integer jj = 0
	
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

function html_generator(integer pAction, sequence pParms, object pContext = "")
	sequence lHTMLText
	sequence lSuffix
	sequence lNumText
	integer lPos

	lHTMLText = ""

	switch pAction do
		case InternalLink then
			if find('.', pParms[1]) = 0 then
				lSuffix = ".html"
			else
				lSuffix = ""
			end if
			lHTMLText = "<a href=\"" & pParms[1] & lSuffix & "\">" & pParms[2] & "</a>"

		case QualifiedLink then
			if find('.', pParms[1]) = 0 then
				lSuffix = ".html"
			else
				lSuffix = ""
			end if
			lHTMLText = "<a href=\"" & pParms[1] & lSuffix & '#' & pParms[2] & "\">" & pParms[3] & "</a>"

		case InterWikiLinkError then
			lHTMLText = "<font color=\"#FF0000\" background=\"#000000\">Interwiki link failed for "
			lHTMLText &= pParms[2]
			lHTMLText &= "</font>"

		case NormalLink then
			lHTMLText = "<a class=\"external\" href=\"" & pParms[1] & "\">" &
							pParms[2] & "</a>"

		case InternalImage then

			lHTMLText = "<img src=\"" & pParms[1] & 
						"\" alt=\"" & pParms[2] & 
						"\" caption=\"" & pParms[2] & 
						"\" />"

		case InterWikiImage then
			lHTMLText = "<font color=\"#FF0000\" background=\"#000000\">Interwiki image failed for "
			for i = 1 to length(pParms) do
				lHTMLText &= pParms[i]
				if i < length(pParms) then
					lHTMLText &= ", "
				end if
			end for
			lHTMLText &= "</font>"

		case NormalImage then
			lHTMLText = "<img src=\"" & pParms[1] & 
						"\" alt=\"" & pParms[2] & 
						"\" caption=\"" & pParms[2] & 
						"\" />"

		case Paragraph then
			lHTMLText = "\n<p>" & pParms & "</p>\n"

		case Division then
			lHTMLText = "\n<div class=\"" & pParms[1] & "\">" & pParms[2] & "</div>\n"

		case Bookmark then
			lHTMLText = sprintf(`<a name="%s"></a>`, { pParms })
			lPos = find('_', pParms, 2) -- skip first _
			if lPos > 0 then
				lHTMLText = sprintf(`%s<a name="%s"></a>`, { lHTMLText, pParms[lPos+1..$] })
			end if

		case OrderedList then
			lHTMLText = "<ol>" & pParms & "</ol>"

		case UnorderedList then
			lHTMLText = "<ul>" & pParms & "</ul>"

		case ListItem then
			lHTMLText = "<li>" & pParms & "\n</li>"

		case Heading then
			lNumText = sprintf("%d", pParms[1])
			lHTMLText = "\n<h" & lNumText & ">" & trim(pParms[2]) & "</h" & lNumText & ">"

		case ItalicText then
			lHTMLText = "<em>" & pParms[1] & "</em>"

		case BoldText then
			lHTMLText = "<strong>" & pParms[1] & "</strong>"

		case MonoText then
			lHTMLText = "<tt>" & pParms[1] & "</tt>"

		case UnderlineText then
			lHTMLText = "<u>" & pParms[1] & "</u>"

		case Superscript then
			lHTMLText = "<sup>" & pParms[1] & "</sup>"

		case Subscript then
			lHTMLText = "<sub>" & pParms[1] & "</sub>"

		case StrikeText then
			lHTMLText = "<del>" & pParms[1] & "</del>"

		case InsertText then
			lHTMLText = "<ins>" & pParms[1] & "</ins>"

		case ColorText then
			if use_span_for_color then
				lHTMLText = "<span style=\"color:" & pParms[1] & ";\">" & pParms[2] & "</span>"
			else
				lHTMLText = "<font color=\"" & pParms[1] & "\">" & pParms[2] & "</font>"
			end if

		case CodeExample then
			lHTMLText = "\n<pre class=\"examplecode\">" & pParms[1] &  "</pre>\n"

		case TableDef then
			lHTMLText = "<table>" & pParms[1] & "</table>\n"

		case HeaderRow then
			lHTMLText = "<tr>" & pParms[1] & "</tr>\n"

		case HeaderCell then
			lHTMLText = "<th>" & pParms[1] & "</th>\n"

		case NormalRow then
			lHTMLText = "<tr>" & pParms[1] & "</tr>\n"

		case NormalCell then
			lHTMLText = "<td>" & pParms[1] & "</td>\n"

		case NonBreakSpace then
			lHTMLText = "&nbsp;"

		case ForcedNewLine then
			lHTMLText = "<br />\n"

		case HorizontalLine then
			lHTMLText = "\n<hr />\n"

		case NoWikiBlock then
			lHTMLText = "\n<pre>" & pParms[1] & "</pre>\n"

		case NoWikiInline then
			lHTMLText = pParms[1]

		case HostID then
			lHTMLText = ""

		case OptReparseHeadings then
			lHTMLText = ""

		case DefinitionList then
			lHTMLText = "<dl>\n"
			for i = 1 to length(pParms) do
				lHTMLText &= "<dt>" & pParms[i][1] & 
							"\n</dt>\n<dd>" & pParms[i][2] & 
							"</dd>\n"
			end for
			lHTMLText &= "</dl>\n"

		case BeginIndent then
			lHTMLText = "<div style=\"margin-left:2em\">"
			
		case EndIndent then
			lHTMLText = "</div>"
			
		case PassThru then
			lHTMLText = pParms
			for i = 1 to length(kHTML) do
				lHTMLText = match_replace(kHTML[i][1], lHTMLText, kHTML[i][2])
			end for
			if not equal(pParms, lHTMLText) then
				lHTMLText = "<div class=\"passthru\">" & lHTMLText & "</div>"
			end if
			
		case Sanitize then
			if atom(pParms[2]) then
				pParms[2] = { pParms[2] }
			end if

			lHTMLText = pParms[2]

			for i = 1 to length(kHTML) do
				lHTMLText = match_replace(kHTML[i][1], lHTMLText, kHTML[i][2])
			end for

		case SanitizeURL then
			lHTMLText = pParms[1]
			for i = 1 to length(kHTML) do
				lHTMLText = match_replace(kHTML[i][1], lHTMLText, kHTML[i][2])
			end for
		
		case CamelCase then
			lHTMLText = {lower(pParms[1])}
			for i = 2 to length(pParms) do
				if upper(pParms[i]) = pParms[i] then
					lHTMLText &= ' '
					lHTMLText &= lower(pParms[i])
				else
					lHTMLText &= pParms[i]
				end if
			end for
			
		case Plugin then
			sequence lValue, lHere
			integer lInstance = pParms[4]

			-- Extract the key/values, but don't parse for quoted text nor whitespace delims.
			sequence lParms = keyvalues(pParms[1], -1, -2, "", "")
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
					sequence lStartDepth = { 0, 0 }
					lValue = {0,2}

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
							search:match_replace("^", lParms[i][2], " ")
						
						elsif equal(lParms[i][1], "start") then
							lStartDepth = value(lParms[i][2])
							if lStartDepth[1] != GET_SUCCESS then
								lStartDepth[2] = 0
							end if
						end if
					end for
					
					lHTMLText = buildTOC( 0, 1, {} )
				
				case "NAV" then
					integer lIdx

					lHere = creole_parse(Get_CurrentHeading, , lInstance)
					sequence lHeadings = creole_parse(Get_Headings, , lHere[1])
	
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
				
				case "LEVELTOC" then
					integer lLevel = 1, lDepth = 4
					
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
						lIx = find(lDelim, pParms[1])
					end while

					lHere = creole_parse(Get_CurrentLevels, , { pParms[4], lLevel })
					lHTMLText = buildTOC(lLevel, lDepth, lHere)
				
				case "FONT" then
					sequence lFontColor = ""
					sequence lFontFace = ""
					sequence lFontSize = ""
					sequence lText = ""

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
							lHTMLText &= "color=\"" & common_gen:generate(Sanitize, lFontColor) & "\" "
						end if
						if length(lFontFace) > 0 then
							lHTMLText &= "face=\"" & common_gen:generate(Sanitize, lFontFace) & "\" "
						end if
						if length(lFontSize) > 0 then
							lHTMLText &= "size=\"" & common_gen:generate(Sanitize, lFontSize) & "\" "
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
					lHTMLText = "Unknown PLUGIN: " & lParms[1][2] & " "
			end switch

		case Document then
			-- Default action is to ust pass back the document text untouched.
			lHTMLText = pParms[1]
									
		case ContextChange then
			-- Record the context change in the output document
			if length(pParms) > 0 then
				lHTMLText = "\n<!-- " & pParms & " -->\n"
			end if
									
		case Comment then
			-- Record a comment in the output document
			if length(pParms) > 0 then
				lHTMLText = "\n<!-- " & pParms & " -->\n"
			end if
									
		case Quoted then
			-- Highlight a quoted section.
			if length(pParms[2]) > 0 then
				lHTMLText = "\n<div class=\"quote\">quote: <strong>" &
							pParms[1] &
							"</strong><br />\n" &
							pParms[2] &
							"\n</div>\n"
			end if
									
		case else
			lHTMLText = sprintf("[BAD ACTION CODE %d]", pAction)
			for i = 1 to length(pParms) do
				lHTMLText &= pParms[i]
				lHTMLText &= " "
			end for

	end switch

	lPos = 0
	while lPos != 0 with entry do
		lHTMLText = lHTMLText[1 .. lPos + 6] & "euwiki" & lHTMLText[lPos + 8 .. $]
	  entry
		lPos = match_from("class=\"?", lHTMLText, lPos+1)
	end while

	return lHTMLText
end function

function default_template(sequence title, sequence context, sequence body)
	return "<!DOCTYPE html \n" &
		"  PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"\n" &
		"  \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n" &
		"\n" &
		"<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">\n" &
		"\n" &
		"<head>\n" &
		"<meta http-equiv=\"Content-Type\" content=\"text/html;charset=utf-8\" />\n" & 
		" <title>" & title & "</title>\n" &
		" <link rel=\"stylesheet\" media=\"screen, projection, print\" type=\"text/css\" href=\"style.css\"/>\n" &
		"<!-- source=\"" & context & "\" -->\n" &
		"</head>\n" &
		"<body>\n" & 
		body &
		"</body></html>"	
end function

common_gen:register("HTML", "html", routine_id("html_generator"), 
	routine_id("default_template"))
