include std/console.e
include std/text.e
include std/search.e
include std/sequence.e

include common_gen.e

constant action_names = {
	"HostID",             -- id of application hosting this parser
	"OptReparseHeadings", -- "" don't reparse, anything then reparse.
	"InternalLink",       -- internal link
	"QualifiedLink",      -- A link with a file name and an anchor point within that file
	"InterWikiLink",      -- interwiki link
	"NormalLink",         -- normal link
	"InternalImage",      -- internal image
	"InterWikiImage",     -- interwiki image
	"NormalImage",        -- normal image
	"Heading",            -- headings
	"OrderedList",        -- An ordered (numbered) list
	"UnorderedList",      -- An unordered (bullet) list
	"ListItem",           -- An item in a list
	"ItalicText",         -- italized text
	"BoldText",           -- bolded text
	"MonoText",           -- monospace font text
	"UnderlineText",      -- underlined text
	"Superscript",        -- superscripted text
	"Subscript",          -- subscripted text
	"StrikeText",         -- striked out text
	"InsertText",         -- Inserted text
	"ColorText",          -- colored text
	"CodeExample",        -- program code example
	"TableDef",           -- entire table
	"HeaderRow",          -- table header row
	"HeaderCell",         -- table header cell
	"NormalRow",          -- table row
	"NormalCell",         -- table cell
	"NonBreakSpace",      -- non-breaking space
	"ForcedNewLine",      -- break the line now
	"HorizontalLine",     -- a line across the display
	"NoWikiBlock",        -- block style no wiki parsed text
	"NoWikiInline",       -- inline style no wiki parsed text
	"DefinitionList",     -- A set of definitions
	"BeginIndent",        -- Start a new indentation level
	"EndIndent",          -- End the current indentation level
	"Paragraph",          -- defines a paragraph
	"Division",           -- defines a division
	"Document",           -- defines a document
	"Bookmark",           -- define a bookmark
	"Sanitize",           -- Ensure input has no illegal characters
	"PassThru",           -- Raw text is being asked for.
	"CamelCase",          -- Convert a CamelCase word to normal text
	"Plugin",             -- A plugin has been called for
	"ContextChange",		-- A new !!CONTEXT: record found.
	"Comment",			-- A comment
	"Quoted",				-- A quoted section
	"LastActionCode"
}

constant sectioning = {
	"part",
	"chapter",
	"section",
	"subsection",
	"subsubsection",
	"par\\textbf"
}

sequence table_cells = {}, table_rows = {}

function escape(sequence val)
	integer i = 1
	
	while i <= length(val) do
		if find(val[i], "_$#\\") then
			val = insert(val, '\\', i)
			i += 1
		end if
		
		i += 1
	end while
	
	return val
end function

