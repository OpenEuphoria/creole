include std/console.e
include std/text.e
include std/search.e
include std/sequence.e

include common_gen.e

constant sectioning = {
	"part",
	"chapter",
	"section",
	"subsection",
	"subsubsection",
	"par\\textbf"
}

constant replacements = {
	'\\', "{\\textbackslash}",
	'$', "{\\textdollar}",
	'_', "{\\textunderscore}",
	'^', "{\\textasciicircum}",
	$
}

sequence table_cells = {}, table_rows = {}

function escape(sequence val)
	integer i = 1
	
	while i <= length(val) do
		if find(val[i], "#&%") then
			val = insert(val, '\\', i)
			i += 1
		else
			integer tmp = find(val[i], replacements)
			if tmp then
				val = replace(val, replacements[tmp+1], i)
				i += length(tmp + 1)
			end if
		end if
		
		i += 1
	end while
	
	return val
end function

function generator(integer action, sequence params, object context)
	sequence doc_text = ""
	
	switch action do
		case SanitizeURL then
			doc_text = params[1]

		case InternalLink then
			doc_text = params[2] & " (\\ref{" & params[1] & "})"

		case QualifiedLink then
			doc_text = "\\hyperref[" & params[2] & "]{" & escape(params[3]) & "}"

		case InterWikiLink then
			doc_text = "InterWikiLink % InterWikiLink " & params[2] & "\n"

		case NormalLink then
			doc_text = "\\href{" & params[1] & "}{" & escape(params[2]) & "}"

		case InternalImage then

		case InterWikiImage then

		case NormalImage then

		case Paragraph, Division then
			-- We want the ability to call trim and make sure we are going to be
			-- outputting data before outputting an empty paragraph. Creole sends
			-- a {-1} for the Paragraph action to see what the beginning and ending
			-- of the paragraph is going to be. Thus we have this special case.
			if equal(params, {-1}) then
				doc_text = "\\par " & params & "\n\n"
			else
				params = trim(params)
				if length(params) then
					doc_text = sprintf("\\par %s\n\n", { params })
				end if
			end if
			
		case Bookmark then
			doc_text = sprintf("\\label{%s}\n", { params })

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
			doc_text = "\\texttt{" & params[1] & "}"

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
			sequence numbers = "none"
			if length(find_all('\n', params[1])) > 4 then
				numbers = "left"
			end if

			doc_text = sprintf("\\lstset{language=Euphoria,numbers=%s,caption=}" &
				"\\begin{lstlisting}\n" &
				"%s\n" &
				"\\end{lstlisting}\n", 
			{
				numbers,
				params[1]
			})

		case TableDef then
			sequence def = ""
			
			if length(table_rows) then
				def = repeat_pattern("X|", length(table_rows[1]))
			end if
				
			doc_text = sprintf("\\begin{tabularx}{\\linewidth}{|%s}\n\\hline\n%s\n\\end{tabularx}\n", { 
				def, params[1] })
			
			table_rows = {}

		case HeaderRow then
			doc_text = sprintf("%s \\\\\\hline\n", { params[1][1..$ - 2] })
			
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
			if params[1] then
				-- We are sanitizing a eudoc, don't do it
				doc_text = params[2]
			else
				doc_text = escape(params[2])
			end if
	
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
	return `
\documentclass[letter,openany,twoside]{book}
\usepackage{fixltx2e}
\usepackage{tabularx}
\usepackage{listings}
\usepackage{color}
\usepackage{ulem}
\usepackage[pagebackref=true,colorlinks]{hyperref}
\usepackage[all]{hypcap}
\usepackage[Lenny]{fncychap}
\usepackage{fancyhdr}
\usepackage{vpage}
%\usepackage[titles]{tocloft}
\usepackage{graphicx}
\usepackage{fix-cm}

\pagestyle{empty}
\fancyhf{}
\fancyhead[LE]{\slshape \leftmark}
\fancyhead[RO]{\slshape \rightmark}
\fancyfoot[LE]{\thepage}
\fancyfoot[RO]{\thepage}

% Set the default font to serif
\renewcommand{\familydefault}{\sfdefault}

\definecolor{listinggray}{gray}{0.99}
\definecolor{stringgray}{rgb}{0.2,0.2,1.0}
\definecolor{keyword}{rgb}{0.05,0.35,0.05}
\lstset{%
	showspaces=false,%
	showtabs=false,%
	showstringspaces=false,%
	tabsize=4,%
	backgroundcolor=\color{listinggray},%
	rulecolor=\color{black},%
	basicstyle=\ttfamily\small,%
	frame=single,%
	captionpos=b,%
	stringstyle=\ttfamily\color{stringgray},%
	keywordstyle=\color{keyword},%
	numberstyle=\tiny%
}

\begin{document}

\frontmatter
\title{` & title & `}
\author{OpenEuphoria Group}
%\maketitle
{\centering%
  %\includegraphics{300px-Logo-Logotype-boxed-oV2-R0.png}
  \includegraphics{300px-mongoose-head-colour-V2-R0.png}%
  \par\vspace*{48pt}%
  \includegraphics{300px-Logo-Logotype-orange-V2-R0.png}%
  %\vspace*{64pt}%
  \par{\fontsize{28}{36}\selectfont Version 4.0}%
  \vspace*{90pt}%
  \par{\fontsize{48}{58}\selectfont User Manual}%
  %
  \newpage%
}

\setcounter{tocdepth}{1}
\tableofcontents

\pagestyle{fancy}
\mainmatter

` & body & `

\end{document}
`
end function

common_gen:register("LaTeX", "tex", routine_id("generator"),
	routine_id("default_template"))
