CreoleHtml
=====================================


Settings
---------------------------
Settings are specified by a double % followed by the name and the value:

%%splitlevel = 2

Available Settings
allow
    bold
    italic
    monospace
    underline
    superscript
    subscript
    strikethru
    insert
    camelcase
codecolors
    normal
    comment
    keyword
    builtin
    string
    bracket1
    bracket2
    bracket3
    bracket4
    bracket5
disallow
    (Same values as allow)
digits
lowercase
maxnumlevel
protocols
specialwordchars
splitlevel          Identifies the header level at which to split the content
                    into different files.
splitname           Specifies the base name of the generated files.
style
uppercase

Plugins
----------------------------

Creole plugins are not native to creole, but implemented by CreoleHtml,
and can be used by putting their name and any parameters inside double 
angle brackets:

<<INDEX>>

Available Plugins:


FONT
INDEX          Generates a linked index of headers in the document
    search     A "js/search.js" file will be generated to search for headers
NAV
LEVELTOC
    level      The starting level of headers to display
    depth      The depth of header at which to stop displaying
TOC