function generator(integer action, sequence params, object context)
	sequence doc_text

	doc_text = ""
	
	switch action do
		case InternalLink then
			display({ "InternalLink", params })
			
			if length(params[2]) and length(1) then
				--doc_text = sprintf("%s in section \\ref{sec:%s}", { escape(params[2]), params[1] })
			end if

		case QualifiedLink then
			--display({ "QualifiedLink", params })
			if sequence(params) and length(params) > 2 then
				doc_text = sprintf(" section \\ref{sec:%s}", { params[2] })
			end if

		case InterWikiLink then
			--display({ "InterWikiLink", params })

		case NormalLink then
			--display({ "NormalLink", params })

		case InternalImage then

		case InterWikiImage then

		case NormalImage then

		case Paragraph, Division then
			doc_text = splice("\\par \n", trim(params), 5)
			
		case Bookmark then
			doc_text = sprintf("\\label{sec:%s}\n", { params })

		case OrderedList then
			doc_text = "\\begin{enumerate}\n" & params & "\\end{enumerate}\n"

		case UnorderedList then
			doc_text = "\\begin{itemize}\n" & params & "\\end{itemize}\n"

		case ListItem then
			doc_text = "\\item " & params & "\n"

		case Heading then
			doc_text = sprintf("\\%s{%s}\n", { sectioning[params[1]], escape(params[2]) })
			
		case ItalicText then
			doc_text = sprintf("\\textit{%s}", { params[1] })

		case BoldText then
			doc_text = sprintf("\\textbf{%s}", { params[1] })

		case MonoText then
			doc_text = sprintf("\\texttt{%s}", { params[1] })

		case UnderlineText then
			doc_text = sprintf("\\uline{%s}", { params[1] })

		case Superscript then
			doc_text = sprintf("\\textsuperscript{%s}", { params[1] })

		case Subscript then
			doc_text = sprintf("\\textsubscript{%s}", { params[1] })

		case StrikeText then
			doc_text = sprintf("\\sout{%s}", { params[1] })

		case InsertText then
			doc_text = sprintf("\\uwave{%s}", { params[1] })

		case ColorText then
			doc_text = params[2]

		case CodeExample then
			doc_text = sprintf("\\lstset{language=euphoria,numbers=left,caption=}" &
				"\\begin{lstlisting}\n" &
				"%s\n" &
				"\\end{lstlisting}\n", 
			{
				params[1]
			})

		case TableDef then
			sequence def = ""
			
			if length(table_rows) then
				def = repeat_pattern("l|", length(table_rows[1]))
			end if
				
			doc_text = sprintf("\\begin{tabular}{|%s}\n\\hline%s\n\\end{tabular}\n", { 
				def, params[1] })
			
			table_rows = {}

		case HeaderRow then
			doc_text = sprintf("%s \\\\ {\\hline width 3pt}\n", { params[1][1..$ - 2] })
			
			table_rows = append(table_rows, table_cells)
			table_cells = {}

		case HeaderCell then
			doc_text = sprintf("\\textbf{%s} & ", { trim(params[1]) })
			table_cells = append(table_cells, params[1])

		case NormalRow then
			doc_text = sprintf("%s \\\\ \\hline\n", { params[1][1..$ - 2] })
			
			table_rows = append(table_rows, table_cells)
			table_cells = {}

		case NormalCell then
			doc_text = sprintf("%s & ", { trim(params[1]) })
			table_cells = append(table_cells, params[1])

		case NonBreakSpace then

		case ForcedNewLine then

		case HorizontalLine then
			doc_text = "\n\\hspace{5pt}\n\\hrule\n\\hspace{5pt}\n\n"

		case NoWikiBlock then
			doc_text = sprintf("\\lstset{language=,numbers=none,caption=}" &
				"\\begin{lstlisting}\n" &
				"%s\n" &
				"\\end{lstlisting}\n", 
			{
				params[1]
			})

		case NoWikiInline then

		case HostID then
			doc_text = ""

		case OptReparseHeadings then
			doc_text = ""

		case DefinitionList then

		case BeginIndent then
			
		case EndIndent then
			
		case PassThru then
			
		case Sanitize then
			doc_text = escape(params)
		
		case CamelCase then
			
		case Plugin then

		case Document then
			-- Default action is to ust pass back the document text untouched.
			doc_text = params[1]
									
		case ContextChange then
									
		case Comment then
			doc_text = sprintf("%% %s\n", { params })
									
		case Quoted then
									
		case else
			doc_text = sprintf("[BAD ACTION CODE %d]", action)
			for i = 1 to length(params) do
				doc_text &= params[i]
				doc_text &= " "
			end for
	end switch
	
	return doc_text
end function

function default_template(sequence title, sequence context, sequence body)
	/*
	-- Work around for not being able to properly escape _ in all cases, i.e.
	-- when cmd_parse or similar appears in a normal paragraph, its sent to the
	-- sanitize function as "cmd" and then "parse", never as "cmd_parse".
	integer i = 1
	while i < length(body) do
		if (find(body[i], "_#")) and (i = 1 or body[i - 1] != '\\') then
			body = insert(body, '\\', i)
			
			i += 1
		end if
		
		i += 1
	end while
	*/
	
	return `
\documentclass[letter]{book}
\usepackage{fixltx2e}
\usepackage{listings}
\usepackage{color}
\usepackage{ulem}
\usepackage{hyperref}
\usepackage[all]{hypcap}
\begin{document}

\definecolor{listinggray}{gray}{0.99}
\definecolor{stringgray}{rgb}{0.2,0.2,1.0}
\definecolor{keyword}{rgb}{0.05,0.35,0.05}
\lstset{backgroundcolor=\color{listinggray},rulecolor=\color{black}}
\lstset{morekeywords={euphoria,case,switch,namespace,public,export,override}}
\lstset{basicstyle=\ttfamily\scriptsize,frame=single,captionpos=b,stringstyle=\ttfamily\color{stringgray}}
\lstset{keywordstyle=\color{keyword},numberstyle=\tiny}

\title{` & title & `}
\author{OpenEuphoria Group}
\maketitle

\tableofcontents

` & body & `

\end{document}
`
end function

common_gen:register("LaTeX", "tex", routine_id("generator"),
	routine_id("default_template"))
