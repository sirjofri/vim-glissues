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

" Section: Loading of issues is done here
"
function! s:LoadIssues(state, notes)
	let l:command = "curl -s --header 'PRIVATE-TOKEN: ".g:gitlab_token."' ".g:gitlab_server.":".g:gitlab_server_port."/api/v4/projects/".g:gitlab_projectid."/issues?state=".a:state
	echo "Trying to fetch data from server: ".g:gitlab_server."\n"
	let l:json = system(l:command)
	let l:data = json_decode(l:json)
	echo "Issue Data fetched. Loading Notes...\n"

	let l:collection = []
	for l:iss in l:data

		if a:notes
			let l:notes = []
			let l:notescommand = "curl -s --header 'PRIVATE-TOKEN: ".g:gitlab_token."' ".g:gitlab_server.":".g:gitlab_server_port."/api/v4/projects/".g:gitlab_projectid."/issues/".l:iss["iid"]."/notes"
			let l:notesjson = system(l:notescommand)
			let l:notesdata = json_decode(l:notesjson)
			for l:note in l:notesdata
				let l:notes += [ "* ".l:note["author"]["username"].":\n".l:note["body"] ]
			endfor
			
			let l:notesout = join(l:notes, "\n")
		else
			let l:notesout = "not loaded"
		endif

		let l:collection += [ "#".l:iss["iid"]."\t".l:iss["title"]."\n\n".l:iss["description"]."\n\nComments:\n".l:notesout ]
	endfor

	let l:output = join(l:collection, "\n\n;;\n")
	
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
	setlocal foldexpr=getline(v\:lnum)=~'^#'?'>1'\:getline(v\:lnum)=~'^;;'?'<1':1
	setlocal foldtext=getline(v:foldstart)
	syntax on
	setlocal syntax=markdown
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

command! GLOpenIssues :call <SID>GLOpenIssues()
command! GLOpenIssuesExt :call <SID>GLOpenIssuesExt()
command! GLClosedIssues :call <SID>GLClosedIssues()
command! GLClosedIssuesExt :call <SID>GLClosedIssuesExt()


" folding stolen from tpope... again
" vim:ts=3:foldmethod=expr:foldexpr=getline(v\:lnum)=~'^\"\ Section\:'?'>1'\:getline(v\:lnum)=~#'^fu'?'a1'\:getline(v\:lnum)=~#'^endf'?'s1'\:'=':sw=3
