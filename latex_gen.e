include std/text.e
include std/search.e

include common_gen.e

function generator(integer action, sequence params, object context)
	sequence doc_text

	doc_text = ""

	switch action do
		case InternalLink then

		case QualifiedLink then

		case InterWikiLink then

		case NormalLink then

		case InternalImage then

		case InterWikiImage then

		case NormalImage then

		case Paragraph then

		case Division then

		case Bookmark then

		case OrderedList then

		case UnorderedList then

		case ListItem then

		case Heading then

		case ItalicText then

		case BoldText then

		case MonoText then

		case UnderlineText then

		case Superscript then

		case Subscript then

		case StrikeText then

		case InsertText then

		case ColorText then

		case CodeExample then

		case TableDef then

		case HeaderRow then

		case HeaderCell then

		case NormalRow then

		case NormalCell then

		case NonBreakSpace then

		case ForcedNewLine then

		case HorizontalLine then

		case NoWikiBlock then

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
		
		case CamelCase then
			
		case Plugin then

		case Document then
			-- Default action is to ust pass back the document text untouched.
			doc_text = params[1]
									
		case ContextChange then
									
		case Comment then
									
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
\documentclass[letter]{book}
\usepackage{listings}
\usepackage{color}
\begin{document}

\definecolor{listinggray}{gray}{0.99}
\definecolor{stringgray}{rgb}{0.2,0.2,1.0}
\definecolor{keyword}{rgb}{0.05,0.35,0.05}
\lstset{backgroundcolor=\color{listinggray},rulecolor=\color{black}}
\lstset{morekeywords={euphoria,case,switch,namespace,public,export,override}}
\lstset{basicstyle=\ttfamily\small,frame=single,captionpos=b,stringstyle=\ttfamily\color{stringgray}}
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
