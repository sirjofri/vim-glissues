" Vim global plugin for accessing GitLab issues
"
" Maintainer:	sirjofri <https://github.com/sirjofri>
"
if exists("g:loaded_glissues") || &cp
	finish
endif
let g:loaded_glissues = 1

" Section: Default Values
"
if !exists("g:gitlab_token")
	let g:gitlab_token = ""
endif

if !exists("g:gitlab_server")
	let g:gitlab_server = "https://gitlab.com"
endif

if !exists("g:gitlab_server_port")
	let g:gitlab_server_port = "443"
endif

if !exists("g:gitlab_projectid")
	let g:gitlab_projectid = "0"
endif

if !exists("g:gitlab_alter")
	let g:gitlab_alter = v:true
endif

if !exists("g:gitlab_debug")
	let g:gitlab_debug = v:false
endif

" Section: Loading of issues is done here
"
function! s:LoadIssues(state, notes)
	let l:command = "sh -c \"curl -s --header 'PRIVATE-TOKEN: ".g:gitlab_token."' ".g:gitlab_server.":".g:gitlab_server_port."/api/v4/projects/".g:gitlab_projectid."/issues?state=".a:state."\""
	echo "Trying to fetch data from server: ".g:gitlab_server."\n"
	let l:json = system(l:command)
	let l:data = json_decode(l:json)
	echo "Issue Data fetched. Loading Notes...\n"

	let l:collection = []
	for l:iss in l:data

		if a:notes
			let l:notes = []
			let l:notescommand = "sh -c \"curl -s --header 'PRIVATE-TOKEN: ".g:gitlab_token."' ".g:gitlab_server.":".g:gitlab_server_port."/api/v4/projects/".g:gitlab_projectid."/issues/".l:iss["iid"]."/notes\""
			let l:notesjson = system(l:notescommand)
			let l:notesdata = json_decode(l:notesjson)
			for l:note in l:notesdata
				let l:notes += [ "* ".l:note["author"]["username"].":\n".l:note["body"] ]
			endfor
			
			let l:notesout = join(l:notes, "\n")
		else
			let l:notesout = "Not loaded. Use `:GLOpenIssuesExt` to load comments."
		endif

		" milestone: no milestone or milestone data
		let l:milestone = l:iss["milestone"]
		let l:milestonetext = ""
		if exists("l:milestone['iid']")
			let l:ms_id = l:milestone['iid']
			let l:ms_title = l:milestone['title']
			let l:milestonetext = "\nMilestone: %".l:ms_id." ".l:ms_title
		endif

		" description placeholder or real data
		let l:desctext = "no description"
		if l:iss["description"] != ""
			let l:desctext = l:iss["description"]
		endif

		let l:collection += [ "#".l:iss["iid"]."\t".l:iss["title"].l:milestonetext."\n\n".l:desctext."\n\nComments:\n".l:notesout ]
	endfor

	let l:output = join(l:collection, "\n\n")
	
	if !exists("g:gl_issues_bufnr")
		new
		setlocal switchbuf=useopen,usetab
		let g:gl_issues_bufnr = bufnr("%")
	else
		execute "sb".g:gl_issues_bufnr
		normal ggVGd
	endif

	setlocal buftype=nofile
	execute "normal i".output
	normal gg
	setlocal foldmethod=expr
	setlocal foldexpr=getline(v\:lnum)=~'^#'?'>1'\:getline(v\:lnum)=~'^#'?'<1':1
	setlocal foldtext=getline(v:foldstart)
	syntax on
	setlocal syntax=markdown
endfunction

" Section: Create a new issue
"
" Text will appear before the actual form
let s:pre_formular = "Fill in the form. The \"Title\" field is required, everything else is\noptional. Do __not__ remove the separating space!\nThe \"Description\" field can be multiline.\nUse `:GLSave` to send data to your gitlab server.\n"
" Number of lines in the form preamble
let s:pre_formular_count = 6

" Name of the fields
let s:title = "Title:"
let s:description = "Description:"
let s:confidential = "Confidential (true|false):"
let s:labels = "Labels:"
let s:due = "Due Date (YYYY-MM-DD):"

" Opens the NewIssue window
function! s:NewIssue()
	if !exists("g:gl_newissue_bufnr")
		new
		setlocal switchbuf=useopen,usetab
		setlocal buftype=nofile
		syntax on
		setlocal syntax=markdown
		let g:gl_newissue_bufnr = bufnr("%")
		command! -buffer GLSave :call s:SaveIssue()
	else
		execute "sb".g:gl_issues_bufnr
		normal ggVGd
	endif

	" create formular
	let l:formular = s:title." \n".s:description." \n".s:confidential." false\n".s:labels." \n".s:due." "

	" write formular
	execute "normal i".s:pre_formular
	normal G
	execute "normal o".l:formular
	execute "normal ".s:pre_formular_count."G$"
	startinsert!
endfunction

" Send the filled form to the gitlab server
function! s:SaveIssue()
	if exists("g:gl_newissue_bufnr")
		execute "sb".g:gl_newissue_bufnr

		let l:title = substitute(getline(search("^".s:title)), "^".s:title." ", "", "")
		let l:description = substitute(join(getline(search("^".s:description), search("^".s:confidential)-1), "\n"), "^".s:description." ", "", "")
		let l:confidential = substitute(getline(search("^".s:confidential)), "^".s:confidential." ", "", "")
		let l:labels = substitute(getline(search("^".s:labels)), "^".s:labels." ", "", "")
		let l:due = substitute(getline(search("^".s:due)), "^".s:due." ", "", "")

		" debug messages
		if g:gitlab_debug
			echo l:title
			echo l:description
			echo l:confidential
			echo l:labels
			echo l:due
		endif

		let l:command = "sh -c \"curl --request POST --header 'PRIVATE-TOKEN: ".g:gitlab_token."' -G '".g:gitlab_server.":".g:gitlab_server_port."/api/v4/projects/".g:gitlab_projectid."/issues' --data-urlencode 'title=".l:title."' --data-urlencode 'description=".l:description."' --data-urlencode 'confidential=".l:confidential."' --data-urlencode 'labels=".l:labels."' --data-urlencode 'due_date=".l:due."'\""
		echo l:command

		if g:gitlab_alter
			let l:response = system(l:command)
			echo l:response
		endif

		" close buffer window
		execute "sb".g:gl_newissue_bufnr
		execute "q!"
	else
		echo "No formular found!"
	endif
endfunction


" Section: Mappings
"
function! <SID>GLOpenIssues()
	call s:LoadIssues("opened", v:false)
endfunction

function! <SID>GLOpenIssuesExt()
	call s:LoadIssues("opened", v:true)
endfunction

function! <SID>GLClosedIssues()
	call s:LoadIssues("closed", v:false)
endfunction

function! <SID>GLClosedIssuesExt()
	call s:LoadIssues("closed", v:true)
endfunction

function! <SID>GLNewIssue()
	call s:NewIssue()
endfunction

command! GLOpenIssues :call <SID>GLOpenIssues()
command! GLOpenIssuesExt :call <SID>GLOpenIssuesExt()
command! GLClosedIssues :call <SID>GLClosedIssues()
command! GLClosedIssuesExt :call <SID>GLClosedIssuesExt()
command! GLNewIssue :call <SID>GLNewIssue()


" folding stolen from tpope... again
" vim:ts=3:foldmethod=expr:foldexpr=getline(v\:lnum)=~'^\"\ Section\:'?'>1'\:getline(v\:lnum)=~#'^fu'?'a1'\:getline(v\:lnum)=~#'^endf'?'s1'\:'=':sw=3
